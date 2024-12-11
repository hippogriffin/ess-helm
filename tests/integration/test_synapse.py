# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import hashlib
from pathlib import Path

import pytest

from .fixtures import ESSData
from .lib.synapse import assert_downloaded_content, download_media, upload_media
from .lib.utils import KubeCtl, aiohttp_post_json, aiottp_get_json, value_file_has


@pytest.mark.skipif(value_file_has("synapse.enabled", False), reason="Synapse not deployed")
@pytest.mark.asyncio_cooperative
async def test_synapse_can_access_client_api(
    synapse_ready,
    ssl_context,
    generated_data: ESSData,
):
    json_content = await aiottp_get_json(
        f"https://synapse.{generated_data.server_name}/_matrix/client/versions", ssl_context
    )
    assert "unstable_features" in json_content


@pytest.mark.skipif(value_file_has("synapse.enabled", False), reason="Synapse not deployed")
@pytest.mark.parametrize("synapse_users", [("sliding-sync-user",)], indirect=True)
@pytest.mark.asyncio_cooperative
async def test_simplified_sliding_sync_syncs(ssl_context, synapse_users, generated_data: ESSData):
    access_token = synapse_users[0]

    sync_result = await aiohttp_post_json(
        f"https://synapse.{generated_data.server_name}/_matrix/client/unstable/org.matrix.simplified_msc3575/sync",
        {},
        {"Authorization": f"Bearer {access_token}"},
        ssl_context,
    )

    assert "pos" in sync_result


@pytest.mark.skipif(value_file_has("synapse.enabled", False), reason="Synapse not deployed")
@pytest.mark.parametrize("synapse_users", [("media-upload-unauth",)], indirect=True)
@pytest.mark.asyncio_cooperative
async def test_synapse_media_upload_fetch_authenticated(
    cluster,
    ssl_context,
    synapse_users,
    generated_data: ESSData,
):
    user_access_token = synapse_users[0]

    filepath = Path(__file__).parent.resolve() / Path("artifacts/files/minimal.png")
    with open(filepath, "rb") as file:
        source_sha256 = hashlib.file_digest(file, "sha256").hexdigest()

    content_upload_json = await upload_media(
        synapse_fqdn=f"synapse.{generated_data.server_name}",
        user_access_token=user_access_token,
        file_path=filepath,
        ssl_context=ssl_context,
    )

    content_download_sha256 = await download_media(
        server_name=generated_data.server_name,
        user_access_token=user_access_token,
        synapse_fqdn=f"synapse.{generated_data.server_name}",
        content_upload_json=content_upload_json,
        ssl_context=ssl_context,
    )

    media_pod_suffix = "synapse-media-repository-0"
    media_pod = f"{generated_data.release_name}-{media_pod_suffix}"

    await assert_downloaded_content(
        KubeCtl(cluster),
        media_pod,
        generated_data.ess_namespace,
        source_sha256,
        content_upload_json["content_uri"].replace(f"mxc://{generated_data.server_name}/", ""),
        content_download_sha256,
    )
