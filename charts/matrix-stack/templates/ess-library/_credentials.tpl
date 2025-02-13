{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- define "element-io.ess-library.check-credential" -}}
{{- $root := .root -}}
{{- with required "element-io.ess-library.check-credential missing context" .context -}}
{{- $secretPath := .secretPath -}}
{{- $secretProperty := .secretProperty -}}
{{- $initIfAbsent := .initIfAbsent | default false -}}
{{- if not $initIfAbsent -}}
  {{- if and .secretProperty.value (or .secretProperty.secret .secretProperty.secretKey) -}}
  {{- fail (printf "The secret %s must either have a value, or both secret & secretKey properties" $secretPath) -}}
  {{- else if and .secretProperty.secret (not .secretProperty.secretKey) -}}
  {{- fail (printf "The secret %s has a secret but no secretKey property" $secretPath) -}}
  {{- else if and .secretProperty.secretKey (not .secretProperty.secret) -}}
  {{- fail (printf "The secret %s has a secretKey but no secret property" $secretPath) -}}
  {{- else if and .secretProperty.secret .secretProperty.secretKey -}}
  {{- /* OK secret has a secret and a secretKey, do nothing */ -}}
  {{- else if .secretProperty.value -}}
  {{- /* OK secret has a value, do nothing */ -}}
  {{- else -}}
  {{- fail (printf "The secret %s is missing its secret/secretKey properties" $secretPath) -}}
  {{- end -}}
{{- end -}}
{{- end -}}
{{- end }}

{{- define "element-io.ess-library.init-secret-path" -}}
{{- $root := .root -}}
{{- with required "element-io.ess-library.init-secret-path" .context -}}
{{- $secretProperty := required "element-io.ess-library.init-secret-path context missing secretProperty" .secretProperty -}}
{{- $initSecretKey := required "element-io.ess-library.init-secret-path context missing initSecretKey" .initSecretKey -}}
{{- $defaultSecretName := required "element-io.ess-library.init-secret-path context missing defaultSecretName" .defaultSecretName -}}
{{- $defaultSecretKey := required "element-io.ess-library.init-secret-path context missing defaultSecretKey" .defaultSecretKey -}}
{{- if not $secretProperty -}}
  {{- if $root.Values.initSecrets.enabled -}}
  {{- printf "%s/%s" (printf "%s-generated" $root.Release.Name) $initSecretKey -}}
  {{- end -}}
{{- else -}}
  {{- include "element-io.ess-library.provided-secret-path" (dict "root" $root "context" (dict "secretProperty" $secretProperty "defaultSecretName" $defaultSecretName "defaultSecretKey" $defaultSecretKey)) -}}
{{- end -}}
{{- end -}}
{{- end -}}


{{- define "element-io.ess-library.provided-secret-path" -}}
{{- $root := .root -}}
{{- with required "element-io.ess-library.provided-secret-path missing context" .context -}}
{{- $secretProperty := required "element-io.ess-library.provided-secret-path context missing secretProperty" .secretProperty -}}
{{- $defaultSecretName := required "element-io.ess-library.provided-secret-path context missing defaultSecretName" .defaultSecretName -}}
{{- $defaultSecretKey := required "element-io.ess-library.provided-secret-path context missing defaultSecretKey" .defaultSecretKey -}}
{{- if $secretProperty.value -}}
{{- printf "%s/%s" $defaultSecretName $defaultSecretKey -}}
{{- else -}}
{{- printf "%s/%s" (tpl $secretProperty.secret $root) (tpl $secretProperty.secretKey $root) -}}
{{- end -}}
{{- end -}}
{{- end -}}


{{- define "element-io.ess-library.postgres-secret-path" -}}
{{- $root := .root -}}
{{- with required "element-io.ess-library.postgres-secret-path" .context -}}
{{- $secretProperty := .secretProperty -}}
{{- $defaultSecretName := required "element-io.ess-library.postgres-secret-path context missing defaultSecretName" .defaultSecretName -}}
{{- $defaultSecretKey := required "element-io.ess-library.postgres-secret-path context missing defaultSecretKey" .defaultSecretKey -}}
{{- if not $secretProperty -}}
  {{- if not $root.Values.postgres.essPassword }}
    {{- if $root.Values.initSecrets.enabled -}}
    {{- printf "%s/%s" (printf "%s-generated" $root.Release.Name) "POSTGRESQL_ESS_PASSWORD" -}}
    {{- end -}}
  {{- else -}}
    {{- include "element-io.ess-library.provided-secret-path" (dict "root" $root "context" (dict "secretProperty" $root.Values.postgres.essPassword "defaultSecretName" (printf "%s-postgres" $root.Release.Name) "defaultSecretKey" "ESS_PASSWORD")) -}}
  {{- end -}}
{{- else -}}
  {{- include "element-io.ess-library.provided-secret-path" (dict "root" $root "context" (dict "secretProperty" $secretProperty "defaultSecretName" $defaultSecretName "defaultSecretKey" $defaultSecretKey)) -}}
{{- end -}}
{{- end -}}
{{- end -}}


{{- define "element-io.ess-library.postgres-secret-name" -}}
{{- $root := .root -}}
{{- with required "element-io.ess-library.postgres-secret-name" .context -}}
{{- $postgresProperty := required "element-io.ess-library.postgres-secret-name context missing postgresProperty" .postgresProperty -}}
{{- $defaultSecretName := required "element-io.ess-library.postgres-secret-name context missing defaultSecretName" .defaultSecretName -}}
{{- if $postgresProperty -}}
    {{- if $postgresProperty.password.value -}}
    {{- $defaultSecretName -}}
    {{- else -}}
    {{- tpl $postgresProperty.password.secret $root -}}
    {{- end -}}
{{- else if $root.Values.postgres.essPassword }}
    {{- if $root.Values.postgres.essPassword.value -}}
    {{- printf "%s-postgres" $root.Release.Name -}}
    {{- else -}}
    {{- tpl $root.Values.postgres.essPassword.secret $root -}}
    {{- end -}}
{{- else -}}
  {{- if $root.Values.initSecrets.enabled -}}
  {{- printf "%s-generated" $root.Release.Name -}}
  {{- else -}}
  {{- fail "No postgres password set and initSecrets not set" -}}
  {{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}


{{- define "element-io.ess-library.postgres-annotation" -}}
{{- $root := .root -}}
{{- with required "element-io.ess-library.postgres-secret-name" .context -}}
{{- $postgresProperty := required "elment-io.ess-library.postgres-secret-name context missing postgresProperty" .postgresProperty -}}
k8s.element.io/postgresPasswordHash: {{ if $postgresProperty -}}
    {{- if $postgresProperty.password.value -}}
    {{- $postgresProperty.password.value | sha1sum -}}
    {{- else -}}
    {{- (printf "%s-%s" (tpl $postgresProperty.password.secret $root) $postgresProperty.password.secretKey) | sha1sum -}}
    {{- end -}}
{{- else if $root.Values.postgres.essPassword }}
    {{- if $root.Values.postgres.essPassword.value -}}
    {{- $root.Values.postgres.essPassword.value | sha1sum -}}
    {{- else -}}
    {{- (printf "%s-%s" (tpl $root.Values.postgres.essPassword.secret $root) $root.Values.postgres.essPassword.secretKey) | sha1sum -}}
    {{- end -}}
{{- else -}}
  {{- if $root.Values.initSecrets.enabled -}}
  {{- (printf "%s-generated" $root.Release.Name) | sha1sum  -}}
  {{- else -}}
  {{- fail "No postgres password set and initSecrets not set" -}}
  {{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
