<!--
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
-->

# Element Server Suite Community Helm Chart

A Helm Chart to deploy the Element Server Suite (ESS).

**This readme is primarily aimed at developing on the chart. The user readme is at
[charts/matrix-stack/README.md](charts/matrix-stack/README.md)**

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

Changes to the chart templates are directly made to `charts/matrix-stack/templates`.

`charts/matrix-stack/values.yaml` and `charts/matrix-stack/values.schema.json` are generated
files and should not be directly edited. Changes to chart values and the values schema are
made in `charts/matrix-stack/source`. This is then built by running
`scripts/assemble_helm_charts_from_fragments.sh`.

The rationale for this is so that shared values & schema snippets can be shared between
components without copy-pasting. Shared schema snippets can be found at
`charts/matrix-stack/source/common/*.json`. Shared values snippets can be found in
`charts/matrix-stack/source/common/sub_schemas.values.yaml.j2`

The output of `assemble_helm_charts_from_fragments.sh` must be committed to Git or CI fails.
The rationale for this is so that the values file and schema can be easily viewed in
the repo and diffs seen in PRs.

Similarly the version number of the chart can be changed with
`scripts/set_chart_version.sh <version>`. Any changes this makes must be committed to Git
as well.

### Running a test cluster

A test cluster can be constructed with `./scripts/setup_test_cluster.sh`. It will:
* Install an ingress controller
* Bind the ingress controller to port 80 & 443 on localhost outside of the cluster such
  that `http://anything.localhost` or `https://anything.localhost` both work.
* Install `metrics-server` into the cluster
* Install `cert-manager` into the cluster
* Construct a self-signed CA and puts its cert and key in `./.ca`.
  This will be persisted over cluster recreation so you can trust it once and use it repeatedly.
* Construct a set of application namespaces.
  * This defaults to `ess` but can be controlled with the `ESS_NAMESPACES` environment variable
    as a space separated list of namespaces.
  * Within each namespace a wildcard certificate for `*.<namespace>.localhost` and
    `<namespace>.localhost` will be created
  * Within each namespace a Postgres will be available at `ess-postgres`

The test cluster can then be deployed to with
`helm -n <namespace> upgrade -i ess charts/matrix-stack -f charts/matrix-stack/ci/test-cluster-mixin.yaml -f <your values file>`.

The test cluster can be taken down by running `./scripts/destroy_test_cluster.sh`.

### User Values

The chart has a Git ignored folder at `charts/matrix-stack/user_values`. Any `.yaml` placed in
this directory will not be committed to Git.

### Inspecting temlates

Often you wish to see what a template looks like whilst developing. From the chart directory:
`helm template -f ci/<values file> . -s <path to template in question>`

If the rendered template is invalid YAML add `--debug` to see what the issue is. If the is
Helm syntax error `--debug` often gets in the way of seeing the error from Helm.

Values can be tweaked further with `--set property.path=value`.

## Linting

Each of the linters will be run in CI in a way that either covers the relevant part (or all)
of the repository or the chart. Instructions on how to run them locally can be found below.

### chart-testing

Wrapper over `helm lint` with other Helm based linting checks.

From the project root: `ct lint`

This will test the chart with all values files matching
`charts/matrix-stack/ci/*-values.yaml`.

From a sub-chart directory: `ct lint --charts . --validate-maintainers=false`

### checkov

Detects misconfigurations and lack of hardening in the manifests.

From `charts/matrix-stack`: `checkov -d . --framework helm --quiet --var-file ci/<checkov values file>`

Other values files can be used but the values files named `checkov<something>values.yaml` will have
any test suppression annotations required.

### kubeconform

Validates the generated manifests against their schemas.

From `charts/matrix-stack`: `helm template -f ci/<values file> . | kubeconform -summary`

### reuse

Validates that all files have the correct copyright and licensing information.

From the project root: `reuse lint`

### shellcheck

Detects common mistakes in shell scripts.

From the project root: `shellcheck scripts/*.sh`

### Integration tests

Verifies that the deployed workloads behave as expected and integrates well together.

From the project root : `pytest test`

#### Special env variables
- `PYTEST_KEEP_CLUSTER=1` : Do not destroy the cluster at the end of the test run.
You must delete it using `kind delete cluster --name ess-helm` manually before running any other test run.

#### Usage
Use `kind export kubeconfig --name ess-helm` to get access to the cluster.

The tests will use the cluster constructed by `scripts/setup_test_cluster.sh` if that is
running. If the tests use an existing cluster, they won't destroy the cluster afterwards.

## Design

### Component Configuration

The chart focus on application construction, i.e.
* Providing Kubernetes options
* Exposing values to set required and very frequently set application settings
* Exposing values to set arbitrary additional application configuration
* Exposing values to set application configuration that for some reason can't be
  set via a generic arbitrary additional application configuration setting. e.g.
  it is a flag in the 2nd item in a predefined list.

We are not going to expose every single application configuration option.

## Changelog

The chart changelog is built using towncrier. Every PR requires a newsfragment created using : `towncrier create`. The fragment number should match the PR number.

Each newsfragment accepts on type of artifct hub kind changes : `added`, `changed`, `removed`, `fixed`, `security`.

The changelog is built on release time using `towncrier build` in the chart directory. The changelog is also injected into the `Chart.yaml` under the annotation `artifacthub.io/changes`.

## Releasing

### Helm chart

To create a release, just construct a tag with the desired version number.
CI will run a workflow that constructs OCI and tarball artifacts with this version
number. It will then create a draft release. The draft release will have release
notes containing all the PR titles since the last release. Finally the workflow
will then create a version bump the PR; the new version number will increment
only the patch version vs the tag and suffix with `-dev`.

The draft release can then be editted to adjust the release notes before being
published.

The tarball artifact will be attached to the release. The OCI artifact will be
available at `oci://ghrc.io/element-hq/ess-helm:<tag>`

### Matrix tools

To release a new `matrix-tools` image, just construct a tag named `matrix-tools-<version>`
with version being a semver.
CI will run a workflow that constructs OCI and pushes the image to ghcr.io

The image will be available at `oci://ghcr.io/element-hq/ess-helm/matrix-tools:<tag>`
