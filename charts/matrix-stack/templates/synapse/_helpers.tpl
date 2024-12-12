{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- define "element-io.synapse.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.synapse.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" .labels) }}
app.kubernetes.io/component: matrix-server
app.kubernetes.io/name: synapse
app.kubernetes.io/instance: {{ $root.Release.Name }}-synapse
app.kubernetes.io/version: {{ .image.tag | default $root.Chart.AppVersion }}
k8s.element.io/synapse-instance: {{ $root.Release.Name }}-synapse
{{- end }}
{{- end }}

{{- define "element-io.synapse.process.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.synapse.process.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" .labels) }}
app.kubernetes.io/component: matrix-server
app.kubernetes.io/name: synapse-{{ .ProcessType }}
app.kubernetes.io/instance: {{ $root.Release.Name }}-synapse-{{ .ProcessType }}
app.kubernetes.io/version: {{ .image.tag | default $root.Chart.AppVersion }}
k8s.element.io/synapse-instance: {{ $root.Release.Name }}-synapse
{{- end }}
{{- end }}

{{- define "element-io.synapse.redis.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.redis.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" .labels) }}
app.kubernetes.io/component: matrix-server-pubsub
app.kubernetes.io/name: synapse-redis
app.kubernetes.io/instance: {{ $root.Release.Name }}-synapse-redis
app.kubernetes.io/version: {{ .image.tag }}
{{- end }}
{{- end }}

{{- define "element-io.synapse.haproxy.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.synapse.haproxy.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" .labels) }}
app.kubernetes.io/component: matrix-server-ingress
app.kubernetes.io/name: synapse-haproxy
app.kubernetes.io/instance: {{ $root.Release.Name }}-synapse-haproxy
app.kubernetes.io/version: {{ .image.tag }}
{{- end }}
{{- end }}

{{- define "element-io.synapse.serviceAccountName" -}}
{{- $root := .root -}}
{{- with required "element-io.synapse.serviceAccountName missing context" .context -}}
{{ default (printf "%s-synapse" $root.Release.Name) .serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "element-io.synapse.redis.serviceAccountName" -}}
{{- $root := .root -}}
{{- with required "element-io.synapse.redis.serviceAccountName missing context" .context -}}
{{ default (printf "%s-synapse-redis" $root.Release.Name) .serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "element-io.synapse.haproxy.serviceAccountName" -}}
{{- $root := .root -}}
{{- with required "element-io.synapse.haproxy.serviceAccountName missing context" .context -}}
{{ default (printf "%s-synapse-haproxy" $root.Release.Name) .serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "element-io.synapse.enabledWorkers" -}}
{{- $root := .root -}}
{{ $enabledWorkers := dict }}
{{- range $workerType, $workerDetails := $root.Values.synapse.workers }}
{{- if $workerDetails.enabled }}
{{ $_ := set $enabledWorkers $workerType $workerDetails }}
{{- end }}
{{- end }}
{{ $enabledWorkers | toJson }}
{{- end }}

{{- define "element-io.synapse.pvcName" -}}
{{- $root := .root -}}
{{- with required "element-io.synapse.pvcName missing context" .context -}}
{{- if $root.Values.synapse.media.storage.existingClaim -}}
{{ tpl $root.Values.synapse.media.storage.existingClaim $root }}
{{- else -}}
{{ $root.Release.Name }}-synapse-media
{{- end -}}
{{- end }}
{{- end }}

{{- define "element-io.synapse.env" }}
{{- $root := .root -}}
{{- with required "element-io.synapse.labels missing context" .context -}}
{{- $initEnv := dict -}}
{{- range $envEntry := .extraEnv -}}
{{- $_ := set $initEnv $envEntry.name $envEntry.value -}}
{{- end -}}
{{- $overrideEnv := dict "POSTGRES_HOST" (tpl .postgres.host $root) "POSTGRES_PORT" .postgres.port  -}}

{{- $resultEnv := merge $initEnv $overrideEnv -}}
{{- range $key, $value := $resultEnv }}
- name: {{ $key | quote }}
  value: {{ $value | quote }}
{{- end -}}
{{- end -}}
{{- end -}}
