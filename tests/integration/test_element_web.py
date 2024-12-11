# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import asyncio

import pytest

from .fixtures import ESSData
from .lib.utils import aiottp_get_json, value_file_has


@pytest.mark.skipif(value_file_has("elementWeb.enabled", False), reason="ElementWeb not deployed")
@pytest.mark.asyncio_cooperative
async def test_element_web_can_access_config_json(cluster, generated_data: ESSData, ssl_context):
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
