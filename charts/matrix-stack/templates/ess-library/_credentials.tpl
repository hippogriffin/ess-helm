{{- /*
Copyright 2024-2025 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- /* Returns the value (or nill) encoded as JSON at the given dot seperated path in the values file */ -}}
{{- define "element-io.ess-library.value-from-values-path" -}}
{{- $root := .root -}}
{{- with required "element-io.ess-library.value-from-values-path missing context" .context -}}
{{- $path := . -}}
{{- $navigatedToPart := merge (dict) (mustDeepCopy $root.Values) -}}
{{- range (mustRegexSplit "\\." $path -1) -}}
{{- if $navigatedToPart -}}
{{- $navigatedToPart = dig . nil $navigatedToPart -}}
{{- end -}}
{{- end -}}
{{ $navigatedToPart | toJson }}
{{- end -}}
{{- end -}}

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
{{- $secretPath := required "element-io.ess-library.init-secret-path context missing secretPath" .secretPath -}}
{{- $initSecretKey := required "element-io.ess-library.init-secret-path context missing initSecretKey" .initSecretKey -}}
{{- $defaultSecretName := required "element-io.ess-library.init-secret-path context missing defaultSecretName" .defaultSecretName -}}
{{- $defaultSecretKey := required "element-io.ess-library.init-secret-path context missing defaultSecretKey" .defaultSecretKey -}}
{{- $secretProperty := include "element-io.ess-library.value-from-values-path" (dict "root" $root "context" $secretPath) | fromJson -}}
{{- if not $secretProperty -}}
  {{- if $root.Values.initSecrets.enabled -}}
  {{- printf "%s/%s" (printf "%s-generated" $root.Release.Name) $initSecretKey -}}
  {{- else -}}
  {{- fail (printf "initSecrets is disabled, but the Secret configuration at %s is not present" $secretPath) -}}
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
{{- $componentPasswordPath := required "element-io.ess-library.postgres-secret-path context missing componentPasswordPath" .componentPasswordPath -}}
{{- $essPassword := required "element-io.ess-library.postgres-secret-path context missing essPassword" .essPassword -}}
{{- $initSecretKey := required "element-io.ess-library.postgres-secret-path context missing initSecretKey" .initSecretKey -}}
{{- $defaultSecretName := required "element-io.ess-library.postgres-secret-path context missing defaultSecretName" .defaultSecretName -}}
{{- $defaultSecretKey := required "element-io.ess-library.postgres-secret-path context missing defaultSecretKey" .defaultSecretKey -}}
{{- $secretProperty := include "element-io.ess-library.value-from-values-path" (dict "root" $root "context" $componentPasswordPath) | fromJson -}}
{{- if not $secretProperty -}}
  {{- if (not (index $root.Values.postgres.essPasswords $essPassword)) }}
    {{- if $root.Values.initSecrets.enabled -}}
    {{- printf "%s/%s" (printf "%s-generated" $root.Release.Name) $initSecretKey -}}
    {{- else -}}
    {{- fail (printf "initSecrets is disabled, but the Secret configuration at %s is not present" $componentPasswordPath) -}}
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
{{- $componentPasswordPath := required "element-io.ess-library.postgres-secret-name context missing componentPasswordPath" .componentPasswordPath -}}
{{- $defaultSecretName := required "element-io.ess-library.postgres-secret-name context missing defaultSecretName" .defaultSecretName -}}
{{- $isHook := required "element-io.ess-library.postgres-secret-name context missing isHook" .isHook -}}
{{- $secretProperty := include "element-io.ess-library.value-from-values-path" (dict "root" $root "context" $componentPasswordPath) | fromJson -}}
{{- if $secretProperty -}}
    {{- if $secretProperty.value -}}
    {{- $defaultSecretName -}}
    {{- else -}}
    {{- tpl $secretProperty.secret $root -}}
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
  {{- fail (printf "initSecrets is disabled, but the Secret configuration at %s is not present" $componentPasswordPath) -}}
  {{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
