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
{{- if $root.Values.matrixAuthenticationService.enabled }}
{{- $embeddedPages := dict "login_for_welcome" true -}}
{{- $ssoRedirectOptions := dict "immediate" true -}}
{{- $settingDefaults := dict "UIFeature.passwordReset" false "UIFeature.registration" false "UIFeature.deactivate" false -}}
{{- $_ := set $config "embedded_pages" $embeddedPages -}}
{{- $_ := set $config "sso_redirect_options" $ssoRedirectOptions -}}
{{- $_ := set $config "setting_defaults" $settingDefaults -}}
{{- end }}
{{- $defaultServerConfig := dict "m.homeserver" $mHomeserver -}}
{{- $_ := set $config "default_server_config" $defaultServerConfig -}}
{{- $_ := set $config "bug_report_endpoint_url" "https://element.io/bugreports/submit" -}}
{{- $_ := set $config "map_style_url" "https://api.maptiler.com/maps/streets/style.json?key=fU3vlMsMn4Jb6dnEIFsx" -}}
{{- tpl (toPrettyJson (merge $config .additional)) $root -}}
{{- end }}
{{- end }}
