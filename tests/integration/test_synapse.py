# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import asyncio
import os

import pytest
import yaml

from ..fixtures import ESSData
from ..lib.helpers import kubernetes_tls_secret
from ..lib.utils import aiottp_get_json
from ..services import PostgresServer


@pytest.mark.skipif(os.environ.get("TEST_SYNAPSE") != "1", reason="Synapse not deployed")
@pytest.mark.asyncio_cooperative
async def test_synapse(
    cluster,
    helm_client,
    kube_client,
    ssl_context,
    ca,
    generated_data: ESSData,
):
    resources = [
        kubernetes_tls_secret(
            "synapse-web-tls", generated_data.ess_namespace, ca, ["synapse.ess.localhost"], bundled=True
        ),
        generated_data.ess_secret(),
    ]

    postgres_setup = PostgresServer(
        name="synapse",
        namespace=generated_data.ess_namespace,
        database="synapse_db",
        user="synapse_user",
        password=generated_data.synapse_postgres_password,
    ).setup(helm_client, kube_client)

    with open("charts/synapse/ci/pytest-values.yaml") as stream:
        values = yaml.safe_load(stream)

    chart = await helm_client.get_chart("charts/synapse")
    # Install or upgrade a release
    revision = helm_client.install_or_upgrade_release(
        f"synapse-{generated_data.secrets_random}",
        chart,
        values,
        namespace=generated_data.ess_namespace,
        atomic=True,
        wait=True,
    )

    await asyncio.gather(revision, postgres_setup, *[kube_client.create(r) for r in resources])

    await asyncio.to_thread(
        cluster.wait,
        name=f"ingress/synapse-{generated_data.secrets_random}-synapse",
        namespace=generated_data.ess_namespace,
        waitfor="jsonpath='{.status.loadBalancer.ingress[0].ip}'",
    )

    json_content = await aiottp_get_json("https://synapse.ess.localhost/_matrix/client/versions", ssl_context)
    assert "unstable_features" in json_content
