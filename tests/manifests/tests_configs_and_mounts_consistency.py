# Copyright 2025 New Vector Ltd
#
# SPDX-License-Identifier: LicenseRef-Element-Commercial

import re

import pytest

from . import component_details, secrets_values_files_to_test, values_files_to_test
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


def get_secret(templates, other_secrets, secret_name):
    """
    Get the content of a Secret with the given name.
    :param secret_name: The name of the Secret to retrieve.
    :return: A string containing the content of the Secret, or an empty string if not found.
    """
    for t in templates:
        if t["kind"] == "Secret" and t["metadata"]["name"] == secret_name:
            return t
    for s in other_secrets:
        if s["metadata"]["name"] == secret_name:
            return s
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
        f"[{','.join([v['name'] for v in template['spec']['template']['spec'].get('volumes', [])])}]"
    )


def match_in_content(container_name, mounted_keys, mount_path, matches_in):
    found_mount = False
    for match_in in matches_in:
        for match in re.findall(rf"{mount_path}/([^\s\n\")`;,]+(?!.*noqa))", match_in):
            assert f"{mount_path}/{match}" in mounted_keys, (
                f"{mount_path}/{match} used in {container_name} but it is not found "
                f"from any mounted secret or configmap"
            )
            found_mount = True
    return found_mount


def get_key_from_render_config(template):
    for container in template["spec"]["template"]["spec"]["initContainers"]:
        if container['name'] == "render-config":
            for idx, cmd in enumerate(container["command"]):
                if cmd == "-output":
                    return container["command"][idx+1].split('/')[-1]
    raise AssertionError(f"{template['kind']}/{template['metadata']['name']} has a rendered-config volume, "
                         "but no render-config output file could be found")


def get_mounts_part(secret_or_cm, volume_mount):
    mounted_keys = []
    if "subPath" in volume_mount:
        mounted_keys.append(volume_mount['mountPath'])
        # The regex tries to find secrets in configfiles, commands & env
        # based on their parent mount point so we drop the filename from
        # the mount path
        mount_parent = "/".join(volume_mount["mountPath"].split("/")[:-1])
    else:
        # When secret data is empty, `data:` is None, so use `get_or_empty`
        for key in get_or_empty(secret_or_cm, "data"):
            # Without subPath, the key will be present as child of the mount path
            mounted_keys.append(f"{volume_mount['mountPath']}/{key}")
        mount_parent = volume_mount["mountPath"]
    return mount_parent, mounted_keys


def get_keys_from_container_using_rendered_config(template, templates, other_secrets):
    mounted_keys = []
    for container in template["spec"]["template"]["spec"]["containers"]:
        if "rendered-config" in [v['name'] for v in container["volumeMounts"]]:
            for volume_mount in container["volumeMounts"]:
                current_volume = get_volume_from_mount(template, volume_mount)
                if "secret" in current_volume:
                    # Extract the paths where this volume's secrets are mounted
                    secret = get_secret(templates, other_secrets, current_volume["secret"]["secretName"])
                    _, keys = get_mounts_part(secret, volume_mount)
                    mounted_keys += keys
                elif "configMap" in current_volume:
                    # Parse config map content
                    configmap = get_configmap(templates, current_volume["configMap"]["name"])
                    _, keys = get_mounts_part(configmap, volume_mount)
                    mounted_keys += keys
    assert len(mounted_keys) > 0
    return mounted_keys


