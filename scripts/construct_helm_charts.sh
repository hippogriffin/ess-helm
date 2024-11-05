#!/usr/bin/env bash
# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

set -euo pipefail

[ "$#" -ne 2 ] && echo "Usage: construct_helm_charts.sh <path to matrix-stack chart> <chart version>" && exit 1

chart_root="$1"
version="$2"
scripts_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

function construct_helm_chart() {
  chart_dir="$1"

  [ ! -d "$chart_dir" ] && echo "$chart_dir must be a directory that exists" && exit 1
  [ ! -f "$chart_dir/Chart.yaml" ] && echo "Chart.yaml not found in $chart_dir" && exit 1
  [ ! -d "$chart_dir/source" ] && echo "$chart_dir/source must be a directory that exists" && exit 1
  [ ! -f "$chart_dir/source/values.schema.json" ] && echo "Chart.yaml not found in $chart_dir" && exit 1

  echo "Building $chart_dir"
  "$scripts_dir/construct_helm_schema.py" "$chart_dir/source/values.schema.json" "$chart_dir/values.schema.json"
  "$scripts_dir/construct_helm_values.py" "$chart_dir/source/values.yaml.j2" "$chart_dir/values.yaml"
  reuse annotate --copyright='New Vector Ltd' --year "$(date +%Y)" --license "AGPL-3.0-only OR LicenseRef-Element-Commercial" "$chart_dir/values.yaml"

  yq -i '.version="'"$version"'"' "$chart_dir/Chart.yaml"
}

[ ! -d "$chart_root" ] && echo "$chart_root must be a directory that exists" && exit 1

for subchart in "$chart_root"/*/; do
  [[ "$subchart" =~ /matrix-stack/?$ ]] && continue
  construct_helm_chart "$subchart"
done

construct_helm_chart "$chart_root"/matrix-stack
yq -i '(.dependencies[] | select(.repository | test("file://"))).version="'"$version"'"' "$chart_root"/matrix-stack/Chart.yaml
helm dependency update --skip-refresh "$chart_root"/matrix-stack
