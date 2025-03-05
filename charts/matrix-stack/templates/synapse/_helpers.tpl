{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- define "element-io.synapse.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.synapse.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" .labels) }}
app.kubernetes.io/component: matrix-server
app.kubernetes.io/name: synapse
app.kubernetes.io/instance: {{ $root.Release.Name }}-synapse
app.kubernetes.io/version: {{ .image.tag }}
k8s.element.io/synapse-instance: {{ $root.Release.Name }}-synapse
{{- end }}
{{- end }}

{{- define "element-io.synapse-check-config-hook.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.synapse.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" .labels) }}
app.kubernetes.io/component: matrix-server
app.kubernetes.io/name: synapse-check-config-hook
app.kubernetes.io/instance: {{ $root.Release.Name }}-synapse-check-config-hook
app.kubernetes.io/version: {{ $root.Values.synapse.image.tag }}
k8s.element.io/synapse-instance: {{ $root.Release.Name }}-synapse-check-config-hook
{{- end }}
{{- end }}

{{- define "element-io.synapse-ingress.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.synapse-ingress.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" .labels) }}
app.kubernetes.io/component: matrix-stack-ingress
app.kubernetes.io/name: synapse
app.kubernetes.io/instance: {{ $root.Release.Name }}-synapse
k8s.element.io/target-name: haproxy
k8s.element.io/target-instance: {{ $root.Release.Name }}-haproxy
app.kubernetes.io/version: {{ .image.tag }}
{{- end }}
{{- end }}

{{- define "element-io.synapse.process.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.synapse.process.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" .labels) }}
app.kubernetes.io/component: matrix-server
app.kubernetes.io/name: synapse-{{ .processType }}
app.kubernetes.io/instance: {{ $root.Release.Name }}-synapse-{{ .processType }}
app.kubernetes.io/version: {{ .image.tag }}
{{ if required "element-io.synapse.process.labels missing context.isHook" .isHook }}
k8s.element.io/synapse-instance: {{ $root.Release.Name }}-synapse-check-config-hook
{{ else }}
k8s.element.io/synapse-instance: {{ $root.Release.Name }}-synapse
{{- end }}
{{- end }}
{{- end }}

{{- define "element-io.synapse-redis.labels" -}}
{{- $root := .root -}}
{{- with required "element-io.synapse-redis.labels missing context" .context -}}
{{ include "element-io.ess-library.labels.common" (dict "root" $root "context" .labels) }}
app.kubernetes.io/component: matrix-server-pubsub
app.kubernetes.io/name: synapse-redis
app.kubernetes.io/instance: {{ $root.Release.Name }}-synapse-redis
app.kubernetes.io/version: {{ .image.tag }}
{{- end }}
{{- end }}

{{- define "element-io.synapse.enabledWorkers" -}}
{{- $root := .root -}}
{{ $enabledWorkers := dict }}
{{- range $workerType, $workerDetails := $root.Values.synapse.workers }}
{{- if $workerDetails.enabled }}
{{ $_ := set $enabledWorkers $workerType $workerDetails }}
{{- end }}
{{- end }}
{{ $enabledWorkers | toJson }}
{{- end }}

{{- define "element-io.synapse.pvcName" -}}
{{- $root := .root -}}
{{- with required "element-io.synapse.pvcName missing context" .context -}}
{{- if $root.Values.synapse.media.storage.existingClaim -}}
{{ tpl $root.Values.synapse.media.storage.existingClaim $root }}
{{- else -}}
{{ $root.Release.Name }}-synapse-media
{{- end -}}
{{- end }}
{{- end }}

{{- define "element-io.synapse.env" }}
{{- $root := .root -}}
{{- with required "element-io.synapse.env missing context" .context -}}
{{- $resultEnv := dict -}}
{{- range $envEntry := .extraEnv -}}
{{- $_ := set $resultEnv $envEntry.name $envEntry.value -}}
{{- end -}}
{{- range $key, $value := $resultEnv }}
- name: {{ $key | quote }}
  value: {{ $value | quote }}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "element-io.synapse.pythonEnv" }}
{{- $root := .root -}}
{{- with required "element-io.synapse.pythonEnv missing context" .context -}}
- name: "LD_PRELOAD"
  value: "libjemalloc.so.2"
{{- end -}}
{{- end -}}

