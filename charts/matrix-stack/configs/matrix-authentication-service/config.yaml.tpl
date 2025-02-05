{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: LicenseRef-Element-Commercial */}}

{{- $root := .root }}
{{- with required "config.yaml missing context" .context }}

http:
  public_base: "https://{{ .ingress.host }}"
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
  uri: "postgresql://{{ .user }}:${MAS_DATABASE_PASSWORD}@{{ .host }}:{{ .port }}/{{ .database }}?sslmode={{ .sslmode }}&application_name=matrix-authentication-service"
{{- end }}

telemetry:
  metrics:
    exporter: prometheus

matrix:
  homeserver: "{{ $root.Values.serverName }}"
  secret: ${SYNAPSE_SHARED_SECRET}
  endpoint: "https://{{ $root.Values.synapse.ingress.host }}"

secrets:
  encryption: ${MAS_ENCRYPTION_SECRET}

  keys:
  - kid: prime256v1
    key: |
      ${MAS_ECDSA_PRIME256V1_PRIVATE_KEY}
  - kid: secp256k1
    key: |
      ${MAS_ECDSA_SECP256K1_PRIVATE_KEY}
  - kid: secp384r1
    key: |
      ${MAS_ECDSA_SECP384R1_PRIVATE_KEY}
  - kid: rsa
    key: |
      ${MAS_RSA_PRIVATE_KEY}
experimental:
  access_token_ttl: 86400  # 1 day, up from 5 mins, until EX can better handle refresh tokens

{{- end -}}
