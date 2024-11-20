# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import asyncio
import os
from pathlib import Path

import pyhelm3
import pytest
from lightkube import AsyncClient, KubeConfig
from lightkube.resources.apps_v1 import Deployment
from lightkube.resources.core_v1 import Service
from pytest_kubernetes.options import ClusterOptions
from pytest_kubernetes.plugin import select_provider_manager
from pytest_kubernetes.providers import KindManager
from python_on_whales import docker


@pytest.fixture(autouse=True, scope="session")
async def cluster(request, registry):
    this_cluster = select_provider_manager()("ess")
    if isinstance(this_cluster, KindManager):
        kind_config = Path("files/clusters/kind-ci.yml") if os.environ.get("CI") else Path("files/clusters/kind.yml")
        this_cluster.create(ClusterOptions(cluster_config=Path(__file__).parent.resolve() / kind_config))
    else:
        raise Exception("Cluster not managed")
    kind_network = docker.network.inspect("kind")
    registry_container = docker.container.inspect("pytest-ess-registry")
    for n in registry_container.network_settings.networks.values():
        if n.network_id == kind_network.id:
            # The network is already present, no need to attach
            break
    else:
        docker.network.connect(kind_network, registry_container)
    yield this_cluster
    if not request.config.getoption("keep_cluster"):
        this_cluster.delete()


@pytest.fixture(scope="session")
async def helm_client(cluster):
    yield pyhelm3.Client(kubeconfig=cluster.kubeconfig, kubecontext=cluster.context)


@pytest.fixture(scope="session")
async def kube_client(cluster):
    kube_config = KubeConfig.from_file(cluster.kubeconfig)
    yield AsyncClient(config=kube_config)


@pytest.fixture(autouse=True, scope="session")
async def ingress(cluster, kube_client: AsyncClient):
    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml"
        )
        ingress_controller_yaml = response.text
    resources = codecs.load_all_yaml(ingress_controller_yaml)
    await batch_apply_ordered(kube_client, resources)
    await asyncio.gather(
        kube_client.wait(
            Job, name="ingress-nginx-admission-create", namespace="ingress-nginx", for_conditions=["Complete"]
        ),
        kube_client.wait(
            Job, name="ingress-nginx-admission-patch", namespace="ingress-nginx", for_conditions=["Complete"]
        ),
        kube_client.wait(
            Deployment, name="ingress-nginx-controller", namespace="ingress-nginx", for_conditions=["Available"]
        ),
    )
    await asyncio.to_thread(
        cluster.wait,
        name="endpoints/ingress-nginx-controller-admission",
        waitfor="jsonpath='{.subsets[].addresses}'",
        namespace="ingress-nginx",
    )
    await asyncio.to_thread(
        cluster.wait,
        name="lease/ingress-nginx-leader",
        waitfor="jsonpath='{.spec.holderIdentity}'",
        namespace="ingress-nginx",
    )
    await asyncio.to_thread(
        cluster.kubectl, ["taint", "nodes", "pytest-ess-control-plane", "context=pytest:NoSchedule"]
    )


@pytest.fixture(autouse=True, scope="session")
async def registry():
    if docker.container.exists("pytest-ess-registry"):
        container = docker.container.inspect("pytest-ess-registry")
        if not container.state.running:
            container.start()
    else:
        container = docker.run(
            name="pytest-ess-registry",
            image="registry:2",
            publish=[("127.0.0.1:5000", "5000")],
            restart="always",
            detach=True,
        )
    yield
    container.stop()
    container.remove()


@pytest.fixture(autouse=True, scope="session")
async def prometheus_operator_crds(helm_client):
    if os.environ.get("SKIP_SERVICE_MONITORS_CRDS", "false") == "false":
        chart = await helm_client.get_chart(
            "prometheus-operator-crds", repo="https://prometheus-community.github.io/helm-charts"
        )

        # Install or upgrade a release
        await helm_client.install_or_upgrade_release(
            "prometheus-operator-crds",
            chart,
            {},
            namespace="default",
            create_namespace=False,
            atomic=True,
            wait=True,
        )


@pytest.fixture(scope="session")
async def ingress_ip(kube_client: AsyncClient, ingress):
    await kube_client.wait(
        Deployment, name="ingress-nginx-controller", namespace="ingress-nginx", for_conditions=["Available"]
    )
    service = await kube_client.get(Service, name="ingress-nginx-controller", namespace="ingress-nginx")
    return service.spec.clusterIP
