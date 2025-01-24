{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- define "element-io.matrix-authentication-service.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.matrix-authentication-service.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" .labels) }}
app.kubernetes.io/component: matrix-client
app.kubernetes.io/name: matrix-authentication-service
app.kubernetes.io/instance: {{ $root.Release.Name }}-matrix-authentication-service
app.kubernetes.io/version: {{ .image.tag }}
{{- end }}
{{- end }}

{{- define "element-io.matrix-authentication-service.config" }}
{{- $root := .root -}}
{{- with required "element-io.matrix-authentication-service.config missing context" .context -}}
{{- $config := (tpl ($root.Files.Get "configs/matrix-authentication-service/config.yaml.tpl") (dict "root" $root "context" .)) | fromYaml }}
{{- toYaml (merge (.additional | fromYaml) $config) }}
{{- end }}
{{- end }}

{{- define "element-io.matrix-authentication-service.configSecrets" -}}
{{- $root := .root -}}
{{- with required "element-io.matrix-authentication-service.configSecrets missing context" .context -}}
{{ $configSecrets := list (printf "%s-matrix-authentication-service" $root.Release.Name) }}
{{- range $privateKey, $value := .privateKeys -}}
{{- if $value.secret }}
{{ $configSecrets = append $configSecrets (tpl $value.secret $root) }}
{{- end -}}
{{- end -}}
{{- with .postgres.password.secret -}}
{{ $configSecrets = append $configSecrets (tpl . $root) }}
{{- end -}}
{{- with .encryptionSecret.secret -}}
{{ $configSecrets = append $configSecrets (tpl . $root) }}
{{- end -}}
{{- with .smtp }}
{{- with .password.secret }}
{{ $configSecrets = append $configSecrets (tpl . $root) }}
{{- end -}}
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
