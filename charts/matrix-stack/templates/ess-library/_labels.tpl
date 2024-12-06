{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- define "element-io.ess-library.labels.common" -}}
{{- $root := .root }}
{{- with required "element-io.ess-library.labels.common missing context" .context }}
{{- $userLabels := dict }}
{{- $userLabels = mustMergeOverwrite $userLabels ($root.Values.labels | deepCopy) }}
{{- $userLabels = mustMergeOverwrite $userLabels (. | deepCopy) }}
{{- /* These labels are owned by the chart, don't allow overriding */}}
{{- $userLabels = unset $userLabels "helm.sh/chart.sh" }}
{{- $userLabels = unset $userLabels "app.kubernetes.io/managed-by" }}
{{- $userLabels = unset $userLabels "app.kubernetes.io/part-of" }}
{{- $userLabels = unset $userLabels "app.kubernetes.io/component" }}
{{- $userLabels = unset $userLabels "app.kubernetes.io/name" }}
{{- $userLabels = unset $userLabels "app.kubernetes.io/instance" }}
{{- $userLabels = unset $userLabels "app.kubernetes.io/version" }}
{{- if $userLabels }}
{{- toYaml $userLabels }}
{{- end }}
{{- end }}
helm.sh/chart: {{ $root.Chart.Name }}-{{ $root.Chart.Version | replace "+" "_" }}
app.kubernetes.io/managed-by: {{ $root.Release.Service }}
app.kubernetes.io/part-of: matrix-stack
{{- end }}
