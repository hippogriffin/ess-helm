# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import pytest

from . import component_details, components_to_test


@pytest.mark.values_file("nothing-enabled-values.yaml")
@pytest.mark.asyncio_cooperative
async def test_nothing_enabled_renders_nothing(templates):
    assert len(templates) == 0


@pytest.mark.parametrize("component", components_to_test)
@pytest.mark.asyncio_cooperative
async def test_minimal_values_file_renders_only_itself(component, templates):
    assert len(templates) > 0

    # We can't easily check that the values file is truely minimal
    # But we can check that it includes no other components
    for template in templates:
        assert template["metadata"]["name"].startswith(f"pytest-{component_details[component]["hyphened_name"]}")
