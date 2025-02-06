{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- $root := .root }}
{{- with required "config.yaml missing context" .context }}

http:
  public_base: "https://{{ tpl .ingress.host $root }}"
  listeners:
  - name: web
    binds:
    - host: 0.0.0.0
      port: 8080
    resources:
    - name: human
    - name: discovery
    - name: oauth
    - name: compat
    - name: assets
    - name: graphql
      # This lets us use the GraphQL API with an OAuth 2.0 access token,
      # which we currently use in the ansible modules and in synapse-admin
      undocumented_oauth2_access: true
    - name: adminapi
  - name: internal
    binds:
    - host: 0.0.0.0
      port: 8081
    resources:
    - name: health
    - name: prometheus
    - name: connection-info

{{- with required "matrixAuthenticationService.postgres is required" .postgres }}
database:
  uri: "postgresql://{{ .user }}:${POSTGRES_PASSWORD}@{{ tpl .host $root }}:{{ .port }}/{{ .database }}?{{ with .sslMode }}sslmode={{ . }}&{{ end }}application_name=matrix-authentication-service"
{{- end }}

telemetry:
  metrics:
    exporter: prometheus

matrix:
  homeserver: "{{ $root.Values.serverName }}"
  secret: ${SYNAPSE_SHARED_SECRET}
  endpoint: "https://{{ tpl $root.Values.synapse.ingress.host $root }}"

secrets:
  encryption: ${ENCRYPTION_SECRET}

  keys:
{{- with required "privateKeys is required for Matrix Authentication Service" .privateKeys }}
  - kid: rsa
    key_file: /secrets/{{
                include "element-io.ess-library.init-secret-path" (
                      dict "root" $root
                      "context" (dict
                        "secretProperty" .rsa
                        "initSecretKey" "MAS_RSA_PRIVATE_KEY"
                        "defaultSecretName" (printf "%s-matrix-authentication-service" $root.Release.Name)
                        "defaultSecretKey" "RSA_PRIVATE_KEY"
                      )
                    ) }}
  - kid: prime256v1
    key_file: /secrets/{{
                include "element-io.ess-library.init-secret-path" (
                      dict "root" $root
                      "context" (dict
                        "secretProperty" .ecdsaPrime256v1
                        "initSecretKey" "MAS_ECDSA_PRIME256V1_PRIVATE_KEY"
                        "defaultSecretName" (printf "%s-matrix-authentication-service" $root.Release.Name)
                        "defaultSecretKey" "ECDSA_PRIME256V1_PRIVATE_KEY"
                      )
                  ) }}
{{ with .ecdsaSecp256k1 }}
  - kid: secp256k1
    key_file: /secrets/{{
                include "element-io.ess-library.provided-secret-path" (
                        dict "root" $root
                        "context" (dict
                          "secretProperty" .
                          "defaultSecretName" (printf "%s-matrix-authentication-service" $root.Release.Name)
                          "defaultSecretKey" "ECDSA_SECP256K1_PRIVATE_KEY"
                        )
                    ) }}
{{- end }}
{{ with .ecdsaSecp384r1 }}
  - kid: secp384r1
    key_file: /secrets/{{
                include "element-io.ess-library.provided-secret-path" (
                        dict "root" $root
                        "context" (dict
                          "secretProperty" .
                          "defaultSecretName" (printf "%s-matrix-authentication-service" $root.Release.Name)
                          "defaultSecretKey" "ECDSA_SECP384R1_PRIVATE_KEY"
                        )
                    ) }}
{{- end }}
{{- end }}
experimental:
  access_token_ttl: 86400  # 1 day, up from 5 mins, until EX can better handle refresh tokens

{{- end -}}
