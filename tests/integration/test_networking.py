# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import asyncio

import pytest
from lightkube import AsyncClient
from lightkube import operators as op
from lightkube.resources.core_v1 import Endpoints, Pod, Service

from .fixtures.data import ESSData


@pytest.mark.asyncio_cooperative
async def test_services_have_matching_labels(
    matrix_stack,
    kube_client: AsyncClient,
    generated_data: ESSData,
):
    ignored_labels = [
        "app.kubernetes.io/managed-by",
        "k8s.element.io/service-type",
        "k8s.element.io/synapse-instance",
        "replica",
    ]

    async for service in kube_client.list(
        Service, namespace=generated_data.ess_namespace, labels={"app.kubernetes.io/part-of": op.in_(["matrix-stack"])}
    ):
        assert service.spec is not None, f"Encountered a service without spec : {service}"
        label_selectors = {label: value for label, value in service.spec.selector.items()}

        async for pod in kube_client.list(Pod, namespace=generated_data.ess_namespace, labels=label_selectors):
            assert service.metadata is not None, f"Encountered a service without metadata : {service}"
            assert pod.metadata is not None, f"Encountered a pod without metadata : {pod}"
            for label, value in service.metadata.labels.items():
                if label in ["k8s.element.io/owner-name", "k8s.element.io/owner-group-kind"]:
                    assert label not in pod.metadata.labels
                    continue
                elif label in ignored_labels:
                    continue
                assert label in pod.metadata.labels
                assert value.startswith(pod.metadata.labels[label])


@pytest.mark.asyncio_cooperative
async def test_services_have_endpoints(
    cluster,
    matrix_stack,
    kube_client: AsyncClient,
    generated_data: ESSData,
):
    async for service in kube_client.list(
        Service, namespace=generated_data.ess_namespace, labels={"app.kubernetes.io/part-of": op.in_(["matrix-stack"])}
    ):
        assert service.metadata is not None, f"Encountered a service without metadata : {service}"
        await asyncio.to_thread(
            cluster.wait,
            name=f"endpoints/{service.metadata.name}",
            namespace=generated_data.ess_namespace,
            waitfor="jsonpath='{.subsets[].addresses}'",
        )
        endpoint = await kube_client.get(Endpoints, name=service.metadata.name, namespace=generated_data.ess_namespace)
        assert endpoint.metadata is not None, f"Encountered an endpoint without metadata : {endpoint}"
        assert endpoint.subsets, f"Endpoint {endpoint.metadata.name} has no subsets"

        ports = []
        for subset in endpoint.subsets:
            assert subset.addresses, f"Endpoint {endpoint.metadata.name} has no addresses"
            assert not subset.notReadyAddresses, f"Endpoint {endpoint.metadata.name} has notReadyAddresses"
            assert subset.ports, f"Endpoint {endpoint.metadata.name} has no ports"
            ports += subset.ports

        port_names = [port.name for port in ports if port.name]
        port_numbers = [port.port for port in ports]
        assert service.spec is not None, f"Service {service.metadata.name} has no spec"
        for port in service.spec.ports:
            if port.name:
                assert port.name in port_names
            else:
                assert port.port in port_numbers
