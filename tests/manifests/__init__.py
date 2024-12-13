# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import copy
from typing import Any, Dict

_raw_component_details = {
    "elementWeb": {
        "hyphened_name": "element-web",
    },
    "synapse": {
        "additional_values_files": [
            "synapse-worker-example-values.yaml",
        ]
    },
}


def _enrich_components_to_test() -> Dict[str, Any]:
    _component_details = copy.deepcopy(_raw_component_details)
    for component in _raw_component_details:
        _component_details[component].setdefault("hyphened_name", component)

        values_files = _component_details[component].setdefault("additional_values_files", [])
        values_files.append(f"{_component_details[component]["hyphened_name"]}-minimal-values.yaml")
        _component_details[component]["values_files"] = values_files
        del _component_details[component]["additional_values_files"]

        _component_details[component].setdefault("has_ingress", True)
    return _component_details


component_details = _enrich_components_to_test()

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