@pytest.mark.parametrize("values_file", values_files_to_test + secrets_values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_secrets_consistency(templates, other_secrets, component):
    """
    Test to ensure that all configmaps and secrets are properly mounted and consistent across the cluster.

    This test checks if each secret and configmap is correctly associated with its respective volume and container,
    ensuring that no inconsistencies or missing configurations exist.

    The test also tries to find some configuration inconsistency. For each env, args, command, and config files,
    it will read its content and find paths matching potential mounted secrets or configmap data.
    If there's a match, it makes sure that it points to an existing data mounted in the container.
    """
    workloads = [t for t in templates if t["kind"] in ("Deployment", "StatefulSet", "Job")]
    for template in workloads:
        # Gather all containers and initContainers from the template spec
        containers = template["spec"]["template"]["spec"].get("containers", []) + template["spec"]["template"][
            "spec"
        ].get("initContainers", [])

        for container in containers:
            # Determine which secrets are mounted by this container
            mounted_keys = []
            mounted_config_maps = []
            mount_paths = []
            mount_parents = []
            uses_rendered_config = False

            for volume_mount in container.get("volumeMounts", []):
                current_volume = get_volume_from_mount(template, volume_mount)
                if "secret" in current_volume:
                    # Extract the paths where this volume's secrets are mounted
                    secret = get_secret(templates, other_secrets, current_volume["secret"]["secretName"])
                    parent, keys = get_mounts_part(secret, volume_mount)
                    mount_paths.append(volume_mount["mountPath"])
                    mount_parents.append(parent)
                    mounted_keys += keys
                elif "configMap" in current_volume:
                    # Parse config map content
                    configmap = get_configmap(templates, current_volume["configMap"]["name"])
                    mounted_config_maps.append(configmap)
                    parent, keys = get_mounts_part(configmap, volume_mount)
                    mount_paths.append(volume_mount["mountPath"])
                    mount_parents.append(parent)
                    mounted_keys += keys
                elif "emptyDir" in current_volume and current_volume["name"] == "rendered-config":
                        # We can't verify rendered-config, it's generated at runtime
                        uses_rendered_config = True
                        mount_paths.append(volume_mount["mountPath"])
                        mount_parents.append(volume_mount["mountPath"])
                        mounted_keys.append(f"{volume_mount['mountPath']}/{get_key_from_render_config(template)}")

            assert len(mounted_keys) == len(set(mounted_keys)), (
                f"Mounted key paths are not unique in {template['metadata']['name']}: {mounted_keys}"
            )
            assert len(mount_paths) == len(set(mount_paths)), (
                f"Secrets mount paths are not unique in {template['metadata']['name']}: {mounted_keys}"
            )

            # If we are checking render-config,
            # we need to look up mounted_keys in the container using the rendered-config
            if container["name"] == "render-config":
                mounted_keys += get_keys_from_container_using_rendered_config(template, templates, other_secrets)


            # We look for all secrets mountPath parents directories in configs and commands
            # And using a regex, make sure that patterns `<parent mount path>/<some key>`
            # refers <some key> to an existing mounted secret key
            for parent_path in mount_parents:
                # If for some path, the configuration cannot be made explicit
                # we add them to the list of exceptions
                # For example, nginx container uses /etc/nginx natively.
                if parent_path in component_details[component]["paths_consistency_noqa"]:
                    continue
                mount_path_found = False

                # Parse container commands to find paths which would match a mounted secret
                # Make sure that paths which match are actually present in mounted secrets
                if match_in_content(
                    f"container {container['name']}",
                    mounted_keys,
                    parent_path,
                    [e.get("value", "") for e in container.get("env", [])]
                    + container.get("command", [])
                    + container.get("args", []),
                ):
                    mount_path_found = True

                # Parse container configmaps to find paths which would match a mounted secret
                # Make sure that paths which match are actually present in mounted secrets
                for cm in mounted_config_maps:
                    for data, content in cm["data"].items():
                        if parent_path == "/docker-entrypoint-initdb.d" or match_in_content(
                            f"configmap {cm['metadata']['name']}/{data} mounted in {container['name']}",
                            mounted_keys,
                            parent_path,
                            [content],
                        ):
                            mount_path_found = True
                if not mount_path_found and not uses_rendered_config:
                    raise AssertionError(
                        f"{parent_path} used in container {container['name']} "
                        f"but no config {','.join([cm['metadata']['name'] for cm in mounted_config_maps])} "
                        f"or env variable, or command is using it"
                    )
