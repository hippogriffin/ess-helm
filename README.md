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

### Inspecting temlates

Often you wish to see what a template looks like whilst developing. From the chart directory:
`helm template -f ci/<values file> . -s <path to template in question>`

If the rendered template is invalid YAML add `--debug` to see what the issue is. If the is
Helm syntax error `--debug` often gets in the way of seeing the error from Helm.

Values can be tweaked further with `--set property.path=value`.

## Linting

Each of the linters will be run in CI in a way that either covers the relevant part (or all)
of the repository or all charts. Instructions on how to run them locally can be found below.

### chart-testing

Wrapper over `helm lint` with other Helm based linting checks.

From the project root: `ct lint`

This will iterate over all charts in `charts/` and test them with all values files matching
`charts/<chart name>/ci/*-values.yaml`.

From a sub-chart directory: `ct lint --charts . --validate-maintainers=false`

### checkov

Detects misconfigurations and lack of hardening in the manifests.

From a sub-chart directory: `checkov -d . --framework helm --quiet --var-file ci/<checkov values file>`

Other values files can be used but the values files named `checkov<something>values.yaml` will have
any test suppression annotations required.

### kubeconform

Validates the generated manifests against their schemas.

From a sub-chart directory: `helm template -f ci/<values file> . | kubeconform -summary`

### reuse

Validates that all files have the correct copyright and licensing information.

From the project root: `reuse lint`

### shellcheck

Detects common mistakes in shell scripts.

From the project root: `shellcheck scripts/*.sh`
