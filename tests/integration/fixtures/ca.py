# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import ssl

import pytest

from ..artifacts import get_ca


@pytest.fixture(autouse=True, scope="session")
async def ca():
    root_ca = get_ca("ESS CA")
    delegated_ca = get_ca("ESS CA Delegated", root_ca)
    return delegated_ca


@pytest.fixture(scope="session")
async def ssl_context(ca):
    context = ssl.create_default_context()
    context.load_verify_locations(cadata=ca.cert_bundle_as_pem())
    return context
