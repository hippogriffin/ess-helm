{{- /*
Copyright 2025 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only
*/ -}}

{{- $root := .root -}}
{{- with required "configs/element-web/config.json.tpl missing context" .context -}}

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
{{- if (and $root.Values.matrixAuthenticationService.enabled (not $root.Values.matrixAuthenticationService.preMigrationSynapseHandlesAuth)) }}
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
