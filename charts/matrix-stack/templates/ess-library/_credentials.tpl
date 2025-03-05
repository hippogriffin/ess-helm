{{- /*
Copyright 2024-2025 New Vector Ltd

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
{{- $secretPath := .secretPath -}}
{{- $secretProperty := required "element-io.ess-library.init-secret-path context missing secretProperty" .secretProperty -}}
{{- $initSecretKey := required "element-io.ess-library.init-secret-path context missing initSecretKey" .initSecretKey -}}
{{- $defaultSecretName := required "element-io.ess-library.init-secret-path context missing defaultSecretName" .defaultSecretName -}}
{{- $defaultSecretKey := required "element-io.ess-library.init-secret-path context missing defaultSecretKey" .defaultSecretKey -}}
{{- if not $secretProperty -}}
  {{- if $root.Values.initSecrets.enabled -}}
  {{- printf "%s/%s" (printf "%s-generated" $root.Release.Name) $initSecretKey -}}
  {{- else -}}
  {{- fail (printf "initSecrets is disabled, but secret %s is empty." $secretPath) -}}
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
{{- $essPassword := required "element-io.ess-library.postgres-secret-path context missing essPassword" .essPassword -}}
{{- $initSecretKey := required "element-io.ess-library.postgres-secret-path context missing initSecretKey" .initSecretKey -}}
{{- $defaultSecretName := required "element-io.ess-library.postgres-secret-path context missing defaultSecretName" .defaultSecretName -}}
{{- $defaultSecretKey := required "element-io.ess-library.postgres-secret-path context missing defaultSecretKey" .defaultSecretKey -}}
{{- if not $secretProperty -}}
  {{- if (not (index $root.Values.postgres.essPasswords $essPassword)) }}
    {{- if $root.Values.initSecrets.enabled -}}
    {{- printf "%s/%s" (printf "%s-generated" $root.Release.Name) $initSecretKey -}}
    {{- end -}}
  {{- else -}}
    {{- include "element-io.ess-library.provided-secret-path" (dict
                  "root" $root
                  "context" (dict
                    "secretProperty" (index $root.Values.postgres.essPasswords $essPassword)
                    "defaultSecretName" (printf "%s-postgres" $root.Release.Name)
                    "defaultSecretKey" (printf "ESS_PASSWORD_%s" ($essPassword | upper))
                  )
                )
    -}}
  {{- end -}}
{{- else -}}
  {{- include "element-io.ess-library.provided-secret-path" (dict
                "root" $root
                "context" (dict
                  "secretProperty" $secretProperty
                  "defaultSecretName" $defaultSecretName
                  "defaultSecretKey" $defaultSecretKey
                )
              )
    -}}
{{- end -}}
{{- end -}}
{{- end -}}


{{- define "element-io.ess-library.postgres-secret-name" -}}
{{- $root := .root -}}
{{- with required "element-io.ess-library.postgres-secret-name" .context -}}
{{- $essPassword := required "element-io.ess-library.postgres-secret-name context missing essPassword" .essPassword -}}
{{- $postgresProperty := required "element-io.ess-library.postgres-secret-name context missing postgresProperty" .postgresProperty -}}
{{- $defaultSecretName := required "element-io.ess-library.postgres-secret-name context missing defaultSecretName" .defaultSecretName -}}
{{- $isHook := required "element-io.ess-library.postgres-secret-name context missing isHook" .isHook -}}
{{- if $postgresProperty -}}
    {{- if $postgresProperty.password.value -}}
    {{- $defaultSecretName -}}
    {{- else -}}
    {{- tpl $postgresProperty.password.secret $root -}}
    {{- end -}}
{{- else if (index $root.Values.postgres.essPasswords $essPassword) }}
    {{- if (index $root.Values.postgres.essPasswords $essPassword).value -}}
    {{- include "element-io.postgres.secret-name" (dict "root" $root "context"  (dict "isHook" .isHook)) }}
    {{- else -}}
    {{- tpl (index $root.Values.postgres.essPasswords $essPassword).secret $root -}}
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

