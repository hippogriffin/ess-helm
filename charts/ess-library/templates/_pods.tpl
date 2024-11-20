# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

{{- define "element-io.ess-library.pods.pullSecrets" -}}
{{- with .pullSecrets }}
imagePullSecrets:
{{ toYaml . }}
{{- end }}
{{- end }}
