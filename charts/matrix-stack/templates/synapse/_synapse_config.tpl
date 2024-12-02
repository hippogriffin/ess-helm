{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- define "element-io.synapse.config.shared-underrides" -}}
{{- $root := .root -}}
{{- with required "element-io.synapse.config.shared-underrides missing context" .context -}}
report_stats: false

require_auth_for_profile_requests: true
{{ end }}
{{ end }}

{{- define "element-io.synapse.config.shared-overrides" -}}
{{- $root := .root -}}
{{- with required "element-io.synapse.config.shared-overrides missing context" .context -}}
public_baseurl: https://{{ .ingress.host }}
server_name: {{ required "Synapse requires ess.serverName set" $root.Values.ess.serverName }}
signing_key_path: /secrets/{{ .signingKey.secret | default (printf "%s-synapse" $root.Release.Name) }}/{{ .signingKey.secretKey | default "SIGNING_KEY" }}
enable_metrics: true
log_config: "/conf/log_config.yaml"
macaroon_secret_key: ${SYNAPSE_MACAROON}
registration_shared_secret: ${SYNAPSE_REGISTRATION_SHARED_SECRET}

database:
  name: psycopg2
  args:
    user: {{ required "Synapse requires postgres.user set" .postgres.user }}
    password: ${SYNAPSE_POSTGRES_PASSWORD}
    database: {{ required "Synapse requires postgres.database set" .postgres.database }}
    host: {{ required "Synapse requires postgres.host set" .postgres.host }}
    port: {{ required "Synapse requires postgres.port set" .postgres.port }}

    application_name: ${APPLICATION_NAME}
    sslmode: {{ .postgres.sslMode }}
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

{{- if dig "appservice" "enabled" false .workers }}

notify_appservices_from_worker: appservice-0
{{- end }}

{{- with .appservices }}
app_service_config_files:
{{- range $appservice := . }}
 - /as/{{ .registrationFileConfigMapName }}/registration.yaml
{{- end }}
{{- end }}

{{- if dig "background" "enabled" false .workers }}

run_background_tasks_on: background-0
{{- end }}

{{- if dig "federation-sender" "enabled" false .workers }}

send_federation: false
federation_sender_instances:
{{- range $index := untilStep 0 ((index .workers "federation-sender").instances | int) 1 }}
- federation-sender-{{ $index }}
{{- end }}
{{- else }}

send_federation: true
{{- end }}

# This is still required despite media_storage_providers as otherwise Synapse attempts to mkdir /media_store
media_store_path: "/media/media_store"
{{- if dig "media-repository" "enabled" false .workers }}
media_instance_running_background_jobs: "media-repository-0"
{{- end }}

presence:
  enabled: {{ dig "presence-writer" "enabled" false .workers }}

{{- if dig "pusher" "enabled" false .workers }}

start_pushers: false
pusher_instances:
{{- range $index := untilStep 0 ((index .workers "pusher").instances | int) 1 }}
- pusher-{{ $index }}
{{- end }}
{{- else }}

start_pushers: true
{{- end }}

{{- if dig "user-dir" "enabled" false .workers }}

update_user_directory_from_worker: user-dir-0
{{- end }}
{{- $enabledWorkers := (include "element-io.synapse.enabledWorkers" (dict "root" $root)) | fromJson }}

instance_map:
  main:
    host: {{ $root.Release.Name }}-synapse-main.{{ $root.Release.Namespace }}.svc.cluster.local.
    port: 9093
{{- range $workerType, $workerDetails := $enabledWorkers }}
{{- if include "element-io.synapse.process.hasReplication" (dict "root" $root "context" $workerType) }}
{{- range $index := untilStep 0 ($workerDetails.instances | int | default 1) 1 }}
  {{ $workerType }}-{{ $index }}:
    host: {{ $root.Release.Name }}-synapse-{{ $workerType }}-{{ $index }}.{{ $root.Release.Name }}-synapse-{{ $workerType }}.{{ $root.Release.Namespace }}.svc.cluster.local.
    port: 9093
{{- end }}
{{- end }}
{{- end }}

{{- if $enabledWorkers }}

redis:
  enabled: true
  host: "{{ $root.Release.Name }}-synapse-redis.{{ $root.Release.Namespace }}.svc.cluster.local"
{{- if include "element-io.synapse.streamWriterWorkers" (dict "root" $root "context" .) | fromJsonArray }}

stream_writers:
{{- range $workerType, $workerDetails := $enabledWorkers }}
{{- if include "element-io.synapse.process.streamWriters" (dict "root" $root "context" $workerType) | fromJsonArray }}
{{- range $stream_writer := include "element-io.synapse.process.streamWriters" (dict "root" $root "context" $workerType) | fromJsonArray }}
  {{ $stream_writer }}:
{{- range $index := untilStep 0 ($workerDetails.instances | int | default 1) 1 }}
  - {{ $workerType }}-{{ $index }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{ end }}


{{- define "element-io.synapse.config.processSpecific" -}}
{{- $root := .root -}}
{{- with required "element-io.synapse.config.processSpecific missing context" .context -}}
worker_app: {{ include "element-io.synapse.process.app" (dict "root" $root "context" .processType) }}

{{- if eq .processType "main" }}
listeners:
{{- else }}
worker_name: ${APPLICATION_NAME}

worker_listeners:
{{- end }}
{{- if (include "element-io.synapse.process.hasHttp" (dict "root" $root "context" .processType)) }}
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
{{- if (include "element-io.synapse.process.hasReplication" (dict "root" $root "context" .processType)) }}
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

{{- $enabledWorkers := (include "element-io.synapse.enabledWorkers" (dict "root" $root)) | fromJson }}
{{- if (include "element-io.synapse.process.responsibleForMedia" (dict "root" $root "context" (dict "processType" .processType "enabledWorkerTypes" (keys $enabledWorkers)))) }}
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
{{- end }}
{{ end }}
