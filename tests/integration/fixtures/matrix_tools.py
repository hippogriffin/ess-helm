# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

from pathlib import Path

import pytest
from python_on_whales import Image, docker


@pytest.fixture(autouse=True, scope="session")
async def build_matrix_tools():
  project_folder = Path(__file__).parent.parent.parent.parent.resolve()
  docker.buildx.bake(files=str(project_folder / "docker-bake.hcl"), targets="matrix-tools",
                     set={"*.tags": "localhost:5000/matrix-tools:pytest"})

@pytest.fixture(autouse=True, scope="session")
async def loaded_matrix_tools(registry, build_matrix_tools: Image):
  docker.push("localhost:5000/matrix-tools:pytest")
  matrix_tools = docker.image.inspect("localhost:5000/matrix-tools:pytest")
  return {
    "repository": "matrix-tools",
    "registry": "localhost:5000",
    "digest": matrix_tools.repo_digests[0].split("@")[-1],
    "tag": "pytest",
  }
