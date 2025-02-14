#!/usr/bin/env bash

# Copyright 2025 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

set -euo pipefail

[ "$#" -ne 0 ] && echo "Usage: assemble_ci_values_files_from_fragments.sh" && exit 1

scripts_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
values_file_root=$( cd "$scripts_dir/../charts/matrix-stack/ci" &> /dev/null && pwd )


[ ! -d "$values_file_root" ] && echo "$values_file_root must be a directory that exists" && exit 1

for values_file in "$values_file_root"/*-values.yaml; do
  if ! source_fragments=$(grep -E '#\s+source_fragments:' "$values_file" | sed 's/.*:\s*//'); then
    echo "$values_file doesn't have a source_fragments header comment. Skipping"
    continue
  fi

  yq_command='.'
  for fragment_name in ${source_fragments}; do
    fragment_filename="$values_file_root/fragments/$fragment_name"
    [ ! -f "$fragment_filename" ] && echo "$fragment_filename must be a file that exists" && exit 1
    yq_command="($yq_command *= load(\"$fragment_filename\"))"
  done

  # Remove all the licensing headers that have accumulated
  yq_command+=" head_comment=\"\""
  # Pretty print but with double quotes
  yq_command+=" style=\"double\""
  # Sort keys for diff stability if we reorder the fragments
  yq_command+=" | sort_keys(..)"
  # Remove any fields with null values so we have a way of removing things
  yq_command+=" | del(... | select(. == null))"
  # We could remove enabled: true for all default enabled components by setting enabled: null in their minimal values file,
  # however for wellKnownDelegation and initSecrets there's no other config and so being explicit is better.
  # Instead we remove enabled: true for Element Web, MAS, Synapse
  yq_command+=" | del(.elementWeb.enabled | select(.))"
  yq_command+=" | del(.matrixAuthenticationService.enabled | select(.))"
  yq_command+=" | del(.synapse.enabled | select(.))"

  echo "Generating $values_file from $source_fragments";
  echo "" > "$values_file"
  # REUSE-IgnoreStart
  reuse annotate --copyright="Copyright 2024-$(date +%Y) New Vector Ltd" --license "AGPL-3.0-only OR LicenseRef-Element-Commercial" "$values_file"
  # REUSE-IgnoreEnd

  cat << EOF >> "$values_file"
#
# source_fragments: $source_fragments
# DO NOT EDIT DIRECTLY. Edit the fragment files to add / modify / remove values

EOF
  yq "$yq_command" "$values_file_root/nothing-enabled-values.yaml" >> "$values_file"
done
