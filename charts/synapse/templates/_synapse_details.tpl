# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

{{- define "element-io.synapse.process.hasHttp" -}}
{{ $hasHttp := (list "main" "client-reader" "encryption" "event-creator"
                     "federation-inbound" "federation-reader" "initial-synchrotron"
                     "media-repository" "presence-writer" "receipts-account"
                     "sliding-sync" "sso-login" "synchrotron" "typing-persister"
                     "user-dir") }}
{{- if has . $hasHttp -}}
hasHttp
{{- end -}}
{{- end }}

{{- define "element-io.synapse.process.hasReplication" -}}
{{- $hasReplication := (list "main" "encryption" "event-persister"
                             "presence-writer" "receipts-account"
                             "typing-persister") }}
{{- if has . $hasReplication -}}
hasReplication
{{- end -}}
{{- end }}

{{- define "element-io.synapse.process.isSingle" -}}
{{ $isSingle := (list "main" "appservice" "background" "encryption"
                      "media-repository" "presence-writer" "receipts-account"
                      "sso-login" "typing-persister" "user-dir") }}
{{- if has . $isSingle -}}
isSingle
{{- end -}}
{{- end }}

{{- define "element-io.synapse.process.workerTypeName" -}}
{{- if eq . "initial-synchrotron" -}}
initial-sync
{{- else -}}
{{ . }}
{{- end -}}
{{- end }}

{{- define "element-io.synapse.process.app" -}}
{{- if eq . "main" -}}
synapse.app.homeserver
{{- else if eq . "media-repository" -}}
synapse.app.media_repository
{{- else -}}
synapse.app.generic_worker
{{- end -}}
{{- end }}

{{- define "element-io.synapse.process.responsibleForMedia" -}}
{{- if and (eq .processType "main") (not (has "media-repository" .configuredWorkers)) -}}
responsibleForMedia
{{- else if eq .processType "media-repository" -}}
responsibleForMedia
{{- end -}}
{{- end }}

{{- define "element-io.synapse.process.streamWriters" -}}
{{- if eq . "encryption" }}
{{ list "to_device" | toJson }}
{{- else if eq . "event-persister" }}
{{ list "events" | toJson }}
{{- else if eq . "presence-writer" }}
{{ list "presence" | toJson }}
{{- else if eq . "receipts-account" }}
{{ list "account_data" "receipts" | toJson }}
{{- else if eq . "typing-persister" }}
{{ list "typing" | toJson }}
{{- else -}}
{{ list | toJson }}
{{- end }}
{{- end }}

{{- define "element-io.synapse.streamWriterWorkers" -}}
{{ $streamWriterWorkers := list }}
{{- range $workerType := keys .Values.workers }}
{{- if include "element-io.synapse.process.streamWriters" $workerType | fromJsonArray -}}
{{ $streamWriterWorkers = append $streamWriterWorkers $workerType }}
{{- end }}
{{- end }}
{{ $streamWriterWorkers | toJson }}
{{- end }}

{{- define "element-io.synapse.configSecrets" -}}
{{ $configSecrets := list (printf "%s-synapse" $.Release.Name) }}
{{- with .Values.macaroon.secret -}}
{{ $configSecrets = append $configSecrets . }}
{{- end -}}
{{- with .Values.postgres.password.secret -}}
{{ $configSecrets = append $configSecrets . }}
{{- end -}}
{{- with .Values.registrationSharedSecret.secret -}}
{{ $configSecrets = append $configSecrets . }}
{{- end -}}
{{- with .Values.signingKey.secret -}}
{{ $configSecrets = append $configSecrets . }}
{{- end -}}
{{ $configSecrets | uniq | toJson }}
{{- end }}
