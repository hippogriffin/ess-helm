# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import json
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import pyhelm3
import pytest
import yaml

from . import component_details, values_files_to_components


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
def values(values_file) -> dict[str, Any]:
    return yaml.safe_load((Path("charts/matrix-stack/ci") / values_file).read_text("utf-8"))


@pytest.fixture(scope="function")
async def templates(chart: pyhelm3.Chart, values: dict[str, Any]):
    return list([template for template in await helm_template(chart, "pytest", values) if template is not None])


async def helm_template(chart: pyhelm3.Chart, release_name: str, values: Any | None) -> Iterator[Any]:
    """Generate template with ServiceMonitor API Versions enabled

    The native pyhelm3 template command does expose the --api-versions flag,
    so we implement it here.

    Args:
        chart (pyhelm3.Chart): The chart
        release_name (str): The release name
        values (Any, optional): The values to use

    Returns:
        Iterator[Any]: Iterating on manifests.
    """
    command = [
        "template",
        release_name,
        chart.ref,
        "-a",
        "monitoring.coreos.com/v1/ServiceMonitor",
        # We send the values in on stdin
        "--values",
        "-",
    ]
    return yaml.load_all(
        await pyhelm3.Command().run(command, json.dumps(values or {}).encode()), Loader=yaml.SafeLoader
    )


@pytest.fixture
def make_templates(chart: pyhelm3.Chart):
    async def _make_templates(values):
        return list([template for template in await helm_template(chart, "pytest", values) if template is not None])

    return _make_templates


def iterate_component_workload_parts(component, values, setter):
    if component_details[component]["has_workloads"]:
        setter(values[component], values)
        for sub_component in component_details[component]["sub_components"]:
            setter(values[component].setdefault(sub_component, {}), values)
    for shared_component in component_details[component].get("shared_components", []):
        setter(values.setdefault(shared_component, {}), values)


def get_or_empty(d, key):
    res = d.get(key, {})
    if res is not None:
        return res
    else:
        return {}
