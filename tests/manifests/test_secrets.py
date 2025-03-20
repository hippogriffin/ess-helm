# Copyright 2025 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only

import pytest

from . import values_files_to_test


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_all_secrets_have_type(templates):
    for template in templates:
        if template["kind"] == "Secret":
            id = f"{template['kind']}/{template['metadata']['name']}"
            assert "type" in template, f"{id} has not set the Secret type"
            assert template["type"] in ["Opaque"], f"{id} has an unexpected Secret type {template['type']}"
