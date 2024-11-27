#!/usr/bin/env bash

# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

set -euo pipefail

[ "$#" -ne 0 ] && echo "Usage: helm_dependency_update_recursive.sh" && exit 1

scripts_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
chart_root=$( cd "$scripts_dir/../charts" &> /dev/null && pwd )

function helm_dependency_update() {
  chart_dir="$1"

  [ ! -d "$chart_dir" ] && echo "$chart_dir must be a directory that exists" && exit 1
  [ ! -f "$chart_dir/Chart.yaml" ] && echo "Chart.yaml not found in $chart_dir" && exit 1

  echo "Updating dependencies for $chart_dir"
  helm dependency update --skip-refresh "$chart_dir"
}

[ ! -d "$chart_root" ] && echo "$chart_root must be a directory that exists" && exit 1

for subchart in "$chart_root"/*/; do
  [[ "$subchart" =~ /matrix-stack/?$ ]] && continue
  helm_dependency_update "$subchart"
done

helm_dependency_update "$chart_root"/matrix-stack
