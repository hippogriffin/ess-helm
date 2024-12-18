# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import hashlib
from pathlib import Path

import pytest

from .fixtures import ESSData
from .lib.synapse import assert_downloaded_content, download_media, upload_media
from .lib.utils import KubeCtl, aiohttp_post_json, aiottp_get_json, value_file_has


@pytest.mark.skipif(value_file_has("wellKnownDelegation.enabled", False), reason="WellKnownDelegation not deployed")
@pytest.mark.asyncio_cooperative
async def test_well_known_files_can_be_accessed(
    ingress_ready,
    ssl_context,
    generated_data: ESSData,
):
    await ingress_ready("well-known-haproxy")

    json_content = await aiottp_get_json(
        f"https://{generated_data.server_name}/.well-known/matrix/client", ssl_context
    )
    if value_file_has("synapse.enabled", True):
        assert "m.homeserver" in json_content
    else:
        assert json_content == {}

    json_content = await aiottp_get_json(
        f"https://{generated_data.server_name}/.well-known/matrix/server", ssl_context
    )
    if value_file_has("synapse.enabled", True):
        assert "m.server" in json_content
    else:
        assert json_content == {}

    json_content = await aiottp_get_json(
        f"https://{generated_data.server_name}/.well-known/matrix/element.json", ssl_context
    )
    assert json_content == {}

