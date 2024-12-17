# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import copy
from typing import Any, Iterator, Set

import pytest

from . import component_details, values_files_with_service_monitors


def selector_match(labels, selector):
    return all(labels[key] == value for key, value in selector.items())


def find_service_matching_selector(templates, selector):
    result = None
    for template in templates:
        if template["kind"] == "Service" and selector_match(template["metadata"]["labels"], selector):
            if result:
                raise Exception(
                    "Found more than one service matching selector : "
                    f"{template['metadata']['name']} "
                    "and "
                    f"{result['metadata']['name']}"
                )
            result = template
    return result


def find_workload_matching_selector(templates, selector):
    result = None
    for template in templates:
        if template["kind"] in ("Deployment", "StatefulSet") and selector_match(
            template["spec"]["template"]["metadata"]["labels"], selector
        ):
            if result:
                raise Exception(
                    "Found more than one workload matching selector : "
                    f"{template['metadata']['name']} "
                    "and "
                    f"{result['metadata']['name']}"
                )
            result = template

    return result


def service_monitor_to_workload_name(service_monitor, templates):
    service = find_service_matching_selector(templates, service_monitor["spec"]["selector"]["matchLabels"])
    assert service is not None
    workload = find_workload_matching_selector(templates, service["metadata"]["labels"])
    assert workload is not None
    return workload["metadata"]["name"]


def get_service_monitors(component: str, sub_component: str, templates: Iterator[Any]):
    """We read all rendered templated and associate found service monitors to current component/subcomponent

    We expect service monitors to be associated to the workload of the component/subcomponent they monitor

    Args:
        component (_type_): _description_
        sub_component (_type_): _description_
        templates (_type_): _description_

    Returns:
        _type_: _description_
    """
    if sub_component and component_details[component]["sub_components"][sub_component].get("service_monitors_override"):
        return set(component_details[component]["sub_components"][sub_component]["service_monitors_override"])
    elif not sub_component and component_details[component].get("service_monitors_override"):
        return set(component_details[component]["service_monitors_override"])
    return set(
        service_monitor_to_workload_name(template, templates)
        for template in templates
        if template["kind"] == "ServiceMonitor"
    )


def verify_all_expected_services_monitors_presence(
    templates: Iterator[Any], expected_service_monitors: Set[str], excluded_service_monitors: Set[str]
):
    """We read all rendered template and verify that all expected service monitors are present
    and that excluded service monitors are not

    Args:
        templates (Iterator[Any]): Rendered template for current values with 1 excluded component service monitors
        expected_service_monitors (Set[str]): Service monitors expected to be present
        excluded_service_monitors (Set[str]): Service monitors expected to be excluded
    """
    found_service_monitors = set()

    for template in templates:
        if template["kind"] == "ServiceMonitor":
            found_service_monitors.add(template["metadata"]["name"])

    assert set(*expected_service_monitors.values()) == found_service_monitors
    assert len(set.intersection(excluded_service_monitors, found_service_monitors)) == 0


async def initialize_service_monitors(component: str, values: Any, make_templates):
    """This method renders templates by enabling service monitors for each component & sub component one by one.
    Each component is associated with a set of service monitor names.
    This method asserts that no two service monitors share the same name

    Args:
        component (str): The component name
        values (Any): The values to use for these components
        make_templates (_type_): The function to use to render the templates

    Returns:
        dict: A dictionary containing the service monitors found for each component
    """
    # We disable rendering of all service monitors
    values[component].setdefault("serviceMonitors", {}).setdefault("enabled", False)
    for sub_component in component_details[component]["sub_components"]:
        # Subcomponents that don't have service monitors don't need to be tested
        if not component_details[component]["sub_components"][sub_component]["has_service_monitor"]:
            continue
        values[component].setdefault(sub_component, {}).setdefault("serviceMonitors", {}).setdefault("enabled", False)

    components_services_monitors = {}

    # We then render each component one by one, and extract its service monitor
    values[component]["serviceMonitors"]["enabled"] = True
    components_services_monitors[component] = get_service_monitors(component, None, await make_templates(values))
    values[component]["serviceMonitors"]["enabled"] = False

    for sub_component in component_details[component]["sub_components"]:
        # Subcomponents that don't have service monitors don't need to be tested
        if not component_details[component]["sub_components"][sub_component]["has_service_monitor"]:
            continue

        values[component][sub_component]["serviceMonitors"]["enabled"] = True
        components_services_monitors[f"{component}-{sub_component}"] = get_service_monitors(
            component, sub_component, await make_templates(values)
        )
        values[component][sub_component]["serviceMonitors"]["enabled"] = False

    # Individual components and subcomponents should not share any ServiceMonitors
    assert set.intersection(*components_services_monitors.values()) == set()
    return components_services_monitors


@pytest.mark.parametrize("values_file", values_files_with_service_monitors)
@pytest.mark.asyncio_cooperative
async def test_all_components_and_sub_components_has_service_monitor(component, values: dict, make_templates):
    """This test generates all service monitors of each component & sub component one by one.
    Each component is associated with a set of service monitor names.

    Then, we render disable each component independently, and look for all service monitors rendered
    We expect all service monitors rendered to have the same name as the component or subcomponent workload

    Args:
        component (_type_): _description_
        values (dict): _description_
        make_templates (_type_): _description_
    """
    origin_values = copy.deepcopy(values)

    # First, we render all components and subcomponents service monitors one by one
    # We are going to detect the workloads they monitor
    # This workload name is the name we expect to find
    all_components_services_monitors = await initialize_service_monitors(
        component, copy.deepcopy(values), make_templates
    )

    # We start testing by disabling top-level component service monitors
    values[component].setdefault("serviceMonitors", {}).setdefault("enabled", False)

    # We test that all service monitors are present, except for the top-level component
    components_services_monitors = all_components_services_monitors.copy()
    excluded_service_monitors = components_services_monitors.pop(component)
    verify_all_expected_services_monitors_presence(
        await make_templates(values), components_services_monitors, excluded_service_monitors
    )

    # Second, we disable subcomponent service monitors independently
    # And make sure top-level component service monitors are rendered,
    # as well as independent subcomponent service monitors
    # We make sure that excluded service monitors are not rendered
    for turned_off_sub_component in component_details[component]["sub_components"]:
        # Subcomponents that don't have service monitors don't need to be tested
        if not component_details[component]["sub_components"][turned_off_sub_component]["has_service_monitor"]:
            continue

        values = copy.deepcopy(origin_values)
        values[component].setdefault(turned_off_sub_component, {}).setdefault("serviceMonitors", {}).setdefault(
            "enabled", False
        )

        components_services_monitors = all_components_services_monitors.copy()
        excluded_service_monitors = components_services_monitors.pop(f"{component}-{turned_off_sub_component}")

        verify_all_expected_services_monitors_presence(
            await make_templates(values), components_services_monitors, excluded_service_monitors
        )
