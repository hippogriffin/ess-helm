# Copyright 2025 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import re

import pytest

from . import values_files_to_test
from .utils import get_or_empty


def get_configmap(templates, configmap_name):
    """
    Get the content of a ConfigMap with the given name.
    :param configmap_name: The name of the ConfigMap to retrieve.
    :return: A string containing the content of the ConfigMap, or an empty string if not found.
    """
    for t in templates:
        if t["kind"] == "ConfigMap" and t["metadata"]["name"] == configmap_name:
            return t
    raise ValueError(f"ConfigMap {configmap_name} not found")


def get_secret(templates, secret_name):
    """
    Get the content of a Secret with the given name.
    :param secret_name: The name of the Secret to retrieve.
    :return: A string containing the content of the Secret, or an empty string if not found.
    """
    for t in templates:
        if t["kind"] == "Secret" and t["metadata"]["name"] == secret_name:
            return t
    raise ValueError(f"Secret {secret_name} not found")


def get_volume_from_mount(template, volume_mount):
    """
    Get a specific volume mount from a given template.
    :param template: The template to search within.
    :param volume_name: The name of the volume to retrieve.
    :return: A dictionary representing the volume mount
    """
    # Find the corresponding secret volume that matches the volume mount name
    for v in template["spec"]["template"]["spec"].get("volumes", []):
        if volume_mount["name"] == v["name"]:
            return v
    raise ValueError(
        f"No matching volume found for mount path {volume_mount['mountPath']} in "
        f"[{','.join(template['spec'].get('volumes', []))}]"
    )


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_secrets_consistency(templates):
    """
    Test to ensure that all secrets are properly mounted and consistent across the cluster.

    This test checks if each secret is correctly associated with its respective volume and container,
    ensuring that no inconsistencies or missing configurations exist.
    """
    workloads = [t for t in templates if t["kind"] in ("Deployment", "StatefulSet")]
    for template in workloads:
        # Gather all containers and initContainers from the template spec
        containers = template["spec"]["template"]["spec"].get("containers", []) + template["spec"]["template"][
            "spec"
        ].get("initContainers", [])

        for container in containers:
            # Determine which secrets are mounted by this container
            mounted_secret_keys = []
            mounted_config_maps = []
            secrets_mount_paths = []
            uses_rendered_config = False

            for volume_mount in container.get("volumeMounts", []):
                current_volume = get_volume_from_mount(template, volume_mount)
                if "secret" in current_volume:
                    # Extract the paths where this volume's secrets are mounted
                    secret = get_secret(templates, current_volume["secret"]["secretName"])
                    if "subPath" in volume_mount:
                        # When using subPath, the key is mounted as the mountPath itself
                        mounted_secret_keys.append(f"{volume_mount['mountPath']}")
                    else:
                        # When secret data is empty, `data:` is None, so use `get_or_empty`
                        for key in get_or_empty(secret, "data"):
                            # Without subPath, the key will be present as child of the mount path
                            mounted_path = f"{volume_mount['mountPath']}/{key}"
                            mounted_secret_keys.append(mounted_path)
                    secrets_mount_paths.append(volume_mount["mountPath"])
                elif "configMap" in current_volume:
                    # Parse config map content
                    mounted_config_maps.append(get_configmap(templates, current_volume["configMap"]["name"]))
                elif "emptyDir" in current_volume and current_volume["name"] == "rendered-config":
                    # We can't verify rendered-config, it's generated at runtime
                    uses_rendered_config = True

            # We look for all secrets mountPath in configs and commands
            # And using a regex, make sure that patterns `<mount path>/<some key>`
            # refers <some key> to an existing mounted secret key
            for mount_path in set(secrets_mount_paths):
                mount_path_found = False
                # Parse container commands to find paths which would match a mounted secret
                # Make sure that paths which match are actually present in mounted secrets
                for matches in re.findall(rf"{mount_path}/([^\s\n);]+)", "\n".join(container.get("command", []))):
                    assert f"{mount_path}/{matches}" in mounted_secret_keys, (
                        f"{mount_path}/{matches} used in container {container['name']} "
                        + "but it is not found from any mounted secret"
                    )
                    mount_path_found = True
                # Parse container configmaps to find paths which would match a mounted secret
                # Make sure that paths which match are actually present in mounted secrets
                for cm in mounted_config_maps:
                    for data, content in cm["data"].items():
                        for matches in re.findall(rf"{mount_path}/([^\s\n);]+)", content):
                            assert f"{mount_path}/{matches}" in mounted_secret_keys, (
                                f"{mount_path}/{matches} used in "
                                f"config {cm['metadata']['name']}/{data} "
                                f"mounted in container {container['name']} "
                                + "but it is not found from any mounted secret"
                            )
                            mount_path_found = True
                if not mount_path_found and not uses_rendered_config:
                    raise AssertionError(
                        f"{volume_mount['mountPath']} used in container {container['name']} "
                        "but no config or command is using it"
                    )
