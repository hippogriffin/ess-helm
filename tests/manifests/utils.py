# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

from pathlib import Path
from typing import Any, Dict

import pyhelm3
import pytest
import yaml

from . import values_files_to_components


@pytest.fixture(scope="session")
async def helm_client():
    return pyhelm3.Client()


@pytest.fixture(scope="session")
async def chart(helm_client: pyhelm3.Client):
    return await helm_client.get_chart("charts/matrix-stack")


@pytest.fixture(scope="function")
def component(values_file):
    return values_files_to_components[values_file]


@pytest.fixture(scope="function")
def values(values_file) -> Dict[str, Any]:
    return yaml.safe_load((Path("charts/matrix-stack/ci") / values_file).read_text("utf-8"))


@pytest.fixture(scope="function")
async def templates(helm_client: pyhelm3.Client, chart: pyhelm3.Chart, values: Dict[str, Any]):
    return list(
        [template for template in await helm_client.template_resources(chart, "pytest", values) if template is not None]
    )


@pytest.fixture
def make_templates(helm_client: pyhelm3.Client, chart: pyhelm3.Chart):
    async def _make_templates(values):
        return list(
            [
                template
                for template in await helm_client.template_resources(chart, "pytest", values)
                if template is not None
            ]
        )

    return _make_templates
