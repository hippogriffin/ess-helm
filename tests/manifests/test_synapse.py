# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import pytest


@pytest.mark.parametrize("values_file", ["synapse-minimal-values.yaml"])
@pytest.mark.asyncio_cooperative
async def test_appservice_configmaps_are_templated(release_name, values, make_templates):
    values["synapse"].setdefault("appservices", []).append({"registrationFileConfigMap": "as-{{ $.Release.Name }}"})

    for template in await make_templates(values):
        if template["kind"] == "StatefulSet":
            for volume in template["spec"]["template"]["spec"]["volumes"]:
                if (
                    "configMap" in volume
                    and volume["configMap"]["name"] == f"as-{release_name}"
                    and volume["name"] == f"as-{release_name}"
                ):
                    break
            else:
                raise AssertionError("The appservice configMap wasn't included in the volumes")

            for volumeMount in template["spec"]["template"]["spec"]["containers"][0]["volumeMounts"]:
                if (
                    volumeMount["name"] == f"as-{release_name}"
                    and volumeMount["mountPath"] == f"/as/as-{release_name}/registration.yaml"
                ):
                    break
            else:
                raise AssertionError("The appservice configMap isn't mounted at the expected location")
