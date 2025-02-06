# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import pytest

from . import component_details, shared_components_details, values_files_to_test


@pytest.mark.parametrize("values_file", ["nothing-enabled-values.yaml"])
@pytest.mark.asyncio_cooperative
async def test_nothing_enabled_renders_nothing(templates):
    assert len(templates) == 0


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_values_file_renders_only_itself(release_name, component, templates):
    # init-secrets does not render any manifest without any component needing it
    assert len(templates) > 0

    allowed_starts_with = [
        f"{release_name}-{component_details[component]['hyphened_name']}",
    ]
    for shared_component in component_details[component].get("shared_components", []):
        allowed_starts_with.append(f"{release_name}-{shared_components_details[shared_component]['hyphened_name']}")
    for template in templates:
        assert any(template["metadata"]["name"].startswith(allowed_start) for allowed_start in allowed_starts_with), (
            f"{[template['metadata']['name']]} does not start with one of {allowed_starts_with}"
        )
