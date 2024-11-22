# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

from collections.abc import Awaitable

from lightkube.models.meta_v1 import ObjectMeta
from lightkube.resources.core_v1 import Namespace, Secret

from ..artifacts import CertKey, generate_cert


def namespace(name: str) -> Awaitable[Namespace]:
    return Namespace(metadata=ObjectMeta(name=name))


def kubernetes_docker_secret(name: str, namespace: str, docker_config_json: str) -> Awaitable[Secret]:
    secret = Secret(
        type="kubernetes.io/dockerconfigjson",
        metadata=ObjectMeta(name=name, namespace=namespace, labels={"app.kubernetes.io/managed-by": "pytest"}),
        stringData={".dockerconfigjson": docker_config_json},
    )
    return secret


def kubernetes_tls_secret(name: str, namespace: str, ca: CertKey, dns_names: [str], bundled=False) -> Awaitable[Secret]:
    certificate = generate_cert(ca, dns_names)
    secret = Secret(
        type="kubernetes.io/tls",
        metadata=ObjectMeta(name=name, namespace=namespace, labels={"app.kubernetes.io/managed-by": "pytest"}),
        stringData={
            "tls.crt": certificate.cert_bundle_as_pem() if bundled else certificate.cert_as_pem(),
            "tls.key": certificate.key_as_pem(),
        },
    )
    return secret
