# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import asyncio

import pytest

from ..lib.synapse import create_user
from .data import ESSData


@pytest.fixture(scope="session")
async def synapse_users(request, generated_data: ESSData, ssl_context, ingress_ready):
    await ingress_ready("synapse")

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
