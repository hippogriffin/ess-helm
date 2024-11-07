#!/usr/bin/env bash
# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

REPO="ghcr.io/element-hq/ess-helm/ci-runner"

docker build -f Dockerfile.ci-runner --tag "$REPO" --push .
