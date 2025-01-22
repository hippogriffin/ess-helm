# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import copy

import pytest

from . import component_details, values_files_to_test
from .utils import iterate_component_workload_parts


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_dont_automount_serviceaccount_tokens(templates):
    for template in templates:
        if template["kind"] in ["Deployment", "StatefulSet"]:
            id = f"{template['kind']}/{template['metadata']['name']}"

            assert not template["spec"]["template"]["spec"][
                "automountServiceAccountToken"
            ], f"ServiceAccount token automounted for {id}"


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_uses_serviceaccount_named_as_per_pod_controller_by_default(templates):
    workloads_by_id = {}
    serviceaccount_names = set()
    covered_serviceaccount_names = set()
    for template in templates:
        if template["kind"] in ["Deployment", "StatefulSet"]:
            workloads_by_id[f"{template['kind']}/{template['metadata']['name']}"] = template
        elif template["kind"] == "ServiceAccount":
            serviceaccount_names.add(template["metadata"]["name"])

    for id, template in workloads_by_id.items():
        assert (
            "serviceAccountName" in template["spec"]["template"]["spec"]
        ), f"{id} does not set an explicit ServiceAccount"

        serviceaccount_name = template["spec"]["template"]["spec"]["serviceAccountName"]
        covered_serviceaccount_names.add(serviceaccount_name)

        assert serviceaccount_name in serviceaccount_names, f"{id} does not reference a created ServiceAccount"

        # All Synapse workers use the same ServiceAccount. k8s.element.io/synapse-instance is a common label
        # that doesn't have the process type suffixed, so use that
        if "k8s.element.io/synapse-instance" in template["metadata"]["labels"]:
            expected_serviceaccount_name = template["metadata"]["labels"]["k8s.element.io/synapse-instance"]
        else:
            expected_serviceaccount_name = template["metadata"]["name"]
        assert expected_serviceaccount_name == serviceaccount_name, f"{id} uses unexpected ServiceAccount"

    assert serviceaccount_names == covered_serviceaccount_names, f"{id} created ServiceAccounts that it shouldn't have"


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_uses_serviceaccount_named_as_values_if_specified(component, values, make_templates):
    def service_account_name(workload, values):
        workload.setdefault("serviceAccount", {}).setdefault("name", f"{component}-pytest")
        workload.setdefault("labels", {}).setdefault("expected.name", f"{component}-pytest")

    iterate_component_workload_parts(component, values, service_account_name)

    workloads_by_id = {}
    serviceaccount_names = []
    for template in await make_templates(values):
        if template["kind"] in ["Deployment", "StatefulSet"]:
            workloads_by_id[f"{template['kind']}/{template['metadata']['name']}"] = template
        elif template["kind"] == "ServiceAccount":
            serviceaccount_names.append(template["metadata"]["name"])

    for id, template in workloads_by_id.items():
        assert (
            "serviceAccountName" in template["spec"]["template"]["spec"]
        ), f"{id} does not set an explicit ServiceAccount"
        assert (
            template["spec"]["template"]["spec"]["serviceAccountName"] in serviceaccount_names
        ), f"{id} does not reference a created ServiceAccount"
        assert (
            template["metadata"]["labels"]["expected.name"]
            == template["spec"]["template"]["spec"]["serviceAccountName"]
        ), f"{id} uses unexpected ServiceAccount"


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_does_not_create_serviceaccounts_if_configured_not_to(component, values, make_templates):
    def disable_service_account(workload, values):
        values.setdefault(workload, {}).setdefault("serviceAccount", {}).setdefault("create", False)
        values.setdefault(workload, {}).setdefault("labels", {}).setdefault("serviceAccount", "none")

    if component_details[component]["has_workloads"]:
        for sub_component in [""] + list(component_details[component]["sub_components"].keys()):
            sub_component_values = copy.deepcopy(values)
            if sub_component == "":
                disable_service_account(component, sub_component_values)
            else:
                disable_service_account(sub_component, sub_component_values[component])

            workloads_by_id = {}
            serviceaccount_names = set()
            covered_serviceaccount_names = set()
            for template in await make_templates(sub_component_values):
                if template["kind"] in ["Deployment", "StatefulSet"]:
                    id_suffix = f" (for {sub_component})" if sub_component != "" else ""
                    workloads_by_id[f"{template['kind']}/{template['metadata']['name']}{id_suffix}"] = template
                elif template["kind"] == "ServiceAccount":
                    serviceaccount_names.add(template["metadata"]["name"])

            for id, template in workloads_by_id.items():
                assert (
                    "serviceAccountName" in template["spec"]["template"]["spec"]
                ), f"{id} does not set an explicit ServiceAccount"

                serviceaccount_name = template["spec"]["template"]["spec"]["serviceAccountName"]
                if template["metadata"]["labels"].get("serviceAccount", "some") == "none":
                    assert serviceaccount_name not in serviceaccount_names
                else:
                    covered_serviceaccount_names.add(serviceaccount_name)

            assert (
                serviceaccount_names == covered_serviceaccount_names
            ), f"{id} created ServiceAccounts that it shouldn't have"
