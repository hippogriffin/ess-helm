# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import hashlib
import hmac
from ssl import SSLContext

from .utils import aiohttp_post_json, aiottp_get_json


async def get_nonce(synapse_fqdn: str, ssl_context) -> str:
    """
    Call Synapse for a nonce.
    """
    response = await aiottp_get_json(f"https://{synapse_fqdn}/_synapse/admin/v1/register", ssl_context)
    return response.get("nonce", "")


def generate_mac(username: str, password: str, admin: bool, registration_shared_secret: str, nonce: str) -> str:
    """
    Generate a MAC for using in registering the user.
    """
    # From: https://github.com/element-hq/synapse/blob/master/docs/admin_api/register_api.md
    mac = hmac.new(
        key=registration_shared_secret.encode("utf8"),
        digestmod=hashlib.sha1,
    )

    mac.update(nonce.encode("utf8"))
    mac.update(b"\x00")
    mac.update(username.encode("utf8"))
    mac.update(b"\x00")
    mac.update(password.encode("utf8"))
    mac.update(b"\x00")
    mac.update(b"admin" if admin else b"notadmin")
    return mac.hexdigest()


async def create_user(
    synapse_fqdn: str,
    username: str,
    password: str,
    admin: bool,
    registration_shared_secret: str,
    ssl_context: SSLContext,
) -> str:
    """
    Create the user and return access_token
    """
    nonce = await get_nonce(synapse_fqdn, ssl_context)
    mac = generate_mac(username, password, admin, registration_shared_secret, nonce)
    data = {
        "nonce": nonce,
        "username": username,
        "password": password,
        "admin": admin,
        "mac": mac,
    }
    response = await aiohttp_post_json(f"https://{synapse_fqdn}/_synapse/admin/v1/register", data, {}, ssl_context)
    return response["access_token"]
