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
app.kubernetes.io/version: {{ .image.tag }}
k8s.element.io/synapse-instance: {{ $root.Release.Name }}-synapse
{{- end }}
{{- end }}

{{- define "element-io.synapse-ingress.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.synapse-ingress.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" .labels) }}
app.kubernetes.io/component: matrix-stack-ingress
app.kubernetes.io/name: synapse
app.kubernetes.io/instance: {{ $root.Release.Name }}-synapse
k8s.element.io/target-name: haproxy
k8s.element.io/target-instance: {{ $root.Release.Name }}-haproxy
app.kubernetes.io/version: {{ .image.tag }}
{{- end }}
{{- end }}

{{- define "element-io.synapse.process.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.synapse.process.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" .labels) }}
app.kubernetes.io/component: matrix-server
app.kubernetes.io/name: synapse-{{ .ProcessType }}
app.kubernetes.io/instance: {{ $root.Release.Name }}-synapse-{{ .ProcessType }}
app.kubernetes.io/version: {{ .image.tag }}
k8s.element.io/synapse-instance: {{ $root.Release.Name }}-synapse
{{- end }}
{{- end }}

{{- define "element-io.synapse-redis.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.synapse-redis.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" .labels) }}
app.kubernetes.io/component: matrix-server-pubsub
app.kubernetes.io/name: synapse-redis
app.kubernetes.io/instance: {{ $root.Release.Name }}-synapse-redis
app.kubernetes.io/version: {{ .image.tag }}
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
{{- with required "element-io.synapse.env missing context" .context -}}
{{- $resultEnv := dict -}}
{{- range $envEntry := .extraEnv -}}
{{- $_ := set $resultEnv $envEntry.name $envEntry.value -}}
{{- end -}}
{{- $overrideEnv := dict "POSTGRES_HOST" (tpl .postgres.host $root) "POSTGRES_PORT" .postgres.port  -}}
{{- $resultEnv := merge $resultEnv $overrideEnv -}}
{{- range $key, $value := $resultEnv }}
- name: {{ $key | quote }}
  value: {{ $value | quote }}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "element-io.synapse.ingress.additionalPaths" -}}
{{- $root := .root -}}
{{- with required "element-io.synapse.ingress.additionalPaths missing context" .context -}}
{{- if $root.Values.matrixAuthenticationService.enabled -}}
{{- range $apiVersion := list "api/v1" "r0" "v3" "unstable" }}
{{- range $apiSubpath := list "login" "refresh" "logout" }}
- path: "/_matrix/client/{{ $apiVersion }}/{{ $apiSubpath }}"
  availability: only_externally
  service:
    name: "{{ $root.Release.Name }}-matrix-authentication-service"
    port:
      name: http
{{- end }}
{{- end }}
{{- end }}
{{- range $root.Values.synapse.ingress.additionalPaths }}
- {{ . | toYaml | indent 2 | trim }}
{{- end -}}
{{- end -}}
{{- end -}}
