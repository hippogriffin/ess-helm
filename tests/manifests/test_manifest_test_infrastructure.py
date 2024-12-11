# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

from pathlib import Path

import pytest

from . import component_details, components_to_test


def test_all_components_covered():
    expected_folders = [details["hyphened_name"] for details in component_details.values()]

    templates_folder = Path(__file__).parent.parent.parent / Path("charts/matrix-stack/templates")
    for contents in templates_folder.iterdir():
        if not contents.is_dir():
            continue
        if contents.name == "ess-library":
            continue

        assert contents.name in expected_folders


@pytest.mark.parametrize("component", components_to_test)
def test_component_has_minimal_values_file(component):
    ci_folder = Path(__file__).parent.parent.parent / Path("charts/matrix-stack/ci")
    values_file = ci_folder / Path(component_details[component]["minimal_values_file"])
    assert values_file.exists()
