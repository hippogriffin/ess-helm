# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import pytest

from . import values_files_to_test
from .utils import iterate_component_workload_parts


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_sets_nonRoot_uids_gids_in_pod_securityContext_by_default(templates):
    for template in templates:
        if template["kind"] in ["Deployment", "StatefulSet"]:
            id = f"{template['kind']}/{template['metadata']['name']}"

            assert (
                "securityContext" in template["spec"]["template"]["spec"]
            ), f"Pod securityContext unexpectedly absent for {id}"

            pod_securityContext = template["spec"]["template"]["spec"]["securityContext"]

            for idKey in ["runAsUser", "runAsGroup", "fsGroup"]:
                assert idKey in pod_securityContext, f"No {idKey} in {id}'s Pod securityContext"
                assert pod_securityContext[idKey] > 1000, f"Low {idKey} in {id}'s Pod securityContext"

            assert "runAsNonRoot" in pod_securityContext, f"No runAsNonRoot in {id}'s Pod securityContext"
            assert pod_securityContext["runAsNonRoot"], f"{id} is running as root"

            assert (
                pod_securityContext["runAsUser"] == pod_securityContext["runAsGroup"]
            ), f"{id} has distinct uid and gid in the Pod securityContext"
            assert (
                pod_securityContext["runAsGroup"] == pod_securityContext["fsGroup"]
            ), f"{id} has distinct run and FS gids in the Pod securityContext"


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_can_nuke_pod_securityContext_ids(component, values, make_templates):
    iterate_component_workload_parts(
        component,
        values,
        lambda workload, values: workload.setdefault(
            "podSecurityContext", {"runAsUser": None, "runAsGroup": None, "fsGroup": None}
        ),
    )

    for template in await make_templates(values):
        if template["kind"] in ["Deployment", "StatefulSet"]:
            id = f"{template['kind']}/{template['metadata']['name']}"

            assert (
                "securityContext" in template["spec"]["template"]["spec"]
            ), f"Pod securityContext unexpectedly absent for {id}"

            pod_securityContext = template["spec"]["template"]["spec"]["securityContext"]

            for idKey in ["runAsUser", "runAsGroup", "fsGroup"]:
                assert idKey not in pod_securityContext, f"{idKey} set in {id}'s Pod securityContext"


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_sets_seccompProfile_in_pod_securityContext_by_default(templates):
    for template in templates:
        if template["kind"] in ["Deployment", "StatefulSet"]:
            id = f"{template['kind']}/{template['metadata']['name']}"

            assert (
                "securityContext" in template["spec"]["template"]["spec"]
            ), f"Pod securityContext unexpectedly absent for {id}"

            pod_securityContext = template["spec"]["template"]["spec"]["securityContext"]

            assert "seccompProfile" in pod_securityContext, f"No seccompProfile in {id}'s Pod securityContext"
            assert (
                "type" in pod_securityContext["seccompProfile"]
            ), f"No type in {id}'s Pod securityContext.seccompProfile"
            assert (
                pod_securityContext["seccompProfile"]["type"] == "RuntimeDefault"
            ), f"{id} has unexpected seccompProfile type"


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_can_nuke_pod_securityContext_seccompProfile(component, values, make_templates):
    iterate_component_workload_parts(
        component, values, lambda workload, values: workload.setdefault("podSecurityContext", {"seccompProfile": None})
    )

    for template in await make_templates(values):
        if template["kind"] in ["Deployment", "StatefulSet"]:
            id = f"{template['kind']}/{template['metadata']['name']}"

            assert (
                "securityContext" in template["spec"]["template"]["spec"]
            ), f"Pod securityContext unexpectedly absent for {id}"

            pod_securityContext = template["spec"]["template"]["spec"]["securityContext"]

            assert "seccompProfile" not in pod_securityContext, f"seccompProfile set in {id}'s Pod securityContext"
