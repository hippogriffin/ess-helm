# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only

import random

import pytest
import yaml

from . import values_files_to_test
from .utils import helm_template, template_id


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_values_file_renders_idempotent_pods(release_name, values, helm_client, temp_chart):
    async def _patch_version_chart():
        with open(f"{temp_chart}/Chart.yaml") as f:
            chart = yaml.safe_load(f)
        with open(f"{temp_chart}/Chart.yaml", "w") as f:
            chart["version"] = f"{random.randint(0, 100)}.{random.randint(0, 100)}.0"
            yaml.dump(chart, f)
        return await helm_client.get_chart(temp_chart)

    first_render = {}
    second_render = {}
    for template in await helm_template(
        (await _patch_version_chart()), release_name, values, has_service_monitor_crd=True, skip_cache=True
    ):
        if template["kind"] in ["Deployment", "StatefulSet", "Job"]:
            first_render[template_id(template)] = template
    for template in await helm_template(
        (await _patch_version_chart()), release_name, values, has_service_monitor_crd=True, skip_cache=True
    ):
        if template["kind"] in ["Deployment", "StatefulSet", "Job"]:
            second_render[template_id(template)] = template

    assert set(first_render.keys()) == set(second_render.keys()), "Values file should render the same templates"
    for id in first_render:
        assert first_render[id]["spec"]["template"] == second_render[id]["spec"]["template"], (
            f"Template Pod {id} should be rendered the same twice if only the chart version changes"
        )
