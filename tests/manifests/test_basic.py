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

    allowed_starts_with = [f"pytest-{component_details[component]["hyphened_name"]}",]
    for shared_component in component_details[component].get("shared_components", []):
        allowed_starts_with.append(f"pytest-{shared_component}")
    for template in templates:
        assert any(
            template["metadata"]["name"].startswith(allowed_start)
            for allowed_start in allowed_starts_with
        )
