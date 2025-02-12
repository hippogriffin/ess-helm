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

{{- define "element-io.postgresql.enabled" }}
{{- $root := .root -}}
{{- if and $root.Values.postgresql.enabled (or
 (and $root.Values.matrixAuthenticationService.enabled
      (not $root.Values.matrixAuthenticationService.postgresql))
  (and $root.Values.synapse.enabled
      (not $root.Values.synapse.postgresql))
) -}}
true
{{- end }}
{{- end }}

{{- define "element-io.postgresql.configSecrets" -}}
{{- $root := .root -}}
{{- with required "element-io.postgresql.configSecrets missing context" .context -}}
{{ $configSecrets := list (printf "%s-postgresql" $root.Release.Name) }}
{{- if and $root.Values.initSecrets.enabled (include "element-io.init-secrets.generated-secrets" (dict "root" $root)) }}
{{ $configSecrets = append $configSecrets (printf "%s-generated" $root.Release.Name) }}
{{- end }}
{{- with .adminPassword.secret -}}
{{ $configSecrets = append $configSecrets (tpl . $root) }}
{{- end -}}
{{- with .essPassword.secret -}}
{{ $configSecrets = append $configSecrets (tpl . $root) }}
{{- end -}}
{{ $configSecrets | uniq | toJson }}
{{- end }}
{{- end }}


{{- define "element-io.postgresql.memoryLimitsMB" -}}
{{- $root := .root -}}
{{- with required "element-io.postgresql.configSecrets missing context" .context -}}
  {{- $value := .resources.limits.memory }}
  {{- if hasPrefix $value "Mi" }}
    {{- printf "%d" (int64 (trimSuffix "Mi" $value)) | mul 1024 | int64 -}}
  {{- else if hasPrefix $value "Gi" }}
    {{- printf "%d" (int64 (trimSuffix "Gi" $value)) | mul 1048576 | int64 -}}
  {{- else if hasPrefix $value "Ti" }}
    {{- printf "%d" (int64 (trimSuffix "Ti" $value)) | mul 1073741824 | int64 -}}
  {{- else if hasPrefix $value "K" }}
    {{- printf "%d" (int64 (trimSuffix "K" $value)) | mul 1024 | int64 -}}
  {{- else }}
    {{- printf "%d" $value | mul 1024 | int64 -}}
  {{- end -}}
{{- end -}}
{{- end -}}


{{- define "element-io.postgresql.args" -}}
{{- $root := .root -}}
{{- with required "element-io.postgresql.args missing context" .context -}}
{{- $memoryLimitsMB := include "element-io.postgresql.memoryLimitsMB" (dict "root" $root "context" .) }}
- "-c"
- "max_connections={{ printf "%d" (div $memoryLimitsMB 16) }}"
- "-c"
- "shared_buffers={{ printf "%s" (printf "%dMB" (div $memoryLimitsMB 4)) }}"
- "-c"
- "effective_cache_size={{ printf "%s" (printf "%dMB" (sub $memoryLimitsMB 256)) }}"
{{- end -}}
{{- end -}}
