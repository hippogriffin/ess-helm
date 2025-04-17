{{- /*
Copyright 2025 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only
*/ -}}

{{- $root := .root -}}

# A map file that is used in haproxy config to map from matrix paths to the
# named backend. The format is: path_regexp backend_name
{{ if dig "client-reader" "enabled" false $root.Values.synapse.workers }}
^/_matrix/client/(api/v1|r0|v3|unstable)/pushrules/ client-reader
{{- end }}