{{- define "element-io.synapse.ingress.additionalPaths" -}}
{{- $root := .root -}}
{{- with required "element-io.synapse.ingress.additionalPaths missing context" .context -}}
{{- if $root.Values.matrixAuthenticationService.enabled -}}
{{- range $apiVersion := list "api/v1" "r0" "v3" "unstable" }}
{{- range $apiSubpath := list "login" "refresh" "logout" }}
- path: "/_matrix/client/{{ $apiVersion }}/{{ $apiSubpath }}"
  availability: only_externally
  service:
    name: "{{ $root.Release.Name }}-matrix-authentication-service"
    port:
      name: http
{{- end }}
{{- end }}
{{- end }}
{{- range $root.Values.synapse.ingress.additionalPaths }}
- {{ . | toYaml | indent 2 | trim }}
{{- end -}}
{{- end -}}
{{- end -}}


{{- /* The filesystem structure is `/secrets`/<< secret name>>/<< secret key >>.
        The non-defaulted values are handling the case where the credential is provided by an existing Secret
        The default values are handling the case where the credential is provided plain in the Helm chart and we add it to our Secret with a well-known key.

        These could be done as env vars with valueFrom.secretKeyRef, but that triggers CKV_K8S_35.
        Environment variables values found in the config file as ${VARNAME} are parsed through go template engine before being replaced in the target file.
*/}}
{{- define "element-io.synapse.matrixToolsEnv" }}
{{- $root := .root -}}
{{- with required "element-io.synapse.matrixToolsEnv missing context" .context -}}
{{- $isHook := required "element-io.synapse.matrixToolsEnv requires context.isHook" .isHook }}
- name: SYNAPSE_POSTGRES_PASSWORD
  value: >-
    {{
      printf "{{ readfile \"/secrets/%s\" | quote }}"
        (
          include "element-io.ess-library.postgres-secret-path" (
            dict "root" $root
            "context" (dict
              "essPassword" "synapse"
              "initSecretKey" "POSTGRES_SYNAPSE_PASSWORD"
              "componentPasswordPath" "synapse.postgres.password"
              "defaultSecretName" (include "element-io.synapse.secret-name" (dict "root" $root "context" (dict "isHook" .isHook)))
              "defaultSecretKey" "POSTGRES_PASSWORD"
            )
          )
        )
    }}
{{- if $root.Values.matrixAuthenticationService.enabled }}
- name: MAS_SHARED_SECRET
  value: >-
    {{
    printf "{{ readfile \"/secrets/%s\" | quote }}" (
        include "element-io.ess-library.init-secret-path" (
            dict "root" $root
            "context" (dict
              "secretPath" "matrixAuthenticationService.synapseSharedSecret"
              "initSecretKey" "MAS_SYNAPSE_SHARED_SECRET"
              "defaultSecretName" (printf "%s-matrix-authentication-service" $root.Release.Name)
              "defaultSecretKey" "SYNAPSE_SHARED_SECRET"
            )
        )
      )
    }}
- name: MAS_OIDC_CLIENT_SECRET
  value: >-
    {{
      printf "{{ readfile \"/secrets/%s\" | quote }}" (
        include "element-io.ess-library.init-secret-path" (
            dict "root" $root
            "context" (dict
              "secretPath" "matrixAuthenticationService.synapseOIDCClientSecret"
              "initSecretKey" "MAS_SYNAPSE_OIDC_CLIENT_SECRET"
              "defaultSecretName" (printf "%s-matrix-authentication-service" $root.Release.Name)
              "defaultSecretKey" "SYNAPSE_OIDC_CLIENT_SECRET"
            )
          )
        )
    }}
{{- end }}
- name: APPLICATION_NAME
  value: >-
    {{ printf "{{ hostname | replace \"-synapse-\" \"\" }}" }}
{{- end }}
{{- end }}
