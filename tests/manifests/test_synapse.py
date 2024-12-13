# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import pytest


@pytest.mark.parametrize("values_file", ["synapse-minimal-values.yaml"])
@pytest.mark.asyncio_cooperative
async def test_appservice_configmaps_are_templated(values, make_templates):
    values["synapse"].setdefault("appservices", []).append({"registrationFileConfigMap": "as-{{ $.Release.Name }}"})

    for template in await make_templates(values):
        if template["kind"] == "StatefulSet":
            for volume in template["spec"]["template"]["spec"]["volumes"]:
                if (
                    "configMap" in volume
                    and volume["configMap"]["name"] == "as-pytest"
                    and volume["name"] == "as-pytest"
                ):
                    break
            else:
                raise AssertionError("The appservice configMap wasn't included in the volumes")

            for volumeMount in template["spec"]["template"]["spec"]["containers"][0]["volumeMounts"]:
                if volumeMount["name"] == "as-pytest" and volumeMount["mountPath"] == "/as/as-pytest/registration.yaml":
                    break
            else:
                raise AssertionError("The appservice configMap isn't mounted at the expected location")
