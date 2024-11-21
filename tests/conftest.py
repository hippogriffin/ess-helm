# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

from _pytest.config.argparsing import Parser

from .fixtures import *  # noqa: F403

__all__ = [  # noqa : 405 fixtures are all declared here
    "generated_data",
    "cluster",
    "ca",
]


def pytest_addoption(parser: Parser):
    parser.addoption(
        "--keep-cluster",
        action="store_true",
        default=False,
        help="keep cluster at the end of the test run",
        dest="keep_cluster",
    )
