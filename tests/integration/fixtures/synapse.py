# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import asyncio
import logging

import pyhelm3
import pytest

from ..lib.synapse import create_user
from .data import ESSData

# Until synapse release is ready, this is complaining that the helm status command fails
logging.getLogger("pyhelm3").setLevel(logging.ERROR)


@pytest.fixture(scope="session")
async def synapse_ready(cluster, helm_client: pyhelm3.Client, revision_deployed, generated_data: ESSData):
    await asyncio.to_thread(
        cluster.wait,
        name=f"ingress/{generated_data.release_name}-synapse",
        namespace=generated_data.ess_namespace,
        waitfor="jsonpath='{.status.loadBalancer.ingress[0].ip}'",
    )


@pytest.fixture(scope="session")
async def synapse_users(request, generated_data: ESSData, ssl_context, synapse_ready):
    wait_for_users = []
    for user in request.param:
        wait_for_users.append(
            create_user(
                f"synapse.{generated_data.server_name}",
                user,
                generated_data.secrets_random,
                False,
                generated_data.registration_shared_secret,
                ssl_context,
            )
        )
    return await asyncio.gather(*wait_for_users)
