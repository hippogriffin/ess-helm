<!--
Copyright 2025 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
-->

<!-- towncrier release notes start -->

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
