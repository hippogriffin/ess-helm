# Copyright 2025 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import pytest

from . import values_files_to_test


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_unique_ports_in_containers(templates):
    for template in templates:
        if template["kind"] in ["Deployment", "StatefulSet", "Job"]:
            id = f"{template['kind']}/{template['metadata']['name']}"
            ports = []
            for container in template["spec"]["template"]["spec"]["containers"]:
              ports += [port['containerPort'] for port in container.get('ports', [])]
            assert len(ports) == len(set(ports)), f"Ports are not unique: {id}, {ports}"
