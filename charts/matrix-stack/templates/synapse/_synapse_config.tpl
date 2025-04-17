{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only
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
{{- $isHook := required "element-io.synapse.config.shared-overrides requires context.isHook" .isHook -}}
public_baseurl: https://{{ .ingress.host }}/
server_name: {{ required "Synapse requires serverName set" $root.Values.serverName }}
signing_key_path: /secrets/{{
  include "element-io.ess-library.init-secret-path" (
    dict "root" $root "context" (
      dict "secretPath" "synapse.signingKey"
           "initSecretKey" "SYNAPSE_SIGNING_KEY"
           "defaultSecretName" (include "element-io.synapse.secret-name" (dict "root" $root "context" (dict "isHook" $isHook)))
           "defaultSecretKey" "SIGNING_KEY"
      )
    ) }}
enable_metrics: true
log_config: "/conf/log_config.yaml"
macaroon_secret_key_path:  /secrets/{{
  include "element-io.ess-library.init-secret-path" (
    dict "root" $root "context" (
      dict "secretPath" "synapse.macaroon"
           "initSecretKey" "SYNAPSE_MACAROON"
           "defaultSecretName" (include "element-io.synapse.secret-name" (dict "root" $root "context" (dict "isHook" $isHook)))
           "defaultSecretKey" "MACAROON"
      )
    ) }}
registration_shared_secret_path: /secrets/{{
  include "element-io.ess-library.init-secret-path" (
    dict "root" $root "context" (
      dict "secretPath" "synapse.registrationSharedSecret"
           "initSecretKey" "SYNAPSE_REGISTRATION_SHARED_SECRET"
           "defaultSecretName" (include "element-io.synapse.secret-name" (dict "root" $root "context" (dict "isHook" $isHook)))
           "defaultSecretKey" "REGISTRATION_SHARED_SECRET"
      )
    ) }}

database:
  name: psycopg2
  args:
{{- if .postgres }}
    user: {{ required "Synapse requires postgres.user set" .postgres.user }}
    password: ${SYNAPSE_POSTGRES_PASSWORD}
    database: {{ required "Synapse requires postgres.database set" .postgres.database }}
    host: {{ required "Synapse requires postgres.host set" .postgres.host }}
    port: {{ .postgres.port | default 5432 }}
    sslmode: {{ .postgres.sslMode | default "prefer" }}
{{- else if $root.Values.postgres.enabled }}
    user: "synapse_user"
    password: ${SYNAPSE_POSTGRES_PASSWORD}
    database: "synapse"
    host: "{{ $root.Release.Name }}-postgres.{{ $root.Release.Namespace }}.svc.cluster.local"
    port: 5432
    sslmode: prefer
{{ else }}
  {{ fail "Synapse requires synapse.postgres.* to be configured, or the internal chart Postgres to be enabled with postgres.enabled: true" }}
{{ end }}

    application_name: ${APPLICATION_NAME}
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

{{- if (and $root.Values.matrixAuthenticationService.enabled (not $root.Values.matrixAuthenticationService.preMigrationSynapseHandlesAuth)) }}
experimental_features:
  msc3861:
    enabled: true

    issuer: http://{{ $root.Release.Name }}-matrix-authentication-service.{{ $root.Release.Namespace }}.svc.cluster.local:8080/
    client_id_path: /secrets/{{
      include "element-io.ess-library.init-secret-path" (
        dict "root" $root "context" (dict
          "secretPath" "matrixAuthenticationService.synapseOIDCClientId"
          "initSecretKey" "MAS_SYNAPSE_OIDC_CLIENT_ID"
          "defaultSecretName" (include "element-io.matrix-authentication-service.secret-name" (dict "root" $root "context" (dict "isHook" $isHook)))
          "defaultSecretKey" "SYNAPSE_OIDC_CLIENT_ID"
        )
      ) }}
    client_auth_method: client_secret_basic
    # client.<client_id> in the MAS secret
    client_secret_path: /secrets/{{
      include "element-io.ess-library.init-secret-path" (
        dict "root" $root "context" (dict
          "secretPath" "matrixAuthenticationService.synapseOIDCClientSecret"
          "initSecretKey" "MAS_SYNAPSE_OIDC_CLIENT_SECRET"
          "defaultSecretName" (include "element-io.matrix-authentication-service.secret-name" (dict "root" $root "context" (dict "isHook" $isHook)))
          "defaultSecretKey" "SYNAPSE_OIDC_CLIENT_SECRET"
        )
      ) }}
    # serverSecret in the MAS secret
    admin_token_path: /secrets/{{
      include "element-io.ess-library.init-secret-path" (
        dict "root" $root "context" (dict
          "secretPath" "matrixAuthenticationService.synapseSharedSecret"
          "initSecretKey" "MAS_SYNAPSE_SHARED_SECRET"
          "defaultSecretName" (include "element-io.matrix-authentication-service.secret-name" (dict "root" $root "context" (dict "isHook" $isHook)))
          "defaultSecretKey" "SYNAPSE_SHARED_SECRET"
          )
      ) }}
    introspection_endpoint: "http://{{ $root.Release.Name }}-matrix-authentication-service.{{ $root.Release.Namespace }}.svc.cluster.local:8080/oauth2/introspect"

  # QR Code Login. Requires MAS
  msc4108_enabled: true
password_config:
  localdb_enabled: false
  enabled: false
{{- end }}

{{- if dig "appservice" "enabled" false .workers }}

notify_appservices_from_worker: {{ $root.Release.Name }}-synapse-appservice-0
{{- end }}

{{- with .appservices }}
app_service_config_files:
{{- range $idx, $appservice := . }}
{{- if $appservice.configMap }}
 - /as/{{ $idx }}/{{ $appservice.configMapKey }}
{{- else }}
 - /as/{{ $idx }}/{{ $appservice.secretKey }}
{{- end }}
{{- end }}
{{- end }}

{{- if dig "background" "enabled" false .workers }}

run_background_tasks_on: {{ $root.Release.Name }}-synapse-background-0
{{- end }}

{{- if dig "federation-sender" "enabled" false .workers }}

send_federation: false
federation_sender_instances:
{{- range $index := untilStep 0 ((index .workers "federation-sender").replicas | int) 1 }}
- {{ $root.Release.Name }}-synapse-federation-sender-{{ $index }}
{{- end }}
{{- else }}

send_federation: true
{{- end }}

# This is still required despite media_storage_providers as otherwise Synapse attempts to mkdir /media_store
media_store_path: "/media/media_store"
max_upload_size: "{{ .media.maxUploadSize }}"
{{- if dig "media-repository" "enabled" false .workers }}
media_instance_running_background_jobs: "{{ $root.Release.Name }}-synapse-media-repository-0"
{{- end }}

{{- if dig "pusher" "enabled" false .workers }}

start_pushers: false
pusher_instances:
{{- range $index := untilStep 0 ((index .workers "pusher").replicas | int) 1 }}
- {{ $root.Release.Name }}-synapse-pusher-{{ $index }}
{{- end }}
{{- else }}

start_pushers: true
{{- end }}

{{- if dig "user-dir" "enabled" false .workers }}

update_user_directory_from_worker: {{ $root.Release.Name }}-synapse-user-dir-0
{{- end }}
{{- $enabledWorkers := (include "element-io.synapse.enabledWorkers" (dict "root" $root)) | fromJson }}

instance_map:
  main:
    host: {{ $root.Release.Name }}-synapse-main.{{ $root.Release.Namespace }}.svc.cluster.local.
    port: 9093
{{- range $workerType, $workerDetails := $enabledWorkers }}
{{- if include "element-io.synapse.process.hasReplication" (dict "root" $root "context" $workerType) }}
{{- range $index := untilStep 0 ($workerDetails.replicas | int | default 1) 1 }}
  {{ $root.Release.Name }}-synapse-{{ $workerType }}-{{ $index }}:
    host: {{ $root.Release.Name }}-synapse-{{ $workerType }}-{{ $index }}.{{ $root.Release.Name }}-synapse-{{ $workerType }}.{{ $root.Release.Namespace }}.svc.cluster.local.
    port: 9093
{{- end }}
{{- end }}
{{- end }}

{{- if $enabledWorkers }}

redis:
  enabled: true
  host: "{{ $root.Release.Name }}-synapse-redis.{{ $root.Release.Namespace }}.svc.cluster.local"
{{- if include "element-io.synapse.streamWriterWorkers" (dict "root" $root) | fromJsonArray }}

stream_writers:
{{- range $workerType, $workerDetails := $enabledWorkers }}
{{- if include "element-io.synapse.process.streamWriters" (dict "root" $root "context" $workerType) | fromJsonArray }}
{{- range $stream_writer := include "element-io.synapse.process.streamWriters" (dict "root" $root "context" $workerType) | fromJsonArray }}
  {{ $stream_writer }}:
{{- range $index := untilStep 0 ($workerDetails.replicas | int | default 1) 1 }}
  - {{ $root.Release.Name }}-synapse-{{ $workerType }}-{{ $index }}
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
  - names: [health]
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
