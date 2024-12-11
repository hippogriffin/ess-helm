# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import secrets
import string
from dataclasses import dataclass

import pytest
import signedjson.key

from ..artifacts import CertKey
from ..lib.utils import random_string


def generate_signing_key():
    signing_key = signedjson.key.generate_signing_key(0)
    value = f"{signing_key.alg} {signing_key.version} " f"{signedjson.key.encode_signing_key_base64(signing_key)}"
    return value


def unsafe_token(size):
    alphabet = string.ascii_letters + string.digits + string.punctuation
    return "".join(secrets.choice(alphabet) for i in range(size))


@dataclass(frozen=True)
class ESSData:
    secrets_random: str
    ca: CertKey

    # Only here because we need to refer to it, in the tests, after the Secret has been constructed
    synapse_registration_shared_secret: str

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
        synapse_registration_shared_secret=secrets.token_urlsafe(36),
    )
