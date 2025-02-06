# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

from typing import Any, Dict, Iterator

import pytest

from . import component_details, shared_components_details, values_files_to_test


def selector_match(labels: Dict[str, str], selector: Dict[str, str]) -> bool:
    return all(labels[key] == value for key, value in selector.items())


def find_services_matching_selector(templates: Iterator[Any], selector: Dict[str, str]) -> list[Any]:
    services = []
    for template in templates:
        if template["kind"] == "Service" and selector_match(template["metadata"]["labels"], selector):
            services.append(template)
    return services


def find_workload_ids_matching_selector(templates: Iterator[Any], selector: Dict[str, str]) -> list[str]:
    workload_ids = []
    for template in templates:
        if template["kind"] in ("Deployment", "StatefulSet", "Job") and selector_match(
            template["spec"]["template"]["metadata"]["labels"], selector
        ):
            workload_ids.append(f"{template['kind']}/{template['metadata']['name']}")

    return workload_ids


def workload_ids_for_service_monitor(service_monitor, templates) -> set[str]:
    services = find_services_matching_selector(templates, service_monitor["spec"]["selector"]["matchLabels"])
    assert len(services) > 0, f"No Services behind ServiceMonitor {service_monitor['metadata']['name']}"

    workload_ids = []
    for service in services:
        workload_ids.extend(find_workload_ids_matching_selector(templates, service["spec"]["selector"]))

    assert len(workload_ids) > 0, f"No workloads behind ServiceMonitor {service_monitor['metadata']['name']}"
    assert len(workload_ids) == len(set(workload_ids)), (
        f"ServiceMonitor {service_monitor['metadata']['name']} covers same workloads multiple times"
    )
    return set(workload_ids)


def workload_ids_monitored(templates: Iterator[Any]) -> set[str]:
    workload_ids_monitored = set()
    for template in templates:
        if template["kind"] == "ServiceMonitor":
            these_monitored_workload_ids = workload_ids_for_service_monitor(template, templates)
            assert workload_ids_monitored.intersection(these_monitored_workload_ids) == set(), (
                "Multiple ServiceMonitors cover the same workload"
            )
            workload_ids_monitored.update(these_monitored_workload_ids)

    return workload_ids_monitored


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_service_monitored_as_appropriate(component, values: dict, make_templates):
    # If the component and all its sub-components don't have ServiceMonitors we should assert that
    if (
        not component_details[component]["has_service_monitor"]
        and not any(
            [sub_component["has_service_monitor"] for sub_component in component_details[component]["sub_components"]]
        )
        and not any(
            shared_components_details[shared_component].get("has_service_monitor", True)
            for shared_component in component_details[component].get("shared_components", [])
        )
    ):
        for template in await make_templates(values):
            assert template["kind"] != "ServiceMonitor", f"{component} unexpectedly has a ServiceMonitor: {template=}"

        return

    if component_details[component]["has_service_monitor"]:
        # We disable rendering of all service monitors as they're default enabled
        values[component].setdefault("serviceMonitors", {}).setdefault("enabled", False)
    for sub_component in component_details[component]["sub_components"]:
        # Subcomponents that don't have service monitors don't need to be tested
        if component_details[component]["sub_components"][sub_component]["has_service_monitor"]:
            values[component].setdefault(sub_component, {}).setdefault("serviceMonitors", {}).setdefault(
                "enabled", False
            )
        else:
            values[component].setdefault(sub_component, {}).setdefault("labels", {}).setdefault(
                "servicemonitor", "none"
            )
    for shared_component in component_details[component].get("shared_components", []):
        if shared_components_details[shared_component]["has_service_monitor"]:
            values.setdefault(shared_component, {}).setdefault("serviceMonitors", {}).setdefault("enabled", False)

    # We should now have no ServiceMonitors rendered
    workloads_to_cover = set()
    for template in await make_templates(values):
        assert template["kind"] != "ServiceMonitor", (
            f"{component} unexpectedly has a ServiceMonitor when all are turned off"
        )
        if (
            template["kind"] in ["Deployment", "StatefulSet", "Job"]
            and template["metadata"]["labels"].get("servicemonitor", "some") != "none"
        ):
            workloads_to_cover.add(f"{template['kind']}/{template['metadata']['name']}")

    seen_covered_workloads = set[str]()

    if component_details[component]["has_service_monitor"]:
        # We then render each component one by one, and extract its service monitor
        values[component]["serviceMonitors"]["enabled"] = True
        seen_covered_workloads.update(workload_ids_monitored(await make_templates(values)))
        values[component]["serviceMonitors"]["enabled"] = False

    for sub_component in component_details[component]["sub_components"]:
        # Subcomponents that don't have service monitors don't need to be tested
        if not component_details[component]["sub_components"][sub_component]["has_service_monitor"]:
            continue

        values[component][sub_component]["serviceMonitors"]["enabled"] = True

        # Individual components and subcomponents should not share any ServiceMonitors
        sub_component_workload_ids = workload_ids_monitored(await make_templates(values))
        assert seen_covered_workloads.intersection(sub_component_workload_ids) == set()
        seen_covered_workloads.update(sub_component_workload_ids)

        values[component][sub_component]["serviceMonitors"]["enabled"] = False

    for shared_component in component_details[component]["shared_components"]:
        if shared_components_details[shared_component]["has_service_monitor"]:
            values.setdefault(shared_component, {})["serviceMonitors"]["enabled"] = True
            # Shared components should not share any ServiceMonitors
            shared_component_workload_ids = workload_ids_monitored(await make_templates(values))
            assert seen_covered_workloads.intersection(shared_component_workload_ids) == set()
            seen_covered_workloads.update(shared_component_workload_ids)
            values[shared_component]["serviceMonitors"]["enabled"] = False

    assert seen_covered_workloads.symmetric_difference(workloads_to_cover) == set()
