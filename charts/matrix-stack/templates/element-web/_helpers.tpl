{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only
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
{{- $settingDefaults := dict -}}
{{- if $root.Values.serverName }}
{{- $_ := set $mHomeserver "server_name" $root.Values.serverName }}
{{- end }}
{{- if $root.Values.synapse.enabled }}
{{- $_ := set $mHomeserver "base_url" (printf "https://%s" $root.Values.synapse.ingress.host) -}}
{{- end }}
{{- if $root.Values.matrixRTC.enabled }}
{{- $_ := set $settingDefaults "feature_group_calls" true -}}
{{- $_ := set $config "features" (dict "feature_video_rooms" true "feature_group_calls" true "feature_new_room_decoration_ui" true "feature_element_call_video_rooms" true) -}}
{{- $_ := set $config "element_call" (dict "use_exclusively" true) -}}
{{- end }}
{{- if $root.Values.matrixAuthenticationService.enabled }}
{{- $embeddedPages := dict "login_for_welcome" true -}}
{{- $ssoRedirectOptions := dict "immediate" false -}}
{{- $_ := set $settingDefaults "UIFeature.registration" false -}}
{{- $_ := set $settingDefaults "UIFeature.passwordReset" false  -}}
{{- $_ := set $settingDefaults "UIFeature.deactivate" false -}}
{{- $_ := set $config "embedded_pages" $embeddedPages -}}
{{- $_ := set $config "sso_redirect_options" $ssoRedirectOptions -}}
{{- end }}
{{- $_ := set $config "setting_defaults" $settingDefaults -}}
{{- $defaultServerConfig := dict "m.homeserver" $mHomeserver -}}
{{- $_ := set $config "default_server_config" $defaultServerConfig -}}
{{- $_ := set $config "bug_report_endpoint_url" "https://element.io/bugreports/submit" -}}
{{- $_ := set $config "map_style_url" "https://api.maptiler.com/maps/streets/style.json?key=fU3vlMsMn4Jb6dnEIFsx" -}}
{{- with .additional }}
{{- range $key := (. | keys | uniq | sortAlpha) }}
{{- $prop := index $root.Values.elementWeb.additional $key }}
{{- $_ := (merge $config ((tpl $prop $root) | fromJson)) -}}
{{- end }}
{{- end }}
{{- toPrettyJson $config -}}
{{- end }}
{{- end }}

{{- define "element-io.element-web.env" -}}
{{- $root := .root -}}
{{- with required "element-io.element-web.env missing context" .context -}}
{{- $resultEnv := dict -}}
{{- /*
https://github.com/nginxinc/docker-nginx/blob/1.26.1/entrypoint/20-envsubst-on-templates.sh#L31-L45
If pods run with a GID of 0 this makes $output_dir to appear writable to sh, however
due to running with a read-only FS the actual writing later fails. We short circuit this by using an
invalid template directory and so templating as a whole is skipped by the script
*/ -}}
{{- $_ := set $resultEnv "NGINX_ENVSUBST_TEMPLATE_DIR" "/non-existant-so-that-this-works-with-read-only-root-filesystem" -}}
{{- range $envEntry := .extraEnv -}}
{{- $_ := set $resultEnv $envEntry.name $envEntry.value -}}
{{- end -}}
{{- range $key, $value := $resultEnv }}
- name: {{ $key | quote }}
  value: {{ $value | quote }}
{{- end -}}
{{- end -}}
{{- end -}}
