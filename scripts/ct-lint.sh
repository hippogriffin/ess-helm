#!/bin/bash

# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

set -euo pipefail

temp_output_file=$(mktemp)

error=1

# Call the ct lint command and stream the output to stdout
if ct lint "$@" 2>&1 | tee "$temp_output_file"
then
  # Check if there are any "[INFO] Fail:" lines in the output
  (grep -q '\[INFO\] Fail:'  "$temp_output_file") || \
  (grep -q '\[INFO\] Missing required value:'  "$temp_output_file") ||\
  error=0
fi

if [ "$error" -eq 1 ]; then
  # If found, exit with status code 1
  echo "Errors were raised while running ct lint, exiting with error"
  echo "------------------"
  grep '\[INFO\] Fail:'  "$temp_output_file"
  grep '\[INFO\] Missing required value:'  "$temp_output_file"
fi

rm "$temp_output_file"
exit $error
