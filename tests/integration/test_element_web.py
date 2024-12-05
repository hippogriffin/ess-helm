# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import asyncio

import pytest

from ..fixtures import ESSData
from ..lib.helpers import install_matrix_stack, kubernetes_tls_secret
from ..lib.utils import aiottp_get_json, value_file_has


@pytest.mark.skipif(value_file_has("elementWeb.enabled", False), reason="ElementWeb not deployed")
@pytest.mark.asyncio_cooperative
async def test_element_web(
    cluster,
    helm_client,
    kube_client,
    ssl_context,
    ca,
    generated_data: ESSData,
):
    resources = [
        kubernetes_tls_secret(
            f"{generated_data.release_name}-element-web-tls",
            generated_data.ess_namespace,
            ca,
            [f"element.{generated_data.server_name}"],
            bundled=True,
        )
    ]
    revision = await install_matrix_stack(helm_client, generated_data)

    await asyncio.gather(revision, *[kube_client.create(r) for r in resources])


@pytest.mark.skipif(value_file_has("elementWeb.enabled", False), reason="ElementWeb not deployed")
@pytest.mark.asyncio_cooperative
async def test_can_access_config_json(cluster, revision_deployed, generated_data: ESSData, ssl_context):
    await asyncio.to_thread(
        cluster.wait,
        name=f"ingress/{generated_data.release_name}-element-web",
        namespace=generated_data.ess_namespace,
        waitfor="jsonpath='{.status.loadBalancer.ingress[0].ip}'",
    )

    json_content = await aiottp_get_json(f"https://element.{generated_data.server_name}/config.json", ssl_context)
    assert "element_call" in json_content
    assert json_content["element_call"]["url"] == f"https://call.{generated_data.server_name}"
    assert json_content["element_call"]["use_exclusively"]
