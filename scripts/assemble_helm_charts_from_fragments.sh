#!/usr/bin/env bash
# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

set -euo pipefail

[ "$#" -ne 0 ] && echo "Usage: assemble_helm_charts_from_fragments.sh" && exit 1

scripts_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
chart_root=$( cd "$scripts_dir/../charts" &> /dev/null && pwd )

function assemble_helm_chart_from_fragments() {
  chart_dir="$1"

  [ ! -d "$chart_dir" ] && echo "$chart_dir must be a directory that exists" && exit 1
  [ ! -f "$chart_dir/Chart.yaml" ] && echo "Chart.yaml not found in $chart_dir" && exit 1
  [ ! -d "$chart_dir/source" ] && echo "$chart_dir/source must be a directory that exists" && exit 1
  [ ! -f "$chart_dir/source/values.schema.json" ] && echo "Chart.yaml not found in $chart_dir" && exit 1

  echo "Building $chart_dir"
  "$scripts_dir/construct_helm_schema.py" "$chart_dir/source/values.schema.json" "$chart_dir/values.schema.json"
  "$scripts_dir/construct_helm_values.py" "$chart_dir/source/values.yaml.j2" "$chart_dir/values.yaml"
  reuse annotate --copyright="Copyright 2024 New Vector Ltd" --license "AGPL-3.0-only OR LicenseRef-Element-Commercial" "$chart_dir/values.yaml"
}

[ ! -d "$chart_root" ] && echo "$chart_root must be a directory that exists" && exit 1

assemble_helm_chart_from_fragments "$chart_root"/ess-library

for subchart in "$chart_root"/*/; do
  [[ "$subchart" =~ /ess-library/?$ ]] && continue
  [[ "$subchart" =~ /matrix-stack/?$ ]] && continue
  assemble_helm_chart_from_fragments "$subchart"
done

assemble_helm_chart_from_fragments "$chart_root"/matrix-stack

"$scripts_dir"/helm_dependency_update_recursive.sh
