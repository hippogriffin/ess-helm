# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only

import pytest

from . import values_files_to_test
from .utils import iterate_deployables_image_parts


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_sets_global_pull_secrets(values, make_templates):
    values["imagePullSecrets"] = [
        {"name": "global-secret"},
    ]
    for template in await make_templates(values):
        if template["kind"] in ["Deployment", "StatefulSet", "Job"]:
            id = f"{template['kind']}/{template['metadata']['name']}"
            assert "imagePullSecrets" in template["spec"]["template"]["spec"], f"{id} should have an imagePullSecrets"
            assert len(template["spec"]["template"]["spec"]["imagePullSecrets"]) == 1, (
                f"Expected {id} to have 1 image pull secret"
            )
            assert template["spec"]["template"]["spec"]["imagePullSecrets"][0]["name"] == "global-secret", (
                f"Expected {id} to have image pull secret '{values['imagePullSecrets'][0]['name']}'"
            )


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_local_pull_secrets(deployables_details, values, base_values, make_templates):
    values["imagePullSecrets"] = [
        {"name": "global-secret"},
    ]
    values.setdefault("matrixTools", {}).setdefault("image", {})["pullSecrets"] = [{"name": "matrix-tools-secret"}]
    iterate_deployables_image_parts(
        deployables_details,
        values,
        lambda values_fragment, deployable_details: values_fragment.setdefault(
            "image", {"pullSecrets": [{"name": "local-secret"}]}
        ),
    )

    for template in await make_templates(values):
        if template["kind"] in ["Deployment", "StatefulSet", "Job"]:
            id = f"{template['kind']}/{template['metadata']['name']}"
            any_container_uses_matrix_tools_image = any(
                [
                    base_values["matrixTools"]["image"]["repository"] in x["image"]
                    for x in (
                        template["spec"]["template"]["spec"]["containers"]
                        + template["spec"]["template"]["spec"].get("initContainers", [])
                    )
                ]
            )
            containers_with_matrix_tools_image = [
                base_values["matrixTools"]["image"]["repository"] in x["image"]
                for x in (
                    template["spec"]["template"]["spec"]["containers"]
                    + template["spec"]["template"]["spec"].get("initContainers", [])
                )
            ]
            any_container_uses_matrix_tools_image = any(containers_with_matrix_tools_image)
            containers_only_uses_matrix_tools_image = all(containers_with_matrix_tools_image)

            assert "imagePullSecrets" in template["spec"]["template"]["spec"], f"{id} should have an imagePullSecrets"

            secret_names = [x["name"] for x in template["spec"]["template"]["spec"]["imagePullSecrets"]]
            if containers_only_uses_matrix_tools_image:
                assert len(template["spec"]["template"]["spec"]["imagePullSecrets"]) == 2, (
                    f"Expected {id} to have 2 image pull secrets"
                )
                assert "matrix-tools-secret" in secret_names and "global-secret" in secret_names, (
                    f"Expected {id} to have image pull secret names: local-secret, global-secret, "
                    f"got {','.join(secret_names)}"
                )

            elif any_container_uses_matrix_tools_image:
                assert len(template["spec"]["template"]["spec"]["imagePullSecrets"]) == 3, (
                    f"Expected {id} to have 3 image pull secrets"
                )

                assert "matrix-tools-secret" in secret_names, (
                    f"Expected {id} to have image pull secret names: "
                    f"local-secret, global-secret, matrix-tools-secret, got {','.join(secret_names)}"
                )
            else:
                assert len(template["spec"]["template"]["spec"]["imagePullSecrets"]) == 2, (
                    f"Expected {id} to have 2 image pull secrets"
                )
                assert "local-secret" in secret_names and "global-secret" in secret_names, (
                    f"Expected {id} to have image pull secret names: local-secret, global-secret, "
                    f"got {','.join(secret_names)}"
                )
