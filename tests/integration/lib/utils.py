# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import asyncio
import base64
import json
import os
import random
from dataclasses import dataclass
from pathlib import Path
from ssl import SSLContext
from typing import Any
from urllib.parse import urlparse

import aiohttp
import yaml
from aiohttp_retry import JitterRetry, RetryClient
from pytest_kubernetes.providers import AClusterManager

retry_options = JitterRetry(attempts=30, statuses=[429], retry_all_server_errors=False)


@dataclass
class DockerAuth:
    registry: str
    username: str
    password: str


@dataclass
class KubeCtl:
    """A class to execute kubectl against a pod asynchronously"""

    cluster: AClusterManager

    async def exec(self, pod, namespace, cmd):
        return await asyncio.to_thread(
            self.cluster.kubectl, as_dict=False, args=["exec", "-t", pod, "-n", namespace, "--", *cmd]
        )


def random_string(choice, size):
    return "".join([random.choice(choice) for _ in range(0, size)])


def docker_config_json(auths: list[DockerAuth]) -> str:
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


async def aiottp_get_json(url: str, ssl_context: SSLContext) -> Any:
    """Do an async HTTP GET against a url, retry exponentially on 429s. It expects a JSON response.

    Args:
        url (str): The URL to hit
        ssl_context (SSLContext): The SSL Context with test CA loaded

    Returns:
        Any: the Json dict response
    """
    host = urlparse(url).hostname

    async with aiohttp.ClientSession(connector=aiohttp.TCPConnector(ssl=ssl_context)) as session, RetryClient(
        session, retry_options=retry_options, raise_for_status=True
    ) as retry, retry.get(
        url.replace(host, "127.0.0.1"),
        headers={"Host": host},
        server_hostname=host,
    ) as response:
        return await response.json()


async def aiohttp_post_json(url: str, data: dict, headers: dict, ssl_context: SSLContext) -> Any:
    """Do an async HTTP POST against a url, retry exponentially on 429s. IT expects a JSON resposne.

    Due to synapse bootstrap, when helm has finished deploying, HAProxy can still return
    429s because it did not detect the backend servers ready yet.

    Args:
        url (str): The URL to hit
        data (dict): The data to post
        headers (dict): Headers to use
        ssl_context (SSLContext): The SSL Context with test CA loaded

    Returns:
        Any: the Json dict response
    """
    host = urlparse(url).hostname

    async with aiohttp.ClientSession(connector=aiohttp.TCPConnector(ssl=ssl_context)) as session, RetryClient(
        session, retry_options=retry_options, raise_for_status=True
    ) as retry, retry.post(
        url.replace(host, "127.0.0.1"), headers=headers | {"Host": host}, server_hostname=host, json=data
    ) as response:
        return await response.json()


def value_file_has(property_path, expected=None):
    """
    Check if a nested property (given as a dot-separated string) is would be true if the chart was installed/templated.
    """

    def merge(a: dict, b: dict, path=None):
        if not path:
            path = []
        for key in b:
            if key in a:
                if isinstance(a[key], dict) and isinstance(b[key], dict):
                    merge(a[key], b[key], path + [str(key)])
                elif type(a[key]) is not type(b[key]):
                    raise Exception("Conflict at " + ".".join(path + [str(key)]))
                else:
                    a[key] = b[key]
            else:
                a[key] = b[key]
        return a

    with open(Path().resolve() / "charts" / "matrix-stack" / "values.yaml") as base_value_file, open(
        os.environ["TEST_VALUES_FILE"]
    ) as test_value_file:
        data = merge(yaml.safe_load(base_value_file), yaml.safe_load(test_value_file))

    keys = property_path.split(".")
    for key in keys:
        if isinstance(data, dict) and key in data:
            data = data[key]
        else:
            return False
    return data == expected if expected is not None else True
