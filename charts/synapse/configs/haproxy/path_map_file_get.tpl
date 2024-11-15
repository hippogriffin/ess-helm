# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

# A map file that is used in haproxy config to map from matrix paths to the
# named backend. The format is: path_regexp backend_name

{{- if hasKey .Values.workers "client-reader" }}
^/_matrix/client/(api/v1|r0|v3|unstable)/pushrules/ client-reader
{{- end }}
