{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- define "element-io.ess-library.pods.pullSecrets" -}}
{{- $root := .root -}}
{{- with required "element-io.ess-library.pods.pullSecrets missing context" .context -}}
{{- $pullSecrets := concat .pullSecrets $root.Values.imagePullSecrets }}
{{- with ($pullSecrets | uniq) }}
imagePullSecrets:
{{ tpl (toYaml .) $root }}
{{- end }}
{{- end }}
{{- end }}

{{- define "element-io.ess-library.pods.tolerations" -}}
{{- $root := .root -}}
{{- if not (hasKey . "context") -}}
{{- fail "element-io.ess-library.pods.tolerations missing context" -}}
{{- end }}
{{- $tolerations := concat .context $root.Values.tolerations }}
{{- with ($tolerations | uniq) }}
tolerations:
{{ toYaml . }}
{{- end }}
{{- end }}

{{- define "element-io.ess-library.pods.topologySpreadConstraints" -}}
{{- $root := .root -}}
{{- with required "element-io.ess-libary.pods.topologySpreadConstraints missing context" .context -}}
{{- $labelSelector := (dict "matchLabels" (dict "app.kubernetes.io/instance" (printf "%s-%s" $root.Release.Name .instanceSuffix))) }}
{{- $matchLabelKeys := .deployment | ternary (list "pod-template-hash") list }}
{{- $defaultConstraintSettings := dict "labelSelector" $labelSelector "matchLabelKeys" $matchLabelKeys "whenUnsatisfiable" "DoNotSchedule" }}
{{- $topologySpreadConstraints := list -}}
{{- range $constraint := coalesce .topologySpreadConstraints $root.Values.topologySpreadConstraints -}}
{{- $topologySpreadConstraints = append $topologySpreadConstraints (mergeOverwrite (deepCopy $defaultConstraintSettings) $constraint) -}}
{{- end }}
{{- with $topologySpreadConstraints }}
topologySpreadConstraints:
{{ toYaml . }}
{{- end }}
{{- end }}
{{- end }}
