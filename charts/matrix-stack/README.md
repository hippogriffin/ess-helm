<!--
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
-->

# Matrix Stack Chart

This Helm chart deploys a coherent Matrix Stack. It currently includes the following components
* [Synapse](https://github.com/element-hq/synapse) as a Matrix homeserver
* [Element Web](https://github.com/element-hq/element-web) as a Matrix client
* [Matrix Authentication Service](https://github.com/element-hq/matrix-authentication-service) for authentication on the Matrix homeserver
* [PostgreSQL](https://hub.docker.com/_/postgres) as a simple internal DB
* Well Known Delegation file hosting to enable Matrix client and Matrix federation discovery of this deployment

## Requirements

The chart requires:
* An ingress controller installed in the cluster already
* TLS certificates for Ingresses
* If using Synapse, the ability to create `PersistentVolumeClaims` to store media

### Recommandations

The chart comes with an internal postgres database which will be automatically setup by default.

Although we are trying to update the database reliably with the chart, it is provided as-is without warranty of any kind.

On a production deployment, we advise you to host your own Postgres instance, and configure it accordingly
for each of the following the components, if you enable them:
- Synapse under `synapse.postgres`
- Matrix Authentication Service under `matrixAuthenticationService.postgres`

## Common

The components deployed in the chart can share some configuration. You'll find below the relevant base sections of values.yaml that you can configure at the top of the chart.

### Labels

The components deployed in the chart can share labels using the `labels` base section. Configure any value here to set global labels, which will then be applied to each component's labels. You can override them on a per component basis. You can unset a common label on a per-component basis by setting it to `null`.

```yaml
labels:
  my-deployment: ess-deployment
```

### Ingress Configuration

Ingresses of the individual components in the chart can share the same configuration using the `ingress` base section.
Configure any `annotations`, `className`, `tlsSecret` here to set them globally, which will then apply them to each component ingresses. You can override them on a per component basis. You can unset a common ingress annotation on a per-component basis by setting it to `null`.

```yaml
ingress:
  className: nginx
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
  tlsSecret:  my-tls-secret
```

### Tolerations and Topology Spread Constraints configuration

Workloads of the individual components in the chart can share the same configuration using the `tolerations` and `topologySpreadConstraints` base section.
 - Configure **Tolerations** here to apply them globally. They are appended to the per component tolerations.
 - Configure **Topology Spread Constraints** here to apply them globally.You can override them on a per component basis. Please note that setting `topologySpreadConstraints`
   - Automatically sets `labelSelector.matchLabels` based on `app.kubernetes.io/instance` if one isn't specified.
   - Automatically sets `matchLabelKeys` based on `pod-template-hash` for `Deployments` if one isn't specified

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
```

Credentials are generated if possible. Alternatively they can either be provided inline
in the values with `value` or if you have an existing `Secret` in the cluster in the
same namespace you can use `secret` and`secretKey` to reference it.

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

## Matrix Authentication Service

A minimal set of values to bring up Matrix Authentication Service (MAS) would be
```yaml

matrixAuthenticationService:
  ingress:
    host: mas.ess.localhost
```

Additional MAS configuration can be provided inline in the values as a string with
```yaml
matrixAuthenticationService:
  additional:
    ## Either reference config to inject by:
    1-custom-config:
      config: |
        admin_contact: "mailto:admin@example.com"
    ## Either reference an existing `Secret` by:
    2-custom-config:
      configSecret: custom-mas-config
      configSecretKey: shared.yaml
```

Full details on available configuration options can be found at
https://element-hq.github.io/matrix-authentication-service/

MAS is enabled for deployment by default can be disabled with the following values
```yaml
matrixAuthenticationService:
  enabled: false
```

Other settings for MAS can be seen under the `matrixAuthenticationService` section of
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
serverName: ess.localhost
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
