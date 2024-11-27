# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

{{- define "element-io.ess-library.check-credential" -}}
{{- $global := .global -}}
{{- with required "element-io.ess-library.check-credential missing context" .context -}}
{{- $secretPath := .secretPath -}}
{{- $secretProperty := .secretProperty -}}
{{- if and .secretProperty.value (or .secretProperty.secret .secretProperty.secretKey) -}}
{{- fail printf "The secret %s must either have a value, or both secret & secretKey properties" $secretPath -}}
{{- else if and .secretProperty.secret (not .secretProperty.secretKey) -}}
{{- fail printf "The secret %s has a secret but no secretKey property" $secretPath -}}
{{- else if and .secretProperty.secretKey (not .secretProperty.secret) -}}
{{- fail printf "The secret %s has a secretKey but no secret property" $secretPath -}}
{{- else if and .secretProperty.secret .secretProperty.secretKey -}}
{{- /* OK secret has a secret and a secretKey, do nothing */ -}}
{{- else if .secretProperty.value -}}
{{- /* OK secret has a value, do nothing */ -}}
{{- else -}}
{{- fail printf "The secret %s is missing its secret/secretKey properties" $secretPath -}}
{{- end -}}
{{- end -}}
{{- end }}
