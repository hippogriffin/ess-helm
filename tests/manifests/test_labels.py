# Copyright 2025 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import pytest

from . import values_files_to_test


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_templates_have_expected_labels(templates):
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
        id = f"{template["kind"]}/{template["metadata"]["name"]}"
        labels = template["metadata"]["labels"]

        for expected_label in expected_labels:
            assert expected_label in labels, f"{expected_label} label not present in {id}"
            assert (
                labels[expected_label] is not None
            ), f"{expected_label} label is null in {id} and so won't be present in cluster"

        assert labels["helm.sh/chart"].startswith("matrix-stack-")
        assert labels["app.kubernetes.io/managed-by"] == "Helm"
        assert labels["app.kubernetes.io/part-of"] == "matrix-stack"

        # The instance label is <release name>-<name label>. The release name for the manifest tests is "pytest"
        assert labels["app.kubernetes.io/instance"].startswith("pytest-"), (
            f"The app.kubernetes.io/instance label for {id}"
            "does not start with the expected chart release name of 'pytest'. "
        )
        f"The label value is {labels["app.kubernetes.io/instance"]}"

        assert labels["app.kubernetes.io/instance"].replace("pytest-", "") == labels["app.kubernetes.io/name"], (
            f"The app.kubernetes.io/name label for {id}"
            "is not a concatenation of the expected chart release name of 'pytest' and the instance label. "
            f"The label value is {labels["app.kubernetes.io/instance"]} vs {labels["app.kubernetes.io/name"]}"
        )
