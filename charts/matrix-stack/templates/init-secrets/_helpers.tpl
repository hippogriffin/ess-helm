{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- define "element-io.init-secrets.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.init-secrets.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" .labels) }}
app.kubernetes.io/component: matrix-tools
app.kubernetes.io/name: init-secrets
app.kubernetes.io/instance: {{ $root.Release.Name }}-init-secrets
app.kubernetes.io/version: {{ $root.Values.matrixTools.image.tag }}
{{- end }}
{{- end }}

{{- define "element-io.init-secrets.generated-secrets" -}}
{{- $root := .root -}}
{{- with $root.Values.synapse }}
{{- if .enabled -}}
{{- if not .macaroon }}
- {{ (printf "%s-generated" $root.Release.Name) }}:SYNAPSE_MACAROON:rand32
{{- end }}
{{- if not .signingKey }}
- {{ (printf "%s-generated" $root.Release.Name) }}:SYNAPSE_SIGNING_KEY:signingkey
{{- end }}
{{- end }}
{{- end }}
{{- end }}

