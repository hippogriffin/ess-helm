
{{- /*
Copyright 2025 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}


{{- define "element-io.ess-library.postgres-host-port" -}}
{{- $root := .root -}}
{{- with required "element-io.ess-library.postgres-secret-name" .context -}}
{{- if . -}}
"{{ (tpl .host $root) }}:{{ .port }}"
{{- else -}}
"{{ $root.Release.Name }}-postgres.{{ $root.Release.Namespace }}.svc.cluster.local:5432"
{{- end -}}
{{- end -}}
{{- end -}}

