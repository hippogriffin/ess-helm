<!--
Copyright 2025 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
-->

<!-- towncrier release notes start -->

# ESS Community Helm Chart 0.6.0 (2025-02-21)

### Added

- Add support to deploy Matrix Authentication Service. (#132)
- Add an init-secrets job that will prepare internal secrets automatically if they are not provided by the user. (#142)
- Synapse: if SigningKey is not provided, it is now automatically generated. (#146)
- Added the ability to generate the registration shared secret if no value or external Secret is configured. (#163)
- Add internal PostgreSQL database. (#172)
- Config ElementWeb automatically for best Matrix Authentication Service integration. (#194)
- Publish the chart on artifact-hub.io. (#213)
- Add a value to automatically configure CertManager on all ingresses. (#217)

### Changed

- Project name is now ESS Community Helm Chart instead of Element Community Helm Chart. (#141)
- Update READMEs to improve the user on-boarding experience. (#167)
- Support arm64 in matrix-tools image. (#170)
- Update Synapse to v1.124.0. (#179)
- Update Element Web to v1.11.92. (#180)
- Refactor synapse pod to be compatible with minimal container images. (#207)
- Upgrade to Matrix Authentication Service 0.14.0. (#209)
- Configure Element Web for location sharing. (#215)
- Configure Element Web to submit RageShakes. (#215)
- Set the LD_PRELOAD environment variable only in containers that run Synapse. (#218)
- ElementWeb "additional" value now expect a json string. (#219)
- HAProxy: Return 429 error code as Matrix Json format. (#220)
- Improve Synapse HTTP request handling when Synapse processes are restarting. (#225)

### Fixed

- Fixed version label on well-known delegation templates. (#143)
- Fixed the HAProxy Service being headless rather than ClusterIP. (#144)
- Fix missing labels on the Pod created by the initSecret Job. (#156)
- Hard-code the org.opencontainers.image.licenses label be accurate. (#168)
- Fix Matrix Authentication Service render-config container was lacking extraEnv. (#199)
- Fix typo in postgresql values documentation. (#206)
- Postgres: Fixed duplicated ports in statefulset. (#208)
- Postgres: Fix an issue where initialization would fail to happen properly. (#221)
- Fix an issue where HAProxy would be ready despite not having any backend ready to answer. (#224)

### Internal

- Add tests that all manifests have expected labels. (#143)
- Add test that all StatefulSets have headless Services associated with them. (#144)
- Dev dependency updates, include Jinja security. (#145)
- Add gotestfmt in golang CI tests. (#147)
- Pytest: Build matrix-tools in test fixtures. (#148)
- Disable initSecrets in pytests which do not need it. (#149)
- Simplify checkov and kubeconform checks in CI. (#150)
- Use a dynamic Helm release name in the manifest tests. (#151)
- Fix manifest tests issues with shared components, specifically initSecrets. (#152)
- Only build matrix-tools image when necessary. (#153)
- MAS: Make sure legacy auth paths point to MAS service. (#154)
- Add a manifest tests to check pullSecrets list content. (#155)
- Support synthesising Secrets for external and generated Secrets. (#156)
- Use a helper to generate synapse matrix-tools env var. (#157)
- For components with Secrets, always test generated, Helm inlined and external Secrets. (#159)
- Assemble the CI values files from fragments to reduce c/p'ing and make it easy to see the purpose of some values. (#159)
- Reduce retries on HTTP Post/Get in integration tests. (#161)
- Fix local builds of matrix-tools not being available to pytest. (#162)
- Dont print failed yaml with matrix-tools without `DEBUG_RENDERING` enabled. (#164)
- Minor fix in secrets consistency manifest test when a list contains strings. (#165)
- Integration tests: Enhance handling of ingresses readiness. (#166)
- Setup dependabot to manage GHA, go.mod and Poetry deps. (#169)
- matrix-tools: Internal commands handling refactoring. (#171)
- Fix GitHub Actions dependabot config. (#178)
- Sort the keys in values files assembled from fragments. (#186)
- CI values: Do not define `initSecrets` `postgres` in tests, their behaviour depends on other components presence. (#188)
- CI values files: Dont nullify secret/secretKey. (#189)
- Tests: verify mounts and & configs consistency. (#192)
- Better handling of chart values inconsistencies and test it in CI. (#193)
- Matrix-Tools CI: Move Write permissions to push job. (#202)
- Move CI to public github runners. (#204)
- CI: Fix potential security injection. (#205)
- Improve Synapse values files fragments. (#211)
- Fix CI not detecting issues introduced by PRs. (#212)
- Tests: Improve endpoints status verifications. (#226)


# ESS Community Helm Chart 0.5.0 (2025-01-30)

### Added

- Add a matrix-tools image to handle dynamic config build and other chart features. (#131)
- Add support for .well-known/matrix/support in Well Known Delegation. (#133)
- Add the possibility to quote substituted env variable from synapse config. (#137)

### Internal

- Remove towncrier newsfragments after release. (#130)
- Correct SHA used in dev builds to match the commit sha. (#134)
- Make sure matrix-tools is part of ess-helm namespace. (#135)


# ESS Community Helm Chart 0.4.1 (2025-01-23)

### Added

- Add changelog to releases. (#118)
- Document the behaviour common sections of the values file in the README. (#126)

### Fixed

- Fix an issue where the secret key was wrong when using synapse.postgres.value. (#119)
- Fixed an issue with changelogs generation. (#121)

### Internal

- Enhance tests to ensure that secrets mounted in configmaps point to existing mounted secret keys. (#120)
- Tests: Ensure volumes mounts point to existing volumes names. (#122)
- CI: improve licensing checks. (#123)
- Tests: Verify that we can find secrets in env variables. (#124)
- Add internal towncrier change category. (#127)
