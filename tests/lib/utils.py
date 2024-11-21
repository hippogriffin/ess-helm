# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import asyncio
import base64
import json
import random
from dataclasses import dataclass
from urllib.parse import urlparse

import aiohttp
from lightkube import AsyncClient, sort_objects
from lightkube.core.resource import Resource


@dataclass
class DockerAuth:
    registry: str
    username: str
    password: str


def random_string(choice, size):
    return "".join([random.choice(choice) for _ in range(0, size)])


def docker_config_json(auths: [DockerAuth]) -> str:
    docker_config_auths = {}
    for auth in auths:
        docker_config_auths[auth.registry] = {
            "username": auth.username,
            "password": auth.password,
            "auth": b64encode(f"{auth.username}:{auth.password}"),
        }

    return json.dumps({"auths": docker_config_auths})


def b64encode(value: str):
    return base64.b64encode(value.encode("utf-8")).decode("utf-8")


async def aiottp_get_json(url, ssl_context):
    host = urlparse(url).hostname

    async with aiohttp.ClientSession(
        connector=aiohttp.TCPConnector(ssl=ssl_context), raise_for_status=True
    ) as session, session.get(
        url.replace(host, "127.0.0.1"),
        headers={"Host": host},
        server_hostname=host,
    ) as response:
        return await response.json()
