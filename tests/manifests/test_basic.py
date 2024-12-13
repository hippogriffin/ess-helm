# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import pytest

from . import component_details, values_files_to_test


@pytest.mark.parametrize("values_file", ["nothing-enabled-values.yaml"])
@pytest.mark.asyncio_cooperative
async def test_nothing_enabled_renders_nothing(templates):
    assert len(templates) == 0


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_values_file_renders_only_itself(component, templates):
    assert len(templates) > 0

    for template in templates:
        assert template["metadata"]["name"].startswith(f"pytest-{component_details[component]["hyphened_name"]}")
