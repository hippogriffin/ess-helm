# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import secrets
from dataclasses import dataclass

from lightkube.models.meta_v1 import ObjectMeta
from lightkube.resources.core_v1 import Secret
from pyhelm3 import Client


@dataclass
class PostgresServer:
    name: str
    user: str
    database: str
    password: str
    namespace: str

    def properties(self):
        return {
            "host": f"{self.name}-postgresql.{self.namespace}",
            "user": self.user,
            "database": self.database,
            "sslMode": "disable",
        }

    async def setup(self, helm_client: Client, kube_client):
        await kube_client.create(
            Secret(
                metadata=ObjectMeta(
                    name=f"{self.name}-postgres-db",
                    namespace=self.namespace,
                    labels={"app.kubernetes.io/managed-by": "pytest"},
                ),
                stringData={"adminPassword": secrets.token_urlsafe(36), "password": self.password},
            )
        )
        chart = await helm_client.get_chart("postgresql", repo="https://charts.bitnami.com/bitnami")

        # Install or upgrade a release
        await helm_client.install_or_upgrade_release(
            self.name,
            chart,
            {
                "commonLabels": {
                    "app.kubernetes.io/managed-by": "pytest",
                },
                "auth": {
                    "existingSecret": "{{ .Release.Name }}-postgres-db",
                    "username": self.user,
                    "database": self.database,
                    "secretKeys": {
                        "adminPasswordKey": "adminPassword",
                        "userPasswordKey": "password",
                    },
                },
                "primary": {
                    "extraPodSpec": {
                        "tolerations": [
                            {
                                "key": "context",
                                "operator": "Equal",
                                "value": "pytest",
                                "effect": "NoSchedule",
                            }
                        ]
                    },
                    "initdb": {"args": "--locale=C --encoding=UTF8"},
                },
            },
            namespace=self.namespace,
            create_namespace=False,
            atomic=True,
            wait=True,
        )
