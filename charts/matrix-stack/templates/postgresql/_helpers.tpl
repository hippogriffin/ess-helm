{{- /*
Copyright 2025 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- define "element-io.postgresql.labels" -}}
{{- $root := .root -}}

{{- with required "element-io.postgresql.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" .labels) }}
app.kubernetes.io/component: matrix-stack-db
app.kubernetes.io/name: postgresql
app.kubernetes.io/instance: {{ $root.Release.Name }}-postgresql
app.kubernetes.io/version: {{ .image.tag | quote }}
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
  {{- if  $value | hasSuffix "Mi" }}
    {{- printf "%d" (trimSuffix "Mi" $value) | int64 -}}
  {{- else if  $value | hasSuffix "Gi" }}
    {{- printf "%d" (mul (int64 (trimSuffix "Gi" $value)) 1024) | int64 -}}
  {{- else if  $value | hasSuffix "Ti" }}
    {{- printf "%d" (mul (mul (int64 (trimSuffix "Ti" $value)) 1024) 1024) | int64 -}}
  {{- else -}}
    {{- fail (printf "Could not compute Postgres memory limits from %s" $value) -}}
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

{{- define "element-io.postgresql.env" }}
{{- $root := .root -}}
{{- with required "element-io.postgresql.env missing context" .context -}}
{{- $resultEnv := dict -}}
{{- range $envEntry := .extraEnv -}}
{{- $_ := set $resultEnv $envEntry.name $envEntry.value -}}
{{- end -}}
{{- $overrideEnv := dict "POSTGRES_PASSWORD_FILE" (printf "/secrets/%s"
                            (include "element-io.ess-library.init-secret-path" (
                              dict "root" $root "context" (
                                dict "secretProperty" .adminPassword
                                      "initSecretKey" "POSTGRESQL_ADMIN_PASSWORD"
                                      "defaultSecretName" (printf "%s-postgresql" $root.Release.Name)
                                      "defaultSecretKey" "ADMIN_PASSWORD"
                                )
                              )
                            )
                          )
                        "PGDATA" "/var/lib/postgresql/data/pgdata"
                        "POSTGRES_INITDB_ARGS" "-E UTF8"
                        "LC_COLLATE" "C"
                        "LC_CTYPE" "C"
-}}
{{- $resultEnv := merge $resultEnv $overrideEnv -}}
{{- range $key, $value := $resultEnv }}
- name: {{ $key | quote }}
  value: {{ $value | quote }}
{{- end -}}
{{- end -}}
{{- end -}}
