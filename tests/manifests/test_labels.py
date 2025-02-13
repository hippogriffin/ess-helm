# Copyright 2025 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

from hashlib import sha1

import pytest

from . import component_details, secrets_values_files_to_test, values_files_to_test


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_templates_have_expected_labels(release_name, templates):
    expected_labels = [
        "helm.sh/chart",
        "app.kubernetes.io/managed-by",
        "app.kubernetes.io/part-of",
        "app.kubernetes.io/name",
        "app.kubernetes.io/component",
        "app.kubernetes.io/instance",
        "app.kubernetes.io/version",
    ]

    for template in templates:
        id = f"{template['kind']}/{template['metadata']['name']}"
        labels = template["metadata"]["labels"]

        for expected_label in expected_labels:
            assert expected_label in labels, f"{expected_label} label not present in {id}"
            assert labels[expected_label] is not None, (
                f"{expected_label} label is null in {id} and so won't be present in cluster"
            )

        assert labels["helm.sh/chart"].startswith("matrix-stack-")
        assert labels["app.kubernetes.io/managed-by"] == "Helm"
        assert labels["app.kubernetes.io/part-of"] == "matrix-stack"

        # The instance label is <release name>-<name label>.
        assert labels["app.kubernetes.io/instance"].startswith(f"{release_name}-"), (
            f"The app.kubernetes.io/instance label for {id}"
            f"does not start with the expected chart release name of '{release_name}'. "
        )
        f"The label value is {labels['app.kubernetes.io/instance']}"

        assert (
            labels["app.kubernetes.io/instance"].replace(f"{release_name}-", "") == labels["app.kubernetes.io/name"]
        ), (
            f"The app.kubernetes.io/name label for {id}"
            "is not a concatenation of the expected chart release name of '{release_name}' and the instance label. "
            f"The label value is {labels['app.kubernetes.io/instance']} vs {labels['app.kubernetes.io/name']}"
        )


@pytest.mark.parametrize("values_file", secrets_values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_templates_have_postgres_hash_label(release_name, component, templates, values):
    for template in templates:
        if template["kind"] in ["Deployment", "StatefulSet", "Job"]:
            id = f"{template['kind']}/{template['metadata']['name']}"
            if not template["metadata"]["name"].endswith(component_details[component].get("hyphened_name", component)):
                continue
            labels = template["spec"]["template"]["metadata"]["labels"]
            if "postgres" in component_details[component].get("shared_components", []):
                assert "k8s.element.io/postgresPasswordHash" in labels, (
                    f"{id} does not have postgres password hash label"
                )
                if values[component].get("postgres", {}).get("password", {}).get("value", None):
                    expected = values[component]["postgres"]["password"]["value"]
                elif values[component].get("postgres", {}).get("password", {}).get("secret", None):
                    secret_name = values[component]["postgres"]["password"]["secret"]
                    expected = f"{secret_name}-{values[component]['postgres']['password']['secretKey']}"
                elif values["postgres"].get("essPasswords", {}).get(component, {}).get("value", None):
                    expected = values["postgres"]["essPasswords"][component]["value"]
                elif values["postgres"].get("essPasswords", {}).get(component, {}).get("secret", None):
                    secret_name = values["postgres"]["essPasswords"][component]["secret"]
                    expected = f"{secret_name}-{values['postgres']['essPasswords'][component]['secretKey']}"
                else:
                    expected = f"{release_name}-generated"
                expected = expected.replace("{{ $.Release.Name }}", release_name)
                assert labels["k8s.element.io/postgresPasswordHash"] == sha1(expected.encode()).hexdigest(), (
                    f"{id} has incorrect postgres password hash, expect {expected} hashed as sha1"
                )
