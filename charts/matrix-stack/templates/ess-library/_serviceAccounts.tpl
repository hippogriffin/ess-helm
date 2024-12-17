{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- define "element-io.ess-library.serviceAccountName" -}}
{{- $root := .root -}}
{{- with required "element-io.ess-library.serviceAccountName missing context" .context -}}
{{ default (printf "%s-%s" $root.Release.Name (required "element-io.ess-library.serviceAccount missing context.key" .key)) .serviceAccount.name }}
{{- end }}
{{- end }}
