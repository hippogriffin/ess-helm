# Copyright 2024-2025 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import asyncio
import base64
import os

import pyhelm3
import pytest
import yaml
from lightkube import AsyncClient
from lightkube.models.meta_v1 import ObjectMeta
from lightkube.resources.core_v1 import Endpoints, Namespace, Secret, Service
from lightkube.resources.networking_v1 import Ingress

from ..lib.helpers import kubernetes_docker_secret, kubernetes_tls_secret
from ..lib.utils import DockerAuth, docker_config_json, value_file_has
from .data import ESSData


@pytest.fixture(scope="session")
async def helm_prerequisites(
    kube_client: AsyncClient, helm_client: pyhelm3.Client, ca, ess_namespace: Namespace, generated_data: ESSData
):
    resources = []
    setups = []

    # On CI, public runners need read access to dockerhub.io and ghcr.io repositories
    if os.environ.get("CI"):
        resources.append(
            kubernetes_docker_secret(
                f"{generated_data.release_name}-dockerhub",
                namespace=generated_data.ess_namespace,
                docker_config_json=docker_config_json(
                    [
                        DockerAuth(
                            registry="docker.io",
                            username=os.environ["DOCKERHUB_USERNAME"],
                            password=os.environ["DOCKERHUB_TOKEN"],
                        )
                    ]
                ),
            ),
        )
        resources.append(
            kubernetes_docker_secret(
                f"{generated_data.release_name}-ghcr",
                namespace=generated_data.ess_namespace,
                docker_config_json=docker_config_json(
                    [
                        DockerAuth(
                            registry="ghcr.io",
                            username=os.environ["GHCR_USERNAME"],
                            password=os.environ["GHCR_TOKEN"],
                        )
                    ]
                ),
            ),
        )

    if value_file_has("elementWeb.enabled", True):
        resources.append(
            kubernetes_tls_secret(
                f"{generated_data.release_name}-element-web-tls",
                generated_data.ess_namespace,
                ca,
                [f"element.{generated_data.server_name}"],
                bundled=True,
            )
        )

    if value_file_has("matrixAuthenticationService.enabled", True):
        resources.append(
            kubernetes_tls_secret(
                f"{generated_data.release_name}-mas-web-tls",
                generated_data.ess_namespace,
                ca,
                [f"mas.{generated_data.server_name}"],
                bundled=True,
            )
        )
        resources.append(
            Secret(
                metadata=ObjectMeta(
                    name=f"{generated_data.release_name}-pytest-admin",
                    namespace=generated_data.ess_namespace,
                    labels={"app.kubernetes.io/managed-by": "pytest"},
                ),
                stringData={
                    "admin.yaml": f"""
policy:
  data:
    admin_clients:
    - "000000000000000PYTESTADM1N"
clients:
- client_id: "000000000000000PYTESTADM1N"
  client_auth_method: client_secret_basic
  client_secret: {generated_data.mas_oidc_client_secret}
""",
                },
            )
        )

    if value_file_has("synapse.enabled", True):
        resources.append(
            kubernetes_tls_secret(
                f"{generated_data.release_name}-synapse-web-tls",
                generated_data.ess_namespace,
                ca,
                [f"synapse.{generated_data.server_name}"],
                bundled=True,
            )
        )
        resources.append(
            Secret(
                metadata=ObjectMeta(
                    name=f"{generated_data.release_name}-synapse-secrets",
                    namespace=generated_data.ess_namespace,
                    labels={"app.kubernetes.io/managed-by": "pytest"},
                ),
                stringData={
                    "01-other-user-config.yaml": """
retention:
  enabled: false
""",
                },
            )
        )

    if value_file_has("wellKnownDelegation.enabled", True):
        resources.append(
            kubernetes_tls_secret(
                f"{generated_data.release_name}-well-known-web-tls",
                generated_data.ess_namespace,
                ca,
                [generated_data.server_name],
                bundled=True,
            )
        )

    return [*setups, *[kube_client.create(resource) for resource in resources]]


@pytest.fixture(autouse=True, scope="session")
async def matrix_stack(
    helm_client: pyhelm3.Client,
    ingress,
    helm_prerequisites,
    ess_namespace: Namespace,
    generated_data: ESSData,
    loaded_matrix_tools: dict,
):
    with open(os.environ["TEST_VALUES_FILE"]) as stream:
        values = yaml.safe_load(stream)

    values["serverName"] = generated_data.server_name
    values.setdefault("matrixTools", {})
    if os.environ.get("CI"):
        values["imagePullSecrets"] = [
            {"name": f"{generated_data.release_name}-dockerhub"},
            {"name": f"{generated_data.release_name}-ghcr"},
        ]
    values["matrixTools"].setdefault("image", {})
    values["matrixTools"]["image"] = loaded_matrix_tools

    chart = await helm_client.get_chart("charts/matrix-stack")
    # Install or upgrade a release
    revision = helm_client.install_or_upgrade_release(
        generated_data.release_name,
        chart,
        values,
        namespace=generated_data.ess_namespace,
        atomic="CI" not in os.environ,
        wait=True,
    )
    await asyncio.gather(revision, *helm_prerequisites)


@pytest.fixture(scope="session")
def ingress_ready(cluster, kube_client: AsyncClient, matrix_stack, generated_data: ESSData):
    async def _ingress_ready(ingress_suffix):
        await asyncio.to_thread(
            cluster.wait,
            name=f"ingress/{generated_data.release_name}-{ingress_suffix}",
            namespace=generated_data.ess_namespace,
            waitfor="jsonpath='{.status.loadBalancer.ingress[0].ip}'",
        )
        ingress = await kube_client.get(
            Ingress, f"{generated_data.release_name}-{ingress_suffix}", namespace=generated_data.ess_namespace
        )
        for rule in ingress.spec.rules:
            for path in rule.http.paths:
                service = await kube_client.get(
                    Service, path.backend.service.name, namespace=generated_data.ess_namespace
                )
                await asyncio.to_thread(
                    cluster.wait,
                    name=f"endpoints/{service.metadata.name}",
                    namespace=generated_data.ess_namespace,
                    waitfor="jsonpath='{.subsets[].addresses}'",
                )

                endpoints_ready = False
                while not endpoints_ready:
                    endpoint = await kube_client.get(
                        Endpoints, name=service.metadata.name, namespace=generated_data.ess_namespace
                    )

                    for subset in endpoint.subsets:
                        if not subset or subset.notReadyAddresses or not subset.addresses or not subset.ports:
                            await asyncio.sleep(0.1)
                            break
                    else:
                        endpoints_ready = True

    return _ingress_ready


@pytest.fixture(scope="session")
def secrets_generated(cluster, kube_client: AsyncClient, matrix_stack, generated_data: ESSData):
    async def _secrets_generated(secret_key) -> str:
        await asyncio.to_thread(
            cluster.wait,
            name=f"job/{generated_data.release_name}-init-secrets",
            namespace=generated_data.ess_namespace,
            waitfor="condition=complete",
        )
        generated_secret = await kube_client.get(
            Secret, namespace=generated_data.ess_namespace, name=f"{generated_data.release_name}-generated"
        )

        assert secret_key in generated_secret.data
        base64_encoded_secret_value = generated_secret.data[secret_key]
        return base64.standard_b64decode(base64_encoded_secret_value).decode("utf-8")

    return _secrets_generated
