# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

from pathlib import Path

import pytest

from . import component_details, shared_components_details, values_files_to_test


def test_all_components_covered():
    expected_folders = [details["hyphened_name"] for details in component_details.values()]

    templates_folder = Path(__file__).parent.parent.parent / Path("charts/matrix-stack/templates")
    for contents in templates_folder.iterdir():
        if not contents.is_dir():
            continue
        if contents.name in ("ess-library",) + tuple(
            k if not v["hyphened_name"] else v["hyphened_name"] for k, v in shared_components_details.items()
        ):
            continue

        assert contents.name in expected_folders


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
def test_component_has_values_file(values_file):
    ci_folder = Path(__file__).parent.parent.parent / Path("charts/matrix-stack/ci")
    values_file = ci_folder / values_file
    assert values_file.exists()
