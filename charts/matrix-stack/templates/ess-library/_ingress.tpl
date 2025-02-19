{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- define "element-io.ess-library.ingress.annotations" -}}
{{- $root := .root -}}
{{- if not (hasKey . "context") -}}
{{- fail "element-io.ess-library.ingress.annotations missing context" -}}
{{- end }}
{{- $annotations := dict -}}
{{- with $root.Values.certManager -}}
{{- with .clusterIssuer -}}
{{- $annotations = merge $annotations (dict "cert-manager.io/cluster-issuer" .) -}}
{{- end -}}
{{- with .issuer -}}
{{- $annotations = merge $annotations (dict "cert-manager.io/issuer" .) -}}
{{- end -}}
{{- end -}}
{{- $annotations = mustMergeOverwrite $annotations ($root.Values.ingress.annotations | deepCopy) -}}
{{- $annotations = mustMergeOverwrite $annotations (.context | deepCopy) -}}
{{- with $annotations -}}
annotations:
  {{- toYaml . | nindent 2 }}
{{- end -}}
{{- end -}}

{{- define "element-io.ess-library.ingress.tlsSecret" -}}
{{- $root := .root -}}
{{- with required "element-io.ess-library.ingress.tlsSecret missing context" .context -}}
{{- $ingressName := required "element-io.ess-library.ingress.tlsSecret missing ingress name" .ingressName -}}
{{- $hosts := .hosts -}}
{{- $tlsSecret := coalesce .tlsSecret $root.Values.ingress.tlsSecret -}}
{{- if or $tlsSecret $root.Values.certManager -}}
tls:
- hosts:
{{- range $host := $hosts }}
  - {{ (tpl $host $root) | quote }}
{{- end }}
  secretName: {{ (tpl ($tlsSecret | default (printf "{{ .Release.Name }}-%s-certmanager-tls" $ingressName))  $root) | quote }}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "element-io.ess-library.ingress.className" -}}
{{- $root := .root -}}
{{- if not (hasKey . "context") -}}
{{- fail "element-io.ess-library.ingress.className missing context" -}}
{{- end }}
{{- with coalesce .context $root.Values.ingress.className -}}
ingressClassName: {{ . | quote }}
{{- end -}}
{{- end -}}
