# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import copy
from typing import Any, Dict

_raw_component_details = {
    "elementWeb": {"hyphened_name": "element-web"},
    "synapse": {},
}


def _enrich_components_to_test() -> Dict[str, Any]:
    _component_details = copy.deepcopy(_raw_component_details)
    for component, details in _raw_component_details.items():
        if "hyphened_name" not in details:
            _component_details[component]["hyphened_name"] = component

        _component_details[component]["minimal_values_file"] = (
            f"{_component_details[component]["hyphened_name"]}-minimal-values.yaml"
        )
    return _component_details


component_details = _enrich_components_to_test()
components_to_test = component_details.keys()
