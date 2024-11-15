<!--
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
-->
# Element Server Suite - Helm Charts

Helm Charts to deploy the Element Server Suite

## Developing

Requirements for development:
* Python 3.11, 3.12 or 3.13
  * [poetry](https://python-poetry.org/)
* [Helm](https://helm.sh/docs/intro/install/)
* [yq](https://github.com/mikefarah/yq)

Optional Tools:
* [chart-testing](https://github.com/helm/chart-testing) for Helm linting
* [kubeconform](https://github.com/yannh/kubeconform) for Kubernetes manifest validation
* [shellcheck](https://www.shellcheck.net/)
* Managed via Poetry and so should be available after `poetry install`
  * [checkov](https://www.checkov.io/)
  * [reuse](https://reuse.software/)

Changes to chart templates are directly made to `chart/<chart>/templates`.

`chart/<chart>/values.yaml` and `chart/<chart>/values.schema.json` are generated files
and should not be directly edited. Changes to chart values and the values schema are
made in `chart/<chart>/source`. This is then built by running
`scripts/construct_helm_charts.sh charts <version>`.

The rationale for this is so that shared values & schema snippets can be shared between
components without copy-pasting. Shared schema snippets can be found at
`chart/matrix-stack/sub_schemas/*.json`. Shared values snippets can be found in
`chart/matrix-stack/sub_schemas/sub_schemas.values.yaml.j2`

The output of `construct_helm_charts.sh` must be committed to Git or CI fails. The rationale
for this is so that the values files and schemas can be easily viewed in the repo and diffs
seen in PRs
