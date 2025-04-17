{{- /*
Copyright 2025 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only
*/ -}}

{{- define "element-io.matrix-authentication-service.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.matrix-authentication-service.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" (dict "labels" .labels "withChartVersion" .withChartVersion)) }}
app.kubernetes.io/component: matrix-authentication
app.kubernetes.io/name: matrix-authentication-service
app.kubernetes.io/instance: {{ $root.Release.Name }}-matrix-authentication-service
app.kubernetes.io/version: {{ .image.tag }}
{{- end }}
{{- end }}

{{- define "element-io.matrix-authentication-service.config" }}
{{- $root := .root -}}
{{- with required "element-io.matrix-authentication-service.config missing context" .context -}}
{{- (tpl ($root.Files.Get "configs/matrix-authentication-service/config.yaml.tpl") (dict "root" $root "context" .)) }}
{{- end }}
{{- end }}

{{- define "element-io.matrix-authentication-service.configSecrets" -}}
{{- $root := .root -}}
{{- with required "element-io.matrix-authentication-service.configSecrets missing context" .context -}}
{{ $configSecrets := list (printf "%s-matrix-authentication-service" $root.Release.Name) }}
{{- if and $root.Values.initSecrets.enabled (include "element-io.init-secrets.generated-secrets" (dict "root" $root)) }}
{{ $configSecrets = append $configSecrets (printf "%s-generated" $root.Release.Name) }}
{{- end }}
{{- $configSecrets = append $configSecrets (include "element-io.ess-library.postgres-secret-name"
                                            (dict "root" $root "context" (dict
                                                                "essPassword" "matrixAuthenticationService"
                                                                "componentPasswordPath" "matrixAuthenticationService.postgres.password"
                                                                "defaultSecretName" (printf "%s-matrix-authentication-service" $root.Release.Name)
                                                                "isHook" false
                                                                )
                                            )
                                        ) -}}
{{- range $privateKey, $value := .privateKeys -}}
{{- if $value.secret }}
{{ $configSecrets = append $configSecrets (tpl $value.secret $root) }}
{{- end -}}
{{- end -}}
{{- with .synapseSharedSecret.secret -}}
{{ $configSecrets = append $configSecrets (tpl . $root) }}
{{- end -}}
{{- with .synapseOIDCClientSecret.secret -}}
{{ $configSecrets = append $configSecrets (tpl . $root) }}
{{- end -}}
{{- with .synapseOIDCClientId.secret -}}
{{ $configSecrets = append $configSecrets (tpl . $root) }}
{{- end -}}
{{- with .encryptionSecret.secret -}}
{{ $configSecrets = append $configSecrets (tpl . $root) }}
{{- end -}}
{{- with .additional -}}
{{- range $key := (. | keys | uniq | sortAlpha) -}}
{{- $prop := index $root.Values.matrixAuthenticationService.additional $key }}
{{- if $prop.configSecret }}
{{ $configSecrets = append $configSecrets (tpl $prop.configSecret $root) }}
{{- end }}
{{- end }}
{{- end }}
{{ $configSecrets | uniq | toJson }}
{{- end }}
{{- end }}

{{- define "element-io.matrix-authentication-service.env" }}
{{- $root := .root -}}
{{- with required "element-io.matrix-authentication-service.env missing context" .context -}}
{{- $resultEnv := dict -}}
{{- range $envEntry := .extraEnv -}}
{{- $_ := set $resultEnv $envEntry.name $envEntry.value -}}
{{- end -}}
{{- $overrideEnv := dict "MAS_CONFIG" "/config.yaml" -}}
{{- $resultEnv := merge $resultEnv $overrideEnv -}}
{{- range $key, $value := $resultEnv }}
- name: {{ $key | quote }}
  value: {{ $value | quote }}
{{- end -}}
{{- end -}}
{{- end -}}

