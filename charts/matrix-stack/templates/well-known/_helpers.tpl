{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- define "element-io.well-known-delegation.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.well-known-delegation.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" .labels) }}
app.kubernetes.io/component: matrix-delegation
app.kubernetes.io/name: well-known-delegation
app.kubernetes.io/instance: {{ $root.Release.Name }}-well-known-delegation
app.kubernetes.io/version: {{ .image.tag }}
{{- end }}
{{- end }}

{{- define "element-io.well-known-delegation.client" }}
{{- $root := .root -}}
{{- with required "element-io.well-known-delegation.client missing context" .context -}}
{{- $config := dict -}}
{{- $mHomeserver := dict "base_url" (required "WellKnownDelegation requires serverName set" $root.Values.serverName) }}
{{- $_ := set $config "m.homeserver" $mHomeserver -}}
{{- $additional := .additional.client | fromJson -}}
{{- tpl (toPrettyJson (merge $config $additional)) $root -}}
{{- end }}
{{- end }}

{{- define "element-io.well-known-delegation.server" }}
{{- $root := .root -}}
{{- with required "element-io.well-known-delegation.server missing context" .context -}}
{{- $config := dict -}}
{{- if $root.Values.synapse.enabled -}}
{{- with required "WellKnownDelegation requires synapse.ingress.host set" $root.Values.synapse.ingress.host -}}
{{- $_ := set $config "m.server" . -}}
{{- end -}}
{{- end -}}
{{- $additional := .additional.server | fromJson -}}
{{- tpl (toPrettyJson (merge $config $additional)) $root -}}
{{- end -}}
{{- end }}

{{- define "element-io.well-known-delegation.element" }}
{{- $root := .root -}}
{{- with required "element-io.well-known-delegation.element missing context" .context -}}
{{- $config := dict -}}
{{- $additional := .additional.client | fromJson -}}
{{- tpl (toPrettyJson (merge $config $additional)) $root -}}
{{- end -}}
{{- end }}
