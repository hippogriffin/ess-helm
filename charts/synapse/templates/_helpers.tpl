# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

{{- define "element-io.synapse.labels" -}}
app.kubernetes.io/part-of: matrix-stack
app.kubernetes.io/component: matrix-server
app.kubernetes.io/name: synapse
app.kubernetes.io/instance: {{ .Release.Name }}-synapse
app.kubernetes.io/version: {{ .Values.image.tag | default $.Chart.AppVersion }}
k8s.element.io/synapse-instance: {{ .Release.Name }}-synapse
{{- end }}

{{- define "element-io.synapse.process.labels" -}}
app.kubernetes.io/part-of: matrix-stack
app.kubernetes.io/component: matrix-server
app.kubernetes.io/name: synapse-{{ .ProcessType }}
app.kubernetes.io/instance: {{ .Release.Name }}-synapse-{{ .ProcessType }}
app.kubernetes.io/version: {{ .Values.image.tag | default $.Chart.AppVersion }}
k8s.element.io/synapse-instance: {{ .Release.Name }}-synapse
{{- end }}

{{- define "element-io.synapse.redis.labels" -}}
app.kubernetes.io/part-of: matrix-stack
app.kubernetes.io/component: matrix-server-pubsub
app.kubernetes.io/name: synapse-redis
app.kubernetes.io/instance: {{ .Release.Name }}-synapse-redis
app.kubernetes.io/version: {{ .Values.redis.image.tag }}
{{- end }}

{{- define "element-io.synapse.haproxy.labels" -}}
app.kubernetes.io/part-of: matrix-stack
app.kubernetes.io/component: matrix-server-ingress
app.kubernetes.io/name: synapse-haproxy
app.kubernetes.io/instance: {{ .Release.Name }}-synapse-haproxy
app.kubernetes.io/version: {{ .Values.haproxy.image.tag }}
{{- end }}

{{- define "element-io.synapse.pvcName" -}}
{{- if .Values.media.storage.existingClaim -}}
{{ .Values.media.storage.existingClaim }}
{{- else -}}
{{ .Release.Name }}-synapse-media
{{- end -}}
{{- end }}
