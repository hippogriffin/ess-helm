{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- define "element-io.postgresql.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.postgresql.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" .labels) }}
app.kubernetes.io/component: matrix-stack-db
app.kubernetes.io/name: postgresql
app.kubernetes.io/instance: {{ $root.Release.Name }}-postgresql
app.kubernetes.io/version: {{ .image.tag }}
{{- end }}
{{- end }}
