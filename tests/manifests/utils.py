# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

from pathlib import Path
from typing import Any, Dict

import pyhelm3
import pytest
import yaml

from . import component_details


@pytest.fixture(scope="session")
async def helm_client():
    return pyhelm3.Client()


@pytest.fixture(scope="session")
async def chart(helm_client: pyhelm3.Client):
    return await helm_client.get_chart("charts/matrix-stack")


@pytest.fixture(scope="function")
def component(request):
    return request.param


@pytest.fixture(scope="function")
def values(request) -> Dict[str, Any]:
    values_file_marker = request.node.get_closest_marker("values_file")
    if values_file_marker:
        values_file = values_file_marker.args[0]
    else:
        component = request.param
        values_file = component_details[component]["minimal_values_file"]
    return yaml.safe_load((Path("charts/matrix-stack/ci") / values_file).read_text("utf-8"))


@pytest.fixture(scope="function")
async def templates(helm_client: pyhelm3.Client, chart: pyhelm3.Chart, values: Dict[str, Any]):
    return list(await helm_client.template_resources(chart, "pytest", values))


@pytest.fixture
def make_templates(helm_client: pyhelm3.Client, chart: pyhelm3.Chart):
    async def _make_templates(values):
        return list(await helm_client.template_resources(chart, "pytest", values))

    return _make_templates
