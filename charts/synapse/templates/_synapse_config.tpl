# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

{{- define "element-io.synapse.config.shared-underrides" -}}
report_stats: false

require_auth_for_profile_requests: true
{{ end }}

{{- define "element-io.synapse.config.shared-overrides" -}}
public_baseurl: https://{{ .Values.ingress.host }}
server_name: {{ required "Synapse requires global.ess.server_name set" .Values.global.ess.server_name }}
signing_key_path: /secrets/{{ $.Values.signingKey.secret | default (printf "%s-synapse" $.Release.Name) }}/{{ $.Values.signingKey.secretKey | default "SIGNING_KEY" }}
enable_metrics: true
log_config: "/conf/log_config.yaml"
macaroon_secret_key: ${SYNAPSE_MACAROON}
registration_shared_secret: ${SYNAPSE_REGISTRATION_SHARED_SECRET}

database:
  name: psycopg2
  args:
    user: {{ .Values.postgres.user }}
    password: ${SYNAPSE_POSTGRES_PASSWORD}
    database: {{ .Values.postgres.database }}
    host: {{ .Values.postgres.host }}
    port: {{ .Values.postgres.port }}

    application_name: ${APPLICATION_NAME}
    sslmode: {{ .Values.postgres.sslmode }}
    keepalives: 1
    keepalives_idle: 10
    keepalives_interval: 10
    keepalives_count: 3

# The default as of 1.27.0
ip_range_blacklist:
- '127.0.0.0/8'
- '10.0.0.0/8'
- '172.16.0.0/12'
- '192.168.0.0/16'
- '100.64.0.0/10'
- '192.0.0.0/24'
- '169.254.0.0/16'
- '192.88.99.0/24'
- '198.18.0.0/15'
- '192.0.2.0/24'
- '198.51.100.0/24'
- '203.0.113.0/24'
- '224.0.0.0/4'
- '::1/128'
- 'fe80::/10'
- 'fc00::/7'
- '2001:db8::/32'
- 'ff00::/8'
- 'fec0::/10'

{{- if hasKey .Values.workers "appservice" }}

notify_appservices_from_worker: appservice-0
{{- end }}

{{- with .Values.appservices }}
app_service_config_files:
{{- range $appservice := . }}
 - /as/{{ .registrationFileConfigMapName }}/registration.yaml
{{- end }}
{{- end }}

{{- if hasKey .Values.workers "background" }}

run_background_tasks_on: background-0
{{- end }}

send_federation: {{ not (hasKey .Values.workers "federation-sender") }}
{{- if hasKey .Values.workers "federation-sender" }}
federation_sender_instances:
{{- range $index := untilStep 0 ((index .Values.workers "federation-sender").instances | int | default 1) 1 }}
- federation-sender-{{ $index }}
{{- end }}
{{- end }}

# This is still required despite media_storage_providers as otherwise Synapse attempts to mkdir /media_store
media_store_path: "/media/media_store"
{{- if hasKey .Values.workers "media-repository" }}
media_instance_running_background_jobs: "media-repository-0"
{{- end }}

presence:
  enabled: {{ hasKey .Values.workers "presence-writer" }}

start_pushers: {{ not (hasKey .Values.workers "pusher") }}
{{- if hasKey .Values.workers "pusher" }}
pusher_instances:
{{- range $index := untilStep 0 ((index .Values.workers "pusher").instances | int | default 1) 1 }}
- pusher-{{ $index }}
{{- end }}
{{- end }}

{{- if hasKey .Values.workers "user-dir" }}

update_user_directory_from_worker: user-dir-0
{{- end }}

instance_map:
  main:
    host: {{ $.Release.Name }}-synapse-main.{{ $.Release.Namespace }}.svc.cluster.local.
    port: 9093
{{- range $workerType, $workerDetails := .Values.workers }}
{{- if include "element-io.synapse.process.hasReplication" $workerType }}
{{- range $index := untilStep 0 ($workerDetails.instances | int | default 1) 1 }}
  {{ $workerType }}-{{ $index }}:
    host: {{ $.Release.Name }}-synapse-{{ $workerType }}-{{ $index }}.{{ $.Release.Name }}-synapse-{{ $workerType }}.{{ $.Release.Namespace }}.svc.cluster.local.
    port: 9093
{{- end }}
{{- end }}
{{- end }}

{{- if .Values.workers }}

redis:
  enabled: true
  host: "{{ $.Release.Name }}-synapse-redis.{{ $.Release.Namespace }}.svc.cluster.local"
{{- if include "element-io.synapse.streamWriterWorkers" $ | fromJsonArray }}

stream_writers:
{{- range $workerType, $workerDetails := .Values.workers }}
{{- if include "element-io.synapse.process.streamWriters" $workerType | fromJsonArray }}
{{- range $stream_writer := include "element-io.synapse.process.streamWriters" $workerType | fromJsonArray }}
  {{ $stream_writer }}:
{{- range $index := untilStep 0 ($workerDetails.instances | int | default 1) 1 }}
  - {{ $workerType }}-{{ $index }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{ end }}


{{- define "element-io.synapse.config.processSpecific" -}}
worker_app: {{ include "element-io.synapse.process.app" .processType }}

{{- if eq .processType "main" }}
listeners:
{{- else }}
worker_name: ${APPLICATION_NAME}

worker_listeners:
{{- end }}
{{- if (include "element-io.synapse.process.hasHttp" .processType) }}
- port: 8008
  tls: false
  bind_addresses: ['0.0.0.0']
  type: http
  x_forwarded: true
  resources:
  - names:
    - client
    - federation
{{- /* main always loads this if client or federation is set. media-repo workers need it explicitly set.... */}}
{{- if eq .processType "media-repository" }}
    - media
{{- end }}
    compress: false
{{- end }}
{{- if (include "element-io.synapse.process.hasReplication" .processType) }}
- port: 9093
  tls: false
  bind_addresses: ['0.0.0.0']
  type: http
  x_forwarded: false
  resources:
  - names: [replication]
    compress: false
{{- end }}
- type: metrics
  port: 9001
  bind_addresses: ['0.0.0.0']
{{- /* Unfortunately the metrics type doesn't get the health endpoint*/}}
- port: 8080
  tls: false
  bind_addresses: ['0.0.0.0']
  type: http
  x_forwarded: false
  resources:
  - names: []
    compress: false

{{- if (include "element-io.synapse.process.responsibleForMedia" (dict "processType" .processType "configuredWorkers" (keys .Values.workers))) }}
enable_media_repo: true
{{- else }}
# Stub out the media storage provider for processes not responsible for media
media_storage_providers:
- module: file_system
  store_local: false
  store_remote: false
  store_synchronous: false
  config:
    directory: "/media/media_store"
{{- end }}
{{ end }}
