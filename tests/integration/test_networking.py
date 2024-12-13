# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import pytest
from lightkube import AsyncClient
from lightkube import operators as op
from lightkube.resources.core_v1 import Endpoints, Service

from .fixtures.data import ESSData


@pytest.mark.asyncio_cooperative
async def test_services_have_endpoints(
    matrix_stack,
    kube_client: AsyncClient,
    generated_data: ESSData,
):
    endpoints_by_name = dict[str, Endpoints]()
    async for endpoint in kube_client.list(Endpoints, namespace=generated_data.ess_namespace):
        assert endpoint.metadata is not None, f"Encountered an endpoint without metadata : {endpoint}"
        endpoints_by_name[endpoint.metadata.name] = endpoint
    async for service in kube_client.list(
        Service, namespace=generated_data.ess_namespace, labels={"app.kubernetes.io/part-of": op.in_(["matrix-stack"])}
    ):
        assert service.metadata is not None, f"Encountered a service without metadata : {service}"
        endpoint = endpoints_by_name[service.metadata.name]
        assert endpoint.subsets, f"Endpoint {service.metadata.name} has no subsets"

        ports = []
        for subset in endpoint.subsets:
            assert subset.addresses, f"Endpoint {service.metadata.name} has no addresses"
            assert not subset.notReadyAddresses, f"Endpoint {service.metadata.name} has notReadyAddresses"
            assert subset.ports, f"Endpoint {service.metadata.name} has no ports"
            ports += subset.ports

        port_names = [port.name for port in ports if port.name]
        port_numbers = [port.port for port in ports]
        assert service.spec is not None, f"Service {service.metadata.name} has no spec"
        for port in service.spec.ports:
            if port.name:
                assert port.name in port_names
            else:
                assert port.port in port_numbers
