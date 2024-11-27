{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- define "element-io.element-web.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.element-web.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (list $root .labels) }}
app.kubernetes.io/component: matrix-client
app.kubernetes.io/name: element-web
app.kubernetes.io/instance: {{ $root.Release.Name }}-element-web
app.kubernetes.io/version: {{ .image.tag | default $root.Chart.AppVersion }}
{{- end }}
{{- end }}

{{- define "element-io.element-web.serviceAccountName" -}}
{{- $root := .root -}}
{{- with required "element-io.element-web.serviceAccountName missing context" .context -}}
{{ default (printf "%s-element-web" $root.Release.Name ) .serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "element-io.element-web.config" }}
{{- $root := .root -}}
{{- with required "element-io.element-web.config missing context" .context -}}
{{- $config := dict }}
{{- $serverName := required "Element Web requires .ess.serverName set" $root.Values.ess.serverName }}
{{- with required "elementWeb.defaultMatrixServer is required" .defaultMatrixServer }}
{{- $baseUrl := required "elementWeb.defaultMatrixServer.baseUrl is required" .baseUrl -}}
{{- $mHomeserver := dict "base_url" $baseUrl "serverName" $serverName }}
{{- $defaultServerConfig := dict "m.homeserver" $mHomeserver -}}
{{- $_ := set $config "default_server_config" $defaultServerConfig }}
{{- end }}
{{- toPrettyJson (merge $config .additional) }}
{{- end }}
{{- end }}
