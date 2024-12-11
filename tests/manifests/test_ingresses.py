# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import pytest

from . import components_to_test, components_with_ingresses


@pytest.mark.parametrize("component", components_to_test)
@pytest.mark.asyncio_cooperative
async def test_has_ingress(component, templates):
    has_ingress = False
    for template in templates:
        if template["kind"] == "Ingress":
            has_ingress = True

    assert has_ingress == (component in components_with_ingresses)


@pytest.mark.parametrize("component", components_with_ingresses)
@pytest.mark.asyncio_cooperative
async def test_ingress_is_expected_host(component, values, templates):
    for template in templates:
        if template["kind"] == "Ingress":
            assert "rules" in template["spec"]
            assert len(template["spec"]["rules"]) > 0

            for rule in template["spec"]["rules"]:
                assert "host" in rule
                assert rule["host"] == values[component]["ingress"]["host"]


@pytest.mark.parametrize("component", components_with_ingresses)
@pytest.mark.asyncio_cooperative
async def test_ingress_paths_are_all_prefix(component, templates):
    for template in templates:
        if template["kind"] == "Ingress":
            assert "rules" in template["spec"]
            assert len(template["spec"]["rules"]) > 0

            for rule in template["spec"]["rules"]:
                assert "http" in rule
                assert "paths" in rule["http"]
                for path in rule["http"]["paths"]:
                    assert "pathType" in path

                    # Exact would be ok, but ImplementationSpecifc is unacceptable as we don't know the implementation
                    assert path["pathType"] == "Prefix"


@pytest.mark.parametrize("component", components_with_ingresses)
@pytest.mark.asyncio_cooperative
async def test_no_ingress_annotations_by_default(component, templates):
    for template in templates:
        if template["kind"] == "Ingress":
            assert "annotations" not in template["metadata"]


@pytest.mark.parametrize("component", components_with_ingresses)
@pytest.mark.asyncio_cooperative
async def test_renders_component_ingress_annotations(component, values, make_templates):
    values[component]["ingress"]["annotations"] = {
        "component": "set",
    }

    for template in await make_templates(values):
        if template["kind"] == "Ingress":
            assert "annotations" in template["metadata"]
            assert "component" in template["metadata"]["annotations"]
            assert template["metadata"]["annotations"]["component"] == "set"


@pytest.mark.parametrize("component", components_with_ingresses)
@pytest.mark.asyncio_cooperative
async def test_renders_global_ingress_annotations(component, values, make_templates):
    values.setdefault("ingress", {})["annotations"] = {
        "global": "set",
    }

    for template in await make_templates(values):
        if template["kind"] == "Ingress":
            assert "annotations" in template["metadata"]
            assert "global" in template["metadata"]["annotations"]
            assert template["metadata"]["annotations"]["global"] == "set"


@pytest.mark.parametrize("component", components_with_ingresses)
@pytest.mark.asyncio_cooperative
async def test_merges_global_and_component_ingress_annotations(component, values, make_templates):
    values[component]["ingress"]["annotations"] = {
        "component": "set",
        "merged": "from_component",
        "global": None,
    }
    values.setdefault("ingress", {})["annotations"] = {
        "global": "set",
        "merged": "from_global",
    }

    for template in await make_templates(values):
        if template["kind"] == "Ingress":
            assert "annotations" in template["metadata"]
            assert "component" in template["metadata"]["annotations"]
            assert template["metadata"]["annotations"]["component"] == "set"

            assert "merged" in template["metadata"]["annotations"]
            assert template["metadata"]["annotations"]["merged"] == "from_component"

            # The key is still in the template but it renders as null (Python None)
            # And the k8s API will then filter it out
            assert "global" in template["metadata"]["annotations"]
            assert template["metadata"]["annotations"]["global"] is None


@pytest.mark.parametrize("component", components_with_ingresses)
@pytest.mark.asyncio_cooperative
async def test_no_ingress_tlsSecret_by_default(component, templates):
    for template in templates:
        if template["kind"] == "Ingress":
            assert "tls" not in template["spec"]


@pytest.mark.parametrize("component", components_with_ingresses)
@pytest.mark.asyncio_cooperative
async def test_uses_component_ingress_tlsSecret(component, values, make_templates):
    values[component]["ingress"]["tlsSecret"] = "component"

    for template in await make_templates(values):
        if template["kind"] == "Ingress":
            assert "tls" in template["spec"]
            assert len(template["spec"]["tls"]) == 1
            assert len(template["spec"]["tls"][0]["hosts"]) == 1
            assert template["spec"]["tls"][0]["hosts"][0] == template["spec"]["rules"][0]["host"]
            assert template["spec"]["tls"][0]["secretName"] == "component"


@pytest.mark.parametrize("component", components_with_ingresses)
@pytest.mark.asyncio_cooperative
async def test_uses_global_ingress_tlsSecret(component, values, make_templates):
    values.setdefault("ingress", {})["tlsSecret"] = "global"

    for template in await make_templates(values):
        if template["kind"] == "Ingress":
            assert "tls" in template["spec"]
            assert len(template["spec"]["tls"]) == 1
            assert len(template["spec"]["tls"][0]["hosts"]) == 1
            assert template["spec"]["tls"][0]["hosts"][0] == template["spec"]["rules"][0]["host"]
            assert template["spec"]["tls"][0]["secretName"] == "global"


@pytest.mark.parametrize("component", components_with_ingresses)
@pytest.mark.asyncio_cooperative
async def test_component_ingress_tlsSecret_beats_global(component, values, make_templates):
    values[component]["ingress"]["tlsSecret"] = "component"
    values.setdefault("ingress", {})["tlsSecret"] = "global"

    for template in await make_templates(values):
        if template["kind"] == "Ingress":
            assert "tls" in template["spec"]
            assert len(template["spec"]["tls"]) == 1
            assert len(template["spec"]["tls"][0]["hosts"]) == 1
            assert template["spec"]["tls"][0]["hosts"][0] == template["spec"]["rules"][0]["host"]
            assert template["spec"]["tls"][0]["secretName"] == "component"


@pytest.mark.parametrize("component", components_with_ingresses)
@pytest.mark.asyncio_cooperative
async def test_no_ingressClassName_by_default(component, templates):
    for template in templates:
        if template["kind"] == "Ingress":
            assert "ingressClassName" not in template["spec"]


@pytest.mark.parametrize("component", components_with_ingresses)
@pytest.mark.asyncio_cooperative
async def test_uses_component_ingressClassName(component, values, make_templates):
    values[component]["ingress"]["className"] = "component"

    for template in await make_templates(values):
        if template["kind"] == "Ingress":
            assert "ingressClassName" in template["spec"]
            assert template["spec"]["ingressClassName"] == "component"


@pytest.mark.parametrize("component", components_with_ingresses)
@pytest.mark.asyncio_cooperative
async def test_uses_global_ingressClassName(component, values, make_templates):
    values.setdefault("ingress", {})["className"] = "global"

    for template in await make_templates(values):
        if template["kind"] == "Ingress":
            assert "ingressClassName" in template["spec"]
            assert template["spec"]["ingressClassName"] == "global"


@pytest.mark.parametrize("component", components_with_ingresses)
@pytest.mark.asyncio_cooperative
async def test_component_ingressClassName_beats_global(component, values, make_templates):
    values[component]["ingress"]["className"] = "component"
    values.setdefault("ingress", {})["className"] = "global"

    for template in await make_templates(values):
        if template["kind"] == "Ingress":
            assert "ingressClassName" in template["spec"]
            assert template["spec"]["ingressClassName"] == "component"
