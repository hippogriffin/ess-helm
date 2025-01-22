# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: LicenseRef-Element-Commercial

import re

import pytest

from . import values_files_to_test
from .utils import get_or_empty


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_secrets_consistency(templates):
    """
    Test to ensure that all secrets are properly mounted and consistent across the cluster.

    This test checks if each secret is correctly associated with its respective volume and container,
    ensuring that no inconsistencies or missing configurations exist.
    """
    secrets = [t for t in templates if t["kind"] == "Secret"]
    workloads = [t for t in templates if t["kind"] in ("Deployment", "StatefulSet")]
    for template in workloads:
        # Gather all containers and initContainers from the template spec
        containers = template["spec"]["template"]["spec"].get("containers", []) + template["spec"]["template"][
            "spec"
        ].get("initContainers", [])

        for container in containers:
            # Determine which secrets are mounted by this container
            mounted_secrets = []

            for volume_mount in container.get("volumeMounts", []):
                current_volume = None
                # Find the corresponding secret volume that matches the volume mount name
                for v in template["spec"]["template"]["spec"].get("volumes", []):
                    if volume_mount["name"] == v["name"]:
                        current_volume = v
                        break
                else:
                    raise ValueError(
                        f"No matching volume found for mount path {volume_mount['mountPath']} in "
                        f"[{','.join(template['spec'].get('volumes', []))}]"
                    )
                if "secret" not in current_volume:
                    # Skip this volume mount as it's not a secret
                    continue

                # Extract the paths where this volume's secrets are mounted
                for secret in secrets:
                    if current_volume["secret"]["secretName"] == secret["metadata"]["name"]:
                        # When secret data is empty, `data:` is None, so use `get_or_empty`
                        for key in get_or_empty(secret, "data"):
                            mounted_path = f"{volume_mount['mountPath']}/{key}"
                            mounted_secrets.append(mounted_path)
                        break
                else:
                    raise ValueError(
                        f"Secret name '{current_volume['secret']['secretName']}' does not match any secret"
                    )

                # Parse container commands to find potential mounted secrets
                # Make sure that potential mounted secrets are present in mounted secrets
                for matches in re.findall(
                    rf"{volume_mount['mountPath']}/([A-Za-z0-9._]+)", "\n".join(container.get("command", []))
                ):
                    assert f"{volume_mount['mountPath']}/{matches}" in mounted_secrets, (
                        f"{volume_mount['mountPath']}/{matches} used in container {container['name']} "
                        + "but it is not found from any mounted secret"
                    )
