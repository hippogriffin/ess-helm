<!--
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
-->

# Matrix Stack Chart

This Helm chart deploys a coherent Matrix Stack. It currently includes the following components
* [Synapse](https://github.com/element-hq/synapse) as a Matrix homeserver
* [Element Web](https://github.com/element-hq/element-web) as a Matrix client

## Common

The components deployed in the chart can share some configuration. You'll find below the relevant sections of values.yaml.

### Labels

The components deployed in the chart can share labels using the `labels` base section. Any value can be configured here to apply them globally, and will be merged into the per components labels.

```yaml
labels:
  my-deployment: ess-deployment
```

### Ingress Configuration

Ingresses of the individual components in the chart can share the same configuration using the `ingress` base section.
Any `annotations`, `className`, `tlsSecret` can be configured here to apply them globally, but can be overridden on a per component basis.

```yaml
ingress:
  className: nginx
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
  tlsSecret:  my-tls-secret
```

### Security context configuration

Workloads of the individual components in the chart can share the same configuration using the `podSecurityContext` base section. Any value can be configured here to apply them globally, but can be overridden on a per component basis.

```yaml
containersSecurityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  seccompProfile:
    type: RuntimeDefault
```

### Tolerations and Topology Spread Constraints configuration

Workloads of the individual components in the chart can share the same configuration using the `tolerations` and `topologySpreadConstraints` base section. Any value can be configured here to apply them globally, but can be overridden on a per component basis.

```yaml
tolerations:
- key: "key"
  operator: "Equal"
  value: "value"
  effect: "NoSchedule"

topologySpreadConstraints:
- topologyKey: "kubernetes.io/hostname"
  maxSkew: 2
  whenUnsatisfiable: PreferNoSchedule
```

## Synapse

A minimal set of values to bring up Synapse would be
```yaml
serverName: ess.localhost

synapse:
  ingress:
    host: synapse.ess.localhost

  registrationSharedSecret:
    value: A Secret
  macaroon:
    value: Another Secret
  signingKey:
    value: ed25519 0 bNQOzBUDszff7Ax81z6w0uZ1IPWoxYaazT7emaZEfpw

  postgres:
    host: ess-postgres
    user: synapse_user
    database: synapse
    password:
      secret: ess-postgres
      secretKey: password
```

The 4 credentials shown can either be provided inline in the values with `value` or if you
have an existing `Secret` in the cluster in the same namespace you can use `secret` and
`secretKey` to reference it. Signing keys 

`serverName` is the value that is embedded in user IDs, room IDs, etc. It can't be changed
after the initial deployment and so should be chosen carefully. If federating
`https://<serverName>/.well-known/matrix/server` must be available and contain the
location of this Synapse. Future versions of this chart will do this for you.

Additional Synapse configuration can be provided inline in the values as a string with
```yaml
synapse:
  additional:
    ## Either reference config to inject by:
    1-custom-config:
      config: |
        admin_contact: "mailto:admin@example.com"
    ## Either reference an existing `Secret` by:
    2-custom-config:
      configSecret: custom-synapse-config
      configSecretKey: shared.yaml
```

Full details on available configuration options can be found at
https://element-hq.github.io/synapse/latest/usage/configuration/config_documentation.html

Synapse is enabled for deployment by default can be disabled with the following values
```yaml
synapse:
  enabled: false
```

Other settings for Synapse can be seen under the `synapse` section of
`helm show values` for this chart.

## Element Web

A minimal set of values to bring up Element Web would be
```yaml
elementWeb:
  ingress:
    host: element.ess.localhost
```

If `serverName` is set this will be configured in Element Web. If Synapse is enabled
this will be configured in Element Web as well.

Additional Element Web configuration can be provided as arbitrary sub-properties with
```yaml
elementWeb:
  additional:
    default_theme: dark
    default_server_config:
      m.identity_server:
        base_url: https://vector.im
```
Full details on available configuration options can be found at
https://github.com/element-hq/element-web/blob/develop/docs/config.md.

Element Web is enabled for deployment by default can be disabled with the following values
```yaml
elementWeb:
  enabled: false
```

Other settings for Element Web can be seen under the `elementWeb` section of
`helm show values` for this chart.

## Well Known Delegation

A minimal set of values to bring up Well Known Delegation would be
```yaml
servername: ess.localhost
```

If Synapse is enabled, its ingress host will be configured in Well Known Delegation config file as well.

Additional Well Known Delegation configuration can be provided as arbitrary sub-properties with
```yaml
wellKnownDelegation:
  additional:
    server: |
      {"some": "config"}
    client: |
      {"some": "config"}
    element: |
      {"some": "config"}
```

Well Known Delegation is enabled for deployment by default can be disabled with the following values
```yaml
wellKnownDelegation:
  enabled: false
```

Other settings for Well Known Delegation can be seen under the `wellKnownDelegation` section of
`helm show values` for this chart.
