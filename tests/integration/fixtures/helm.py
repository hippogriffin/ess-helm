# Copyright 2024-2025 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import asyncio
import os

import pyhelm3
import pytest
import yaml
from lightkube import AsyncClient
from lightkube.models.meta_v1 import ObjectMeta
from lightkube.resources.core_v1 import Namespace, Secret

from ..lib.helpers import kubernetes_tls_secret
from ..lib.utils import value_file_has
from ..services import PostgresServer
from .data import ESSData, unsafe_token


@pytest.fixture(scope="session")
async def helm_prerequisites(
    kube_client: AsyncClient, helm_client: pyhelm3.Client, ca, ess_namespace: Namespace, generated_data: ESSData
):
    resources = []
    setups = []

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
    - "0000000000000PYTESTADM1N"
clients:
- client_id: "000000000000000PYTESTADM1N"
  client_auth_method: client_secret_basic
  client_secret: {generated_data.mas_oidc_client_secret}
""",}))

        setups.append(
            PostgresServer(
                name=f"{generated_data.release_name}-mas",
                namespace=generated_data.ess_namespace,
                database="mas_db",
                user="mas_user",
                password=unsafe_token(36),
            ).setup(helm_client, kube_client)
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
                    "registrationSharedSecret": generated_data.synapse_registration_shared_secret,
                    "01-other-user-config.yaml": """
retention:
  enabled: false
""",
                },
            )
        )

        setups.append(
            PostgresServer(
                name=f"{generated_data.release_name}-synapse",
                namespace=generated_data.ess_namespace,
                database="synapse_db",
                user="synapse_user",
                password=unsafe_token(36),
            ).setup(helm_client, kube_client)
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

    counter = 0
    while True:
        try:
            revision = await helm_client.get_current_revision(
                generated_data.release_name,
                namespace=generated_data.ess_namespace,
            )
            if revision.status == pyhelm3.ReleaseRevisionStatus.DEPLOYED:
                break
            elif revision.status != pyhelm3.ReleaseRevisionStatus.PENDING_INSTALL:
                raise Exception("Helm Release seems to have failed deploying")
        except pyhelm3.errors.ReleaseNotFoundError:
            continue

        counter += 1
        await asyncio.sleep(1)
        if counter > 180:
            raise Exception("Helm Release did not become DEPLOYED after 180s")


@pytest.fixture(scope="session")
def ingress_ready(cluster, matrix_stack, generated_data: ESSData):
    async def _ingress_ready(ingress_suffix):
        await asyncio.to_thread(
            cluster.wait,
            name=f"ingress/{generated_data.release_name}-{ingress_suffix}",
            namespace=generated_data.ess_namespace,
            waitfor="jsonpath='{.status.loadBalancer.ingress[0].ip}'",
        )

    return _ingress_ready
