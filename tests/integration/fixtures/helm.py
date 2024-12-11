# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: LicenseRef-Element-Commercial

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
from .data import ESSData


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
                ess_namespace.metadata.name,
                ca,
                [f"element.{generated_data.server_name}"],
                bundled=True,
            )
        )

    if value_file_has("synapse.enabled", True):
        resources.append(generated_data.ess_secret())
        resources.append(
            kubernetes_tls_secret(
                f"{generated_data.release_name}-synapse-web-tls",
                ess_namespace.metadata.name,
                ca,
                [f"synapse.{generated_data.server_name}"],
                bundled=True,
            )
        )
        resources.append(
            Secret(
                metadata=ObjectMeta(
                    name=f"{generated_data.release_name}-synapse-secrets",
                    namespace=ess_namespace.metadata.name,
                    labels={"app.kubernetes.io/managed-by": "pytest"},
                ),
                stringData={
                    "01-other-user-config.yaml": """
retention:
  enabled: false
"""
                },
            )
        )

        setups.append(
            PostgresServer(
                name=f"{generated_data.release_name}-synapse",
                namespace=ess_namespace.metadata.name,
                database="synapse_db",
                user="synapse_user",
                password=generated_data.synapse_postgres_password,
            ).setup(helm_client, kube_client)
        )

    return [*setups, *[kube_client.create(resource) for resource in resources]]


@pytest.fixture(autouse=True, scope="session")
async def matrix_stack(
    helm_client: pyhelm3.Client, ingress, helm_prerequisites, ess_namespace: Namespace, generated_data: ESSData
):
    with open(os.environ["TEST_VALUES_FILE"]) as stream:
        values = yaml.safe_load(stream)

    values["serverName"] = generated_data.server_name

    chart = await helm_client.get_chart("charts/matrix-stack")
    # Install or upgrade a release
    revision = helm_client.install_or_upgrade_release(
        generated_data.release_name,
        chart,
        values,
        namespace=ess_namespace.metadata.name,
        atomic=True,
        wait=True,
    )
    await asyncio.gather(revision, *helm_prerequisites)


@pytest.fixture(autouse=True, scope="session")
async def revision_deployed(helm_client: pyhelm3.Client, ess_namespace: Namespace, generated_data: ESSData):
    counter = 0
    while True:
        try:
            revision = await helm_client.get_current_revision(
                generated_data.release_name,
                namespace=ess_namespace.metadata.name,
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
