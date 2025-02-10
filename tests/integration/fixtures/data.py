# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import random
import secrets
import string
from dataclasses import dataclass

import pytest

from ..artifacts import CertKey


def unsafe_token(size):
    alphabet = string.ascii_letters + string.digits + string.punctuation
    return "".join(secrets.choice(alphabet) for i in range(size))


def random_string(choice, size):
    return "".join([random.choice(choice) for _ in range(0, size)])


@dataclass(frozen=True)
class ESSData:
    secrets_random: str
    ca: CertKey

    # Only here because we need to refer to it, in the tests, after the Secret has been constructed
    mas_oidc_client_secret: str

    @property
    def release_name(self):
        return f"pytest-{self.secrets_random}"

    @property
    def ess_namespace(self):
        return f"ess-{self.secrets_random}"

    @property
    def server_name(self):
        return f"ess-test-{self.secrets_random}.localhost"


@pytest.fixture(scope="session")
async def generated_data(ca):
    return ESSData(
        secrets_random=random_string(string.ascii_lowercase + string.digits, 8),
        ca=ca,
        mas_oidc_client_secret=secrets.token_urlsafe(36),
    )
