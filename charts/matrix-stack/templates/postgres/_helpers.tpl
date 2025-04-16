{{- /*
Copyright 2025 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only
*/ -}}

{{- define "element-io.postgres.labels" -}}
{{- $root := .root -}}

{{- with required "element-io.postgres.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" (dict "labels" .labels "withChartVersion" .withChartVersion)) }}
app.kubernetes.io/component: matrix-stack-db
app.kubernetes.io/name: postgres
app.kubernetes.io/instance: {{ $root.Release.Name }}-postgres
app.kubernetes.io/version: {{ .image.tag | quote }}
{{- end }}
{{- end }}

{{- define "element-io.postgres.enabled" }}
{{- $root := .root -}}
{{- if and $root.Values.postgres.enabled (or
 (and $root.Values.matrixAuthenticationService.enabled
      (not $root.Values.matrixAuthenticationService.postgres))
  (and $root.Values.synapse.enabled
      (not $root.Values.synapse.postgres))
) -}}
true
{{- end }}
{{- end }}

{{- define "element-io.postgres.anyEssPasswordHasValue" }}
{{- $root := .root -}}
{{- with required "element-io.postgres.anyEssPasswordHasValue missing context" .context -}}
{{- range .essPasswords -}}
{{- if .value -}}
true
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}


{{- define "element-io.postgres.configSecrets" -}}
{{- $root := .root -}}
{{- with required "element-io.postgres.configSecrets missing context" .context -}}
{{- $configSecrets := list }}
{{- if or .adminPassword.value (include "element-io.postgres.anyEssPasswordHasValue" (dict "root" $root "context" .)) }}
{{- $configSecrets = append $configSecrets  (printf "%s-postgres" $root.Release.Name) }}
{{- end }}
{{- with .adminPassword.secret -}}
{{ $configSecrets = append $configSecrets (tpl . $root) }}
{{- end -}}
{{- range $key := (.essPasswords | keys | uniq | sortAlpha) -}}
{{- $prop := index $root.Values.postgres.essPasswords $key }}
{{- with $prop.secret -}}
{{ $configSecrets = append $configSecrets (tpl . $root) }}
{{- end }}
{{- end }}
{{ $configSecrets | uniq | toJson }}
{{- end }}
{{- end }}


{{- define "element-io.postgres.memoryLimitsMB" -}}
{{- $root := .root -}}
{{- with required "element-io.postgres.memoryLimitsMB missing context" .context -}}
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


{{- define "element-io.postgres.args" -}}
{{- $root := .root -}}
{{- with required "element-io.postgres.args missing context" .context -}}
{{- $memoryLimitsMB := include "element-io.postgres.memoryLimitsMB" (dict "root" $root "context" .) }}
- "-c"
- "max_connections={{ printf "%d" (div $memoryLimitsMB 16) }}"
- "-c"
- "shared_buffers={{ printf "%s" (printf "%dMB" (div $memoryLimitsMB 4)) }}"
- "-c"
- "effective_cache_size={{ printf "%s" (printf "%dMB" (sub $memoryLimitsMB 256)) }}"
{{- end -}}
{{- end -}}

{{- define "element-io.postgres.env" }}
{{- $root := .root -}}
{{- with required "element-io.postgres.env missing context" .context -}}
{{- $resultEnv := dict -}}
{{- range $envEntry := .extraEnv -}}
{{- $_ := set $resultEnv $envEntry.name $envEntry.value -}}
{{- end -}}
{{- $overrideEnv := dict "POSTGRES_PASSWORD_FILE" (printf "/secrets/%s"
                            (include "element-io.ess-library.init-secret-path" (
                              dict "root" $root "context" (
                                dict "secretPath" "postgres.adminPassword"
                                     "initSecretKey" "POSTGRES_ADMIN_PASSWORD"
                                     "defaultSecretName" (include "element-io.postgres.secret-name" (dict "root" $root "context"  (dict "isHook" false)))
                                     "defaultSecretKey" "ADMIN_PASSWORD"
                                )
                              )
                            )
                          )
                        "PGDATA" "/var/lib/postgres/data/pgdata"
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


{{- define "element-io.postgres.configmap-data" -}}
{{- $root := .root -}}
{{- with required "element-io.postgres.configmap-data" .context -}}
configure-dbs.sh: |
  #!/bin/sh
  set -e;
  export POSTGRES_PASSWORD=`cat /secrets/{{
      include "element-io.ess-library.init-secret-path" (
    dict "root" $root "context" (
      dict "secretPath" "postgres.adminPassword"
            "initSecretKey" "POSTGRES_ADMIN_PASSWORD"
            "defaultSecretName" (include "element-io.postgres.secret-name" (dict "root" $root "context"  (dict "isHook" false)))
            "defaultSecretKey" "ADMIN_PASSWORD"
      )
  ) }}`;
{{- range $key := (.essPasswords | keys | uniq | sortAlpha) -}}
{{- if (index $root.Values $key).enabled -}}
{{- $prop := index $root.Values.postgres.essPasswords $key }}
  export ESS_PASSWORD=`cat /secrets/{{
include "element-io.ess-library.init-secret-path" (
  dict "root" $root "context" (
    dict "secretPath" (printf "postgres.essPasswords.%s" $key)
          "initSecretKey" (printf "POSTGRES_%s_PASSWORD" ($key | upper))
          "defaultSecretName" (include "element-io.postgres.secret-name" (dict "root" $root "context"  (dict "isHook" false)))
          "defaultSecretKey" (printf "ESS_PASSWORD_%s" ($key | upper))
    )
  ) }}`;
  (
    (echo -n $POSTGRES_PASSWORD | psql -W -U postgres -tc "SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = '{{ $key | lower }}_user'" | grep -q 1) && \
    (echo -n $POSTGRES_PASSWORD | psql -W -U postgres -c "ALTER USER {{ $key | lower }}_user PASSWORD '"$ESS_PASSWORD"'")
  ) || \
    (echo -n $POSTGRES_PASSWORD | psql -W -U postgres -c "CREATE ROLE {{ $key | lower }}_user LOGIN PASSWORD '"$ESS_PASSWORD"'");
  (echo -n $POSTGRES_PASSWORD | psql -W -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = '{{ $key | lower }}'" | grep -q 1) || \
  (echo -n $POSTGRES_PASSWORD | createdb --encoding=UTF8 --locale=C --template=template0 --owner={{ $key | lower }}_user {{ $key | lower }} -U postgres)
{{- end }}
{{- end }}
{{- end }}
{{- end }}