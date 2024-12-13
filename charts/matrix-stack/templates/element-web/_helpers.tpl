{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- define "element-io.element-web.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.element-web.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" .labels) }}
app.kubernetes.io/component: matrix-client
app.kubernetes.io/name: element-web
app.kubernetes.io/instance: {{ $root.Release.Name }}-element-web
app.kubernetes.io/version: {{ .image.tag }}
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
{{- $config := dict -}}
{{- $mHomeserver := dict }}
{{- if $root.Values.serverName }}
{{- $_ := set $mHomeserver "server_name" $root.Values.serverName }}
{{- end }}
{{- if $root.Values.synapse.enabled }}
{{- $_ := set $mHomeserver "base_url" (printf "https://%s" $root.Values.synapse.ingress.host) -}}
{{- end }}
{{- $defaultServerConfig := dict "m.homeserver" $mHomeserver -}}
{{- $_ := set $config "default_server_config" $defaultServerConfig -}}
{{- tpl (toPrettyJson (merge $config .additional)) $root -}}
{{- end }}
{{- end }}
