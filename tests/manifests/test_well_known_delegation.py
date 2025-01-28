# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import json

import pytest


@pytest.mark.parametrize("values_file", ["well-known-minimal-values.yaml"])
@pytest.mark.asyncio_cooperative
async def test_only_additional_if_all_disabled_in_well_known(values, make_templates):
    client_config = {"testclientkey": {"testsubket": "testvalue"}}
    server_config = {"testserverkey": {"testsubket": "testvalue"}}
    element_config = {"testelementkey": {"testsubket": "testvalue"}}
    support_config = {"testsupportkey": {"testsubket": "testvalue"}}
    values["wellKnownDelegation"].setdefault("additional", {})["client"] = json.dumps(client_config)
    values["wellKnownDelegation"].setdefault("additional", {})["server"] = json.dumps(server_config)
    values["wellKnownDelegation"].setdefault("additional", {})["element"] = json.dumps(element_config)
    values["wellKnownDelegation"].setdefault("additional", {})["support"] = json.dumps(support_config)
    for template in await make_templates(values):
        if template["kind"] == "ConfigMap" and template["metadata"]["name"] == "pytest-well-known-haproxy":
            client_from_json = json.loads(template["data"]["client"])
            assert client_from_json == client_config

            server_from_json = json.loads(template["data"]["server"])
            assert server_from_json == server_config

            element_from_json = json.loads(template["data"]["element.json"])
            assert element_from_json == element_config

            support_config_from_json = json.loads(template["data"]["support"])
            assert support_config == support_config_from_json

            break
    else:
        raise AssertionError("Unable to find WellKnownDelegationConfigMap")


@pytest.mark.parametrize("values_file", ["well-known-synapse-values.yaml"])
@pytest.mark.asyncio_cooperative
async def test_synapse_injected_in_server_and_client_well_known(values, make_templates):
    client_config = {"testclientkey": {"testsubket": "testvalue"}}
    server_config = {"testserverkey": {"testsubket": "testvalue"}}
    element_config = {"testelementkey": {"testsubket": "testvalue"}}
    support_config = {"testsupportkey": {"testsubket": "testvalue"}}
    values["wellKnownDelegation"].setdefault("additional", {})["client"] = json.dumps(client_config)
    values["wellKnownDelegation"].setdefault("additional", {})["server"] = json.dumps(server_config)
    values["wellKnownDelegation"].setdefault("additional", {})["element"] = json.dumps(element_config)
    values["wellKnownDelegation"].setdefault("additional", {})["support"] = json.dumps(support_config)

    synapse_federation = {"m.server": "synapse.ess.localhost:443"}
    synapse_base_url = {"m.homeserver": {"base_url": "https://synapse.ess.localhost"}}
    for template in await make_templates(values):
        if template["kind"] == "ConfigMap" and template["metadata"]["name"] == "pytest-well-known-haproxy":
            client_from_json = json.loads(template["data"]["client"])
            assert client_from_json == client_config | synapse_base_url

            server_from_json = json.loads(template["data"]["server"])
            assert server_from_json == server_config | synapse_federation

            element_from_json = json.loads(template["data"]["element.json"])
            assert element_from_json == element_config

            support_from_json = json.loads(template["data"]["support"])
            assert support_from_json == support_config

            break
    else:
        raise AssertionError("Unable to find WellKnownDelegationConfigMap")
