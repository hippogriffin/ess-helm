{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- define "element-io.ess-library.labels.common" -}}
{{- $root := .root }}
{{- if not (hasKey . "context") -}}
{{- fail "element-io.ess-library.labels.common missing context" -}}
{{- end }}
{{- $userLabels := dict }}
{{- $userLabels = mustMergeOverwrite $userLabels ($root.Values.labels | deepCopy) }}
{{- $userLabels = mustMergeOverwrite $userLabels (.context | deepCopy) }}
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
helm.sh/chart: {{ $root.Chart.Name }}-{{ $root.Chart.Version | replace "+" "_" }}
app.kubernetes.io/managed-by: {{ $root.Release.Service }}
app.kubernetes.io/part-of: matrix-stack
{{- end }}

{{- define "element-io.ess-library.postgres-label" -}}
{{- $root := .root -}}
{{- with required "element-io.ess-library.postgres-label requires context" .context -}}
{{- $essPassword := required "element-io.ess-library.postgres-label context missing essPassword" .essPassword -}}
{{- $postgresProperty := required "elment-io.ess-library.postgres-label context missing postgresProperty" .postgresProperty -}}
k8s.element.io/postgresPasswordHash: {{ if $postgresProperty -}}
    {{- if $postgresProperty.password.value -}}
    {{- $postgresProperty.password.value | sha1sum -}}
    {{- else -}}
    {{- (printf "%s-%s" (tpl $postgresProperty.password.secret $root) $postgresProperty.password.secretKey) | sha1sum -}}
    {{- end -}}
{{- else if (index $root.Values.postgres.essPasswords $essPassword) }}
    {{- if (index $root.Values.postgres.essPasswords $essPassword).value -}}
    {{- (index $root.Values.postgres.essPasswords $essPassword).value | sha1sum -}}
    {{- else -}}
    {{- (printf "%s-%s" (tpl (index $root.Values.postgres.essPasswords $essPassword).secret $root) (index $root.Values.postgres.essPasswords $essPassword).secretKey) | sha1sum -}}
    {{- end -}}
{{- else -}}
  {{- if $root.Values.initSecrets.enabled -}}
  {{- (printf "%s-generated" $root.Release.Name) | sha1sum  -}}
  {{- else -}}
  {{- fail "No postgres password set and initSecrets not set" -}}
  {{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
