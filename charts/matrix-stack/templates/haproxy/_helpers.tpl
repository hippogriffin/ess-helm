{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only
*/ -}}

{{- define "element-io.haproxy.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.haproxy.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" (dict "labels" .labels)) }}
app.kubernetes.io/component: matrix-stack-ingress
app.kubernetes.io/name: haproxy
app.kubernetes.io/instance: {{ $root.Release.Name }}-haproxy
app.kubernetes.io/version: {{ .image.tag }}
{{- end }}
{{- end }}
