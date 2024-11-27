{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- define "element-io.synapse.labels" -}}
{{- $global := .global -}}
{{- with required "element-io.synapse.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (list $global .labels) }}
app.kubernetes.io/component: matrix-server
app.kubernetes.io/name: synapse
app.kubernetes.io/instance: {{ $global.Release.Name }}-synapse
app.kubernetes.io/version: {{ .image.tag | default $global.Chart.AppVersion }}
k8s.element.io/synapse-instance: {{ $global.Release.Name }}-synapse
{{- end }}
{{- end }}

{{- define "element-io.synapse.process.labels" -}}
{{- $global := .global -}}
{{- with required "element-io.synapse.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (list $global .labels) }}
app.kubernetes.io/component: matrix-server
app.kubernetes.io/name: synapse-{{ .ProcessType }}
app.kubernetes.io/instance: {{ $global.Release.Name }}-synapse-{{ .ProcessType }}
app.kubernetes.io/version: {{ .image.tag | default $global.Chart.AppVersion }}
k8s.element.io/synapse-instance: {{ $global.Release.Name }}-synapse
{{- end }}
{{- end }}

{{- define "element-io.synapse.redis.labels" -}}
{{- $global := .global -}}
{{- with required "element-io.redis.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (list $global .labels) }}
app.kubernetes.io/part-of: matrix-stack
app.kubernetes.io/component: matrix-server-pubsub
app.kubernetes.io/name: synapse-redis
app.kubernetes.io/instance: {{ $global.Release.Name }}-synapse-redis
app.kubernetes.io/version: {{ .image.tag }}
{{- end }}
{{- end }}

{{- define "element-io.synapse.haproxy.labels" -}}
{{- $global := .global -}}
{{- with required "element-io.synapse.haproxy.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (list $global .labels) }}
app.kubernetes.io/part-of: matrix-stack
app.kubernetes.io/component: matrix-server-ingress
app.kubernetes.io/name: synapse-haproxy
app.kubernetes.io/instance: {{ $global.Release.Name }}-synapse-haproxy
app.kubernetes.io/version: {{ .image.tag }}
{{- end }}
{{- end }}

{{- define "element-io.synapse.serviceAccountName" -}}
{{- $global := .global -}}
{{- with required "element-io.synapse.serviceAccountName missing context" .context -}}
{{ default (printf "%s-synapse" $global.Release.Name) .serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "element-io.synapse.redis.serviceAccountName" -}}
{{- $global := .global -}}
{{- with required "element-io.synapse.redis.serviceAccountName missing context" .context -}}
{{ default (printf "%s-synapse-redis" $global.Release.Name) .serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "element-io.synapse.haproxy.serviceAccountName" -}}
{{- $global := .global -}}
{{- with required "element-io.synapse.haproxy.serviceAccountName missing context" .context -}}
{{ default (printf "%s-synapse-haproxy" $global.Release.Name) .serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "element-io.synapse.enabledWorkers" -}}
{{- $global := .global -}}
{{- with required "element-io.synapse.enabledWorkers missing context" .context -}}
{{ $enabledWorkers := dict }}
{{- range $workerType, $workerDetails := .workers }}
{{- if $workerDetails.enabled }}
{{ $_ := set $enabledWorkers $workerType $workerDetails }}
{{- end }}
{{- end }}
{{ $enabledWorkers | toJson }}
{{- end }}
{{- end }}

{{- define "element-io.synapse.pvcName" -}}
{{- $global := .global -}}
{{- with required "element-io.synapse.pvcName missing context" .context -}}
{{- if $global.Values.synapse.media.storage.existingClaim -}}
{{ $global.Values.synapse.media.storage.existingClaim }}
{{- else -}}
{{ $global.Release.Name }}-synapse-media
{{- end -}}
{{- end }}
{{- end }}