{{- /* The filesystem structure is `/secrets`/<< secret name>>/<< secret key >>.
        The non-defaulted values are handling the case where the credential is provided by an existing Secret
        The default values are handling the case where the credential is provided plain in the Helm chart and we add it to our Secret with a well-known key.

        These could be done as env vars with valueFrom.secretKeyRef, but that triggers CKV_K8S_35.
        Environment variables values found in the config file as ${VARNAME} are parsed through go template engine before being replaced in the target file.
*/}}
{{- define "element-io.matrix-authentication-service.matrixToolsEnv" }}
{{- $root := .root -}}
{{- with required "element-io.matrix-authentication-service.matrixToolsEnv missing context" .context -}}
- name: POSTGRES_PASSWORD
  value: >-
    {{
      printf "{{ readfile \"/secrets/%s\" | urlencode }}" (
          include "element-io.ess-library.postgres-secret-path" (
              dict "root" $root
              "context" (dict
                "essPassword" "matrixAuthenticationService"
                "initSecretKey" "POSTGRES_MATRIXAUTHENTICATIONSERVICE_PASSWORD"
                "componentPasswordPath" "matrixAuthenticationService.postgres.password"
                "defaultSecretName" (printf "%s-matrix-authentication-service" $root.Release.Name)
                "defaultSecretKey" "POSTGRES_PASSWORD"
                "isHook" false
              )
          )
        )
    }}
- name: ENCRYPTION_SECRET
  value: >-
    {{
      printf "{{ readfile \"/secrets/%s\" | quote }}" (
          include "element-io.ess-library.init-secret-path" (
              dict "root" $root
              "context" (dict
                "secretPath" "matrixAuthenticationService.encryptionSecret"
                "initSecretKey" "MAS_ENCRYPTION_SECRET"
                "defaultSecretName" (printf "%s-matrix-authentication-service" $root.Release.Name)
                "defaultSecretKey" "ENCRYPTION_SECRET"
              )
          )
        )
    }}
{{- /*
  This is the secrets shared between Synapse & MAS
*/ -}}
{{- if $root.Values.synapse.enabled }}
- name: SYNAPSE_SHARED_SECRET
  value: >-
    {{
      printf "{{ readfile \"/secrets/%s\" | quote }}" (
          include "element-io.ess-library.init-secret-path" (
              dict "root" $root
              "context" (dict
                "secretPath" "matrixAuthenticationService.synapseSharedSecret"
                "initSecretKey" "MAS_SYNAPSE_SHARED_SECRET"
                "defaultSecretName" (printf "%s-matrix-authentication-service" $root.Release.Name)
                "defaultSecretKey" "SYNAPSE_SHARED_SECRET"
              )
          )
        )
    }}
- name: SYNAPSE_OIDC_CLIENT_SECRET
  value: >-
    {{
      printf "{{ readfile \"/secrets/%s\" | quote }}" (
          include "element-io.ess-library.init-secret-path" (
              dict "root" $root
              "context" (dict
                "secretPath" "matrixAuthenticationService.synapseOIDCClientSecret"
                "initSecretKey" "MAS_SYNAPSE_OIDC_CLIENT_SECRET"
                "defaultSecretName" (printf "%s-matrix-authentication-service" $root.Release.Name)
                "defaultSecretKey" "SYNAPSE_OIDC_CLIENT_SECRET"
              )
          )
        )
    }}
- name: SYNAPSE_OIDC_CLIENT_ID
  value: >-
    {{
      printf "{{ readfile \"/secrets/%s\" | quote }}" (
          include "element-io.ess-library.init-secret-path" (
              dict "root" $root
              "context" (dict
                "secretPath" "matrixAuthenticationService.synapseOIDCClientId"
                "initSecretKey" "MAS_SYNAPSE_OIDC_CLIENT_ID"
                "defaultSecretName" (printf "%s-matrix-authentication-service" $root.Release.Name)
                "defaultSecretKey" "SYNAPSE_OIDC_CLIENT_ID"
              )
          )
        )
    }}
{{- end }}
{{- end }}
{{- end }}


{{- define "element-io.matrix-authentication-service.secret-name" }}
{{- $root := .root }}
{{- with required "element-io.matrix-authentication-service.secret-name requires context" .context }}
{{- $isHook := required "element-io.matrix-authentication-service.secret-name requires context.isHook" .isHook }}
{{- if $isHook }}
{{- $root.Release.Name }}-matrix-authentication-service-hook
{{- else }}
{{- $root.Release.Name }}-matrix-authentication-service
{{- end }}
{{- end }}
{{- end }}


