# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import asyncio
import os

import pytest
import yaml
from lightkube.models.meta_v1 import ObjectMeta
from lightkube.resources.core_v1 import Namespace

from ..fixtures import ESSData
from ..lib.helpers import kubernetes_tls_secret
from ..lib.utils import aiottp_get_json


@pytest.mark.skipif(os.environ.get("TEST_ELEMENTWEB") != "1", reason="ElementWeb not deployed")
@pytest.mark.asyncio_cooperative
async def test_element_web(
    cluster,
    helm_client,
    kube_client,
    ssl_context,
    ca,
    generated_data: ESSData,
):
    await kube_client.create(Namespace(metadata=ObjectMeta(name=generated_data.ess_namespace)))
    resources = [
        kubernetes_tls_secret(
            "element-web-tls", generated_data.ess_namespace, ca, ["element.ess.localhost"], bundled=True
        )
    ]

    with open("charts/element-web/ci/pytest-values.yaml") as stream:
        values = yaml.safe_load(stream)

    chart = await helm_client.get_chart("charts/element-web")
    # Install or upgrade a release
    revision = helm_client.install_or_upgrade_release(
        f"eleweb-{generated_data.secrets_random}",
        chart,
        values,
        namespace=generated_data.ess_namespace,
        atomic=True,
        wait=True,
    )

    await asyncio.gather(revision, *[kube_client.create(r) for r in resources])

    await asyncio.to_thread(
        cluster.wait,
        name=f"ingress/eleweb-{generated_data.secrets_random}-element-web",
        namespace=generated_data.ess_namespace,
        waitfor="jsonpath='{.status.loadBalancer.ingress[0].hostname}'",
    )

    json_content = await aiottp_get_json("https://element.ess.localhost/config.json", ssl_context)
    assert "element_call" in json_content
    assert json_content["element_call"]["url"] == "https://call.ess.localhost"
    assert json_content["element_call"]["use_exclusively"]
