# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import pytest

from . import component_details, values_files_with_service_monitors


def verify_all_expected_services_monitors_presence(templates, expected_service_monitors):
    found_service_monitors = list()
    for template in templates:
        if template["kind"] == "ServiceMonitor":
            found_service_monitors.append(template["metadata"]["name"])

    assert set(expected_service_monitors) == set(found_service_monitors)


@pytest.mark.parametrize("values_file", values_files_with_service_monitors)
@pytest.mark.asyncio_cooperative
async def test_all_components_and_sub_components_has_service_monitor(component, values, make_templates):
    origin_values = values.copy()
    expected_service_monitors = list()

    current_sub_components = component_details[component]["sub_components"]
    sub_components_with_service_monitors = {
        sub_component: current_sub_components[sub_component]
        for sub_component in current_sub_components
        if current_sub_components[sub_component]["has_service_monitor"]
    }
    # First, we disable top-level component service monitors
    # And make sure all subcomponent service monitors are rendered
    values[component].setdefault("serviceMonitors", {}).setdefault("enabled", False)
    for sub_component in sub_components_with_service_monitors:
        expected_service_monitors.append(f"pytest-{component}-{sub_component}")

    verify_all_expected_services_monitors_presence(await make_templates(values), expected_service_monitors)

    # Second, we disable subcomponent service monitors independently
    # And make sure top-level component service monitors are rendered,
    # as well as independent subcomponent service monitors
    for turned_off_sub_component in component_details[component]["sub_components"]:
        # Subcomponents that don't have service monitors don't need to be tested
        if not component_details[component]["sub_components"][turned_off_sub_component]["has_service_monitor"]:
            continue

        values = origin_values.copy()
        expected_service_monitors = list()
        values[component].setdefault(turned_off_sub_component, {}).setdefault("serviceMonitors", {}).setdefault(
            "enabled", False
        )
        for sub_component in sub_components_with_service_monitors:
            if turned_off_sub_component != sub_component:
                expected_service_monitors.append(f"pytest-{component}-{sub_component}")

        verify_all_expected_services_monitors_presence(await make_templates(values), expected_service_monitors)