{{- define "element-io.matrix-authentication-service.synapse-secret-data" -}}
{{- $root := .root -}}
{{- with required "element-io.matrix-authentication-service.synapse-secret-data" .context -}}
{{- if $root.Values.synapse.enabled }}
{{- include "element-io.ess-library.check-credential" (dict "root" $root "context" (dict "secretPath" "matrixAuthenticationService.synapseSharedSecret" "initIfAbsent" true)) }}
{{- with .synapseSharedSecret.value }}
SYNAPSE_SHARED_SECRET: {{ . | b64enc }}
{{- end }}
{{- include "element-io.ess-library.check-credential" (dict "root" $root "context" (dict "secretPath" "matrixAuthenticationService.synapseOIDCClientSecret" "initIfAbsent" true)) }}
{{- with .synapseOIDCClientSecret.value }}
SYNAPSE_OIDC_CLIENT_SECRET: {{ . | b64enc }}
{{- end }}
{{- include "element-io.ess-library.check-credential" (dict "root" $root "context" (dict "secretPath" "matrixAuthenticationService.synapseOIDCClientId" "initIfAbsent" true)) }}
{{- with .synapseOIDCClientId.value }}
SYNAPSE_OIDC_CLIENT_ID: {{ . | b64enc }}
{{- end }}
{{- end -}}
{{- end -}}
{{- end -}}


{{- define "element-io.matrix-authentication-service.configmap-data" }}
{{- $root := .root -}}
{{- with required "element-io.matrix-authentication-service.configmap-data" .context -}}
config.yaml: |
  {{- include "element-io.matrix-authentication-service.config" (dict "root" $root "context" .) | nindent 2 }}
{{- end -}}
{{- end -}}


{{- define "element-io.matrix-authentication-service.secret-data" -}}
{{- $root := .root -}}
{{- with required "element-io.matrix-authentication-service.secret-data" .context -}}
{{- with (include "element-io.matrix-authentication-service.synapse-secret-data" (dict "root" $root "context" .)) }}
{{- . | nindent 2 }}
{{- end }}
{{- with .additional }}
{{- range $key := (. | keys | uniq | sortAlpha) }}
{{- $prop := index $root.Values.matrixAuthenticationService.additional $key }}
{{- if $prop.config }}
  user-{{ $key }}: {{ $prop.config | b64enc }}
{{- end }}
{{- end }}
{{- end }}
{{- with .postgres.password }}
{{- include "element-io.ess-library.check-credential" (dict "root" $root "context" (dict "secretPath" "matrixAuthenticationService.postgres.password" "initIfAbsent" false)) }}
{{- with .value }}
  POSTGRES_PASSWORD: {{ . | b64enc }}
{{- end }}
{{- end }}
{{- include "element-io.ess-library.check-credential" (dict "root" $root "context" (dict "secretPath" "matrixAuthenticationService.encryptionSecret" "initIfAbsent" true)) }}
{{- with .encryptionSecret }}
{{- with .value }}
  ENCRYPTION_SECRET: {{ . | b64enc }}
{{- end }}
{{- end }}
{{- with required "privateKeys is required for Matrix Authentication Service" .privateKeys }}
{{- include "element-io.ess-library.check-credential" (dict "root" $root "context" (dict "secretPath" "matrixAuthenticationService.privateKeys.rsa" "initIfAbsent" true)) }}
{{- with .rsa }}
{{- with .value }}
  RSA_PRIVATE_KEY: {{ . | b64enc }}
{{- end }}
{{- end }}
{{- include "element-io.ess-library.check-credential" (dict "root" $root "context" (dict "secretPath" "matrixAuthenticationService.privateKeys.ecdsaPrime256v1" "initIfAbsent" true)) }}
{{- with .ecdsaPrime256v1 }}
{{- with .value }}
  ECDSA_PRIME256V1_PRIVATE_KEY: {{ . | b64enc }}
{{- end }}
{{- end }}
{{- with .ecdsaSecp256k1 }}
{{- include "element-io.ess-library.check-credential" (dict "root" $root "context" (dict "secretPath" "matrixAuthenticationService.privateKeys.ecdsaSecp256k1" "initIfAbsent" false)) }}
{{- with .value }}
  ECDSA_SECP256K1_PRIVATE_KEY: {{ . | b64enc }}
{{- end }}
{{- end }}
{{- with .ecdsaSecp384r1 }}
{{- include "element-io.ess-library.check-credential" (dict "root" $root "context" (dict "secretPath" "matrixAuthenticationService.privateKeys.ecdsaSecp384r1" "initIfAbsent" false)) }}
{{- with .value }}
  ECDSA_SECP384R1_PRIVATE_KEY: {{ . | b64enc}}
{{- end }}
{{- end }}
{{- end -}}
{{- end }}
{{- end -}}
