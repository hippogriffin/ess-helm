# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import copy
from typing import Any

_raw_shared_components_details = {
    "initSecrets": {
        "hyphened_name": "init-secrets",
        "has_image": False,
        "has_service_monitor": False,
        "has_ingress": False,
    },
    "haproxy": {},
}

_raw_component_details = {
    "elementWeb": {
        "hyphened_name": "element-web",
        "has_service_monitor": False,
    },
    "matrixAuthenticationService": {
        "hyphened_name": "matrix-authentication-service",
        "shared_components": ["initSecrets"],
    },
    "synapse": {
        "additional_values_files": [
            "synapse-worker-example-values.yaml",
        ],
        "sub_components": {
            "redis": {
                "has_service_monitor": False,
            },
        },
        "shared_components": ["initSecrets", "haproxy"],
    },
    "wellKnownDelegation": {
        "hyphened_name": "well-known",
        "has_service_monitor": False,
        "has_image": False,
        "has_workloads": False,
        "shared_components": ["haproxy"],
    },
}


def _enrich_components_to_test(details) -> dict[str, Any]:
    _component_details = copy.deepcopy(details)
    for component in details:
        _component_details[component].setdefault("hyphened_name", component)

        values_files = _component_details[component].setdefault("additional_values_files", [])
        values_files.append(f"{_component_details[component]['hyphened_name']}-minimal-values.yaml")
        _component_details[component]["values_files"] = values_files
        del _component_details[component]["additional_values_files"]

        _component_details[component].setdefault("has_ingress", True)
        _component_details[component].setdefault("has_service_monitor", True)
        _component_details[component].setdefault("has_workloads", True)
        _component_details[component].setdefault("has_image", True)
        _component_details[component].setdefault("sub_components", {})
        for sub_component in _component_details[component]["sub_components"]:
            _component_details[component]["sub_components"][sub_component].setdefault("has_service_monitor", True)
    return _component_details


component_details = _enrich_components_to_test(_raw_component_details)
shared_components_details = _enrich_components_to_test(_raw_shared_components_details)

values_files_to_components = {
    values_file: component
    for component, details in component_details.items()
    for values_file in details["values_files"]
}
values_files_to_test = values_files_to_components.keys()
values_files_with_ingresses = [
    values_file
    for values_file, component in values_files_to_components.items()
    if component_details[component]["has_ingress"]
]
