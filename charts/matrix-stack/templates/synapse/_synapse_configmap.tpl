{{- /*
Copyright 2025 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- define "element-io.synapse.configmap-name" }}
{{- $root := .root }}
{{- with required "element-io.synapse.configmap-name requires context" .context }}
{{- $isHook := required "element-io.synapse.configmap-name requires context.isHook" .isHook }}
{{- if $isHook }}
{{- $root.Release.Name }}-synapse-hook
{{- else }}
{{- $root.Release.Name }}-synapse
{{- end }}
{{- end }}
{{- end }}

{{- define "element-io.synapse.configmap-data" }}
{{- $root := .root }}
{{- with required "element-io.synapse.configmap-data requires context" .context }}
{{- $isHook := required "element-io.synapse.configmap-data requires context.isHook" .isHook }}
data:
  01-homeserver-underrides.yaml: |
    {{- (tpl (include "element-io.synapse.config.shared-underrides" (dict "root" $root "context" $root.Values.synapse)) $root) | nindent 4  }}
{{- /*02 files are user provided in Helm values and end up in the Secret*/}}
{{- /*03 files are user provided as secrets rather than directly in Helm*/}}
  04-homeserver-overrides.yaml: |
    {{- (tpl (include "element-io.synapse.config.shared-overrides" (dict "root" $root "context" (merge dict $root.Values.synapse (dict "isHook" $isHook)))) $root) | nindent 4 }}
  05-main.yaml: |
    {{- (tpl (include "element-io.synapse.config.processSpecific" (dict "root" $root "context" (dict "processType" "main"))) $root) | nindent 4 }}
{{- if not $isHook }}
{{- range $workerType, $workerDetails := (include "element-io.synapse.enabledWorkers" (dict "root" $root)) | fromJson }}
  05-{{ $workerType }}.yaml: |
    {{- (tpl (include "element-io.synapse.config.processSpecific" (dict "root" $root "context" (dict "processType" $workerType))) $root) | nindent 4 }}
{{- end }}
{{- end }}
  log_config.yaml: |
    version: 1

    formatters:
      precise:
        format: '%(asctime)s - %(name)s - %(lineno)d - %(levelname)s - %(request)s - %(message)s'

    handlers:
      console:
        class: logging.StreamHandler
        formatter: precise

    loggers:
    {{- /*
    Increasing synapse.storage.SQL past INFO will log access tokens. Putting in the values default will mean it gets
    nuked if an override is set and then if the root level is increased to debug, the access tokens will be logged.
    Putting here means it is an explicit customer choice to override it.
    */}}
    {{- range $logger, $level := merge dict $root.Values.synapse.logging.levelOverrides (dict "synapse.storage.SQL" "INFO") }}
      {{ $logger }}:
        level: "{{ $level }}"
    {{- end }}

    root:
      level: "{{ $root.Values.synapse.logging.rootLevel }}"
      handlers:
      - console

    disable_existing_loggers: false
{{- end }}
{{- end }}
