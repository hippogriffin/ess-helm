{{- /*
Copyright 2025 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- define "element-io.matrix-authentication-service.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.matrix-authentication-service.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" .labels) }}
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
                                                                "postgresProperty" .postgres
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
                "secretProperty" .postgres.password
                "defaultSecretName" (printf "%s-matrix-authentication-service" $root.Release.Name)
                "defaultSecretKey" "POSTGRES_PASSWORD"
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
                "secretProperty" .encryptionSecret
                "secretPath" ".matrixAuthenticationService.encryptionSecret"
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
                "secretProperty" .synapseSharedSecret
                "secretPath" ".matrixAuthenticationService.synapseSharedSecret"
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
                "secretProperty" .synapseOIDCClientSecret
                "secretPath" ".matrixAuthenticationService.synapseOIDCClientSecret"
                "initSecretKey" "MAS_SYNAPSE_OIDC_CLIENT_SECRET"
                "defaultSecretName" (printf "%s-matrix-authentication-service" $root.Release.Name)
                "defaultSecretKey" "SYNAPSE_OIDC_CLIENT_SECRET"
              )
          )
        )
    }}
{{- end }}
{{- end }}
{{- end }}
