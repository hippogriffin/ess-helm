{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- define "element-io.ess-library.pods.pullSecrets" -}}
{{- $root := .root -}}
{{- with required "element-io.ess-library.check-credential missing context" .context -}}
{{- $pullSecrets := list -}}
{{- if $root.Values.global -}}
{{- $pullSecrets := concat .pullSecrets $root.Values.global.ess.imagePullSecrets }}
{{- end -}}
{{- if $root.Values.ess -}}
{{- $pullSecrets := concat .pullSecrets $root.Values.ess.imagePullSecrets }}
{{- end -}}
{{- with ($pullSecrets | uniq) }}
imagePullSecrets:
{{ toYaml . }}
{{- end }}
{{- end }}
{{- end }}
