#!/bin/bash

# Copyright 2024-2025 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only

set -euo pipefail

checkov --version
export HELM_NAMESPACE=ess
workdir="$PWD"
matrix_stack_path="$workdir/charts/matrix-stack"
for checkov_values in charts/matrix-stack/ci/*checkov*values.yaml; do
  echo "Testing matrix-stack with $checkov_values";
  tmpdir=$(mktemp -d)
  cd "$tmpdir"
  helm template checkov -f "$workdir/$checkov_values" "$matrix_stack_path" | sed 's/{{//' | yq -s '.kind + "-" + .metadata.name'
  # CKV_K8S_11=We deliberately don't set CPU limits. Pod is BestEffort not Guaranteed
  # CKV_K8S_43=No digests
  # CKV2_K8S_6=No network policy yet
  # CKV_SECRET_6=Checksum contains fake data with low entropy
  checkov -d .  --skip-check CKV_K8S_11 --skip-check CKV_K8S_43 --skip-check CKV2_K8S_6 --skip-check CKV_SECRET_6  --quiet
  cd -
done
