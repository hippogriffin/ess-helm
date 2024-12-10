# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import asyncio
import os
from pathlib import Path

import pyhelm3
import pytest
import yaml
from lightkube import AsyncClient, KubeConfig
from lightkube.models.meta_v1 import ObjectMeta
from lightkube.resources.core_v1 import Namespace
from pytest_kubernetes.options import ClusterOptions
from pytest_kubernetes.providers import KindManager
from python_on_whales import docker

from .data import ESSData


class PotentiallyExistingKindCluster(KindManager):
    def __init__(self, cluster_name, cluster_config=None):
        super().__init__(cluster_name, cluster_config)

        # Remove the pytest- prefix
        self.cluster_name = cluster_name

        clusters = self._exec(["get", "clusters"])
        if self.cluster_name in clusters.stdout.decode("utf-8").split("\n"):
            self.existing_cluster = True
        else:
            self.existing_cluster = False

    def _on_create(self, cluster_options, **kwargs):
        if self.existing_cluster:
            self._exec(
                [
                    "export",
                    "kubeconfig",
                    "--name",
                    self.cluster_name,
                    "--kubeconfig ",
                    str(cluster_options.kubeconfig_path),
                ]
            )
        else:
            super()._on_create(cluster_options, **kwargs)

    def _on_delete(self):
        # We always keep around an existing cluster, it can always be deleted with scripts/destroy-test-cluster.sh
        if not self.existing_cluster and os.environ.get("PYTEST_KEEP_CLUSTER", "") != "1":
            return super()._on_delete()


@pytest.fixture(autouse=True, scope="session")
async def cluster():
    fixtures_folder = Path(__file__).parent.resolve()
    # This name must match what `setup_test_cluster.sh` would create
    this_cluster = PotentiallyExistingKindCluster("ess-helm")
    kind_config = Path("files/clusters/kind-ci.yml") if os.environ.get("CI") else Path("files/clusters/kind.yml")
    this_cluster.create(ClusterOptions(cluster_config=fixtures_folder / kind_config))

    await asyncio.to_thread(
        this_cluster.kubectl, ["taint", "nodes", "ess-helm-control-plane", "context=pytest:NoSchedule", "--overwrite"]
    )

    await asyncio.to_thread(
        this_cluster.kubectl,
        [
            "patch",
            "-n",
            "kube-system",
            "deployment/coredns",
            "--patch-file",
            (fixtures_folder / Path("files/patches/tolerations.yml")).as_posix(),
        ],
    )

    await asyncio.to_thread(
        this_cluster.kubectl,
        [
            "patch",
            "-n",
            "local-path-storage",
            "deployment/local-path-provisioner",
            "--patch-file",
            (fixtures_folder / Path("files/patches/tolerations.yml")).as_posix(),
        ],
    )

    yield this_cluster

    await asyncio.to_thread(
        this_cluster.kubectl, ["taint", "nodes", "ess-helm-control-plane", "context=pytest:NoSchedule-"]
    )

    this_cluster.delete()


@pytest.fixture(scope="session")
async def helm_client(cluster):
    yield pyhelm3.Client(kubeconfig=cluster.kubeconfig, kubecontext=cluster.context)


@pytest.fixture(scope="session")
async def kube_client(cluster):
    kube_config = KubeConfig.from_file(cluster.kubeconfig)
    yield AsyncClient(config=kube_config)


@pytest.fixture(autouse=True, scope="session")
async def ingress(cluster, helm_client: pyhelm3.Client):
    chart = await helm_client.get_chart("ingress-nginx", repo="https://kubernetes.github.io/ingress-nginx")

    values_file = Path(__file__).parent.resolve() / Path("files/charts/ingress-nginx.yml")
    # Install or upgrade a release
    await helm_client.install_or_upgrade_release(
        "ingress-nginx",
        chart,
        yaml.safe_load(values_file.read_text("utf-8")),
        namespace="ingress-nginx",
        create_namespace=True,
        atomic=True,
        wait=True,
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


@pytest.fixture(autouse=True, scope="session")
async def registry(cluster):
    pytest_registry_container_name = "pytest-ess-helm-registry"
    test_cluster_registry_container_name = "ess-helm-registry"

    # We have a registry created by `setup_test_cluster.sh`
    if docker.container.exists(test_cluster_registry_container_name):
        container_name = test_cluster_registry_container_name
    # We have a registry created by a previous run of pytest
    elif docker.container.exists(pytest_registry_container_name):
        container_name = pytest_registry_container_name
    # We have no registry, create one
    else:
        container_name = pytest_registry_container_name
        container = docker.run(
            name=container_name,
            image="registry:2",
            publish=[("127.0.0.1:5000", "5000")],
            restart="always",
            detach=True,
        )

    container = docker.container.inspect(container_name)
    if not container.state.running:
        container.start()

    kind_network = docker.network.inspect("kind")
    if container.id not in kind_network.containers:
        docker.network.connect(kind_network, container, alias="registry")

    yield

    if container_name == pytest_registry_container_name:
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


@pytest.fixture(autouse=True, scope="session")
async def ess_namespace(kube_client, generated_data):
    await kube_client.create(Namespace(metadata=ObjectMeta(name=generated_data.ess_namespace)))
