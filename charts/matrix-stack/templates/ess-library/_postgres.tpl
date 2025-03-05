
{{- /*
Copyright 2025 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}


{{- define "element-io.ess-library.postgres-host-port" -}}
{{- $root := .root -}}
{{- with required "element-io.ess-library.postgres-host-port requires context" .context -}}
{{- if .postgres -}}
{{ (tpl .postgres.host $root) }}:{{ .postgres.port | default 5432 }}
{{- else if $root.Values.postgres.enabled -}}
{{ $root.Release.Name }}-postgres.{{ $root.Release.Namespace }}.svc.cluster.local:5432
{{- else }}
{{- fail "You need to enable the chart Postgres or configure this component postgres" -}}
{{- end -}}
{{- end -}}
{{- end -}}

