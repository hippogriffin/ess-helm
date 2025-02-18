// Copyright 2025 New Vector Ltd
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

// Targets filled by GitHub Actions: one for the regular tag
target "docker-metadata-action" {}

target "matrix-tools" {
  inherits = ["docker-metadata-action"]
  dockerfile = "Dockerfile"
  context = "./matrix-tools"
}
