# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

# A map file that is used in haproxy config to map from matrix paths to the
# named backend. The format is: path_regexp backend_name

{{- if hasKey .Values.workers "client-reader" }}

# Client API requests (apart from createRoom which is eventCreator)
^/_matrix/client/(api/v1|r0|v3|unstable)/publicRooms$               client_reader
^/_matrix/client/(api/v1|r0|v3|unstable)/rooms/.*/joined_members$   client_reader
^/_matrix/client/(api/v1|r0|v3|unstable)/rooms/.*/context/.*$       client_reader
^/_matrix/client/(api/v1|r0|v3|unstable)/rooms/.*/members$          client_reader
# We can't guarantee this goes to the same instance.
# But it is a federated request. A misconfiguration
# seems to generate a really small volume of bad requests on matrix.org.
# Federation is generally limited in environment deployed via the operator. for ease of maintenance
# we are routing it to the client-reader pool as the other requests.
# Should be fixed by : https://github.com/matrix-org/synapse/issues/11717
^/_matrix/client/(api/v1|r0|v3|unstable)/rooms/.*/messages$         client_reader
^/_matrix/client/(api/v1|r0|v3|unstable)/rooms/.*/state$            client_reader
^/_matrix/client/v1/rooms/.*/hierarchy$                             client_reader
^/_matrix/client/(v1|unstable)/rooms/.*/relations/                  client_reader
^/_matrix/client/v1/rooms/.*/threads$                               client_reader
^/_matrix/client/unstable/im.nheko.summary/rooms/.*/summary$        client_reader
^/_matrix/client/(r0|v3|unstable)/account/3pid$                     client_reader
^/_matrix/client/(r0|v3|unstable)/account/whoami$                   client_reader
^/_matrix/client/(r0|v3|unstable)/devices$                          client_reader
^/_matrix/client/versions$                                          client_reader
^/_matrix/client/(api/v1|r0|v3|unstable)/voip/turnServer$           client_reader
^/_matrix/client/(api/v1|r0|v3|unstable)/rooms/.*/event/            client_reader
^/_matrix/client/(api/v1|r0|v3|unstable)/joined_rooms$              client_reader
^/_matrix/client/v1/rooms/.*/timestamp_to_event$                    client_reader
^/_matrix/client/(api/v1|r0|v3|unstable/.*)/rooms/.*/aliases        client_reader
^/_matrix/client/(api/v1|r0|v3|unstable)/search$                    client_reader
^/_matrix/client/(r0|v3|unstable)/user/.*/filter(/|$)               client_reader
^/_matrix/client/(api/v1|r0|v3|unstable)/directory/room/.*$         client_reader
^/_matrix/client/(r0|v3|unstable)/capabilities$                     client_reader
^/_matrix/client/(r0|v3|unstable)/notifications$                    client_reader

# Registration/login requests
^/_matrix/client/(api/v1|r0|v3|unstable)/login$                     client_reader
^/_matrix/client/(r0|v3|unstable)/register$                         client_reader
^/_matrix/client/(r0|v3|unstable)/register/available$               client_reader
^/_matrix/client/v1/register/m.login.registration_token/validity$   client_reader
^/_matrix/client/(r0|v3|unstable)/password_policy$                  client_reader

# Encryption requests
^/_matrix/client/(r0|v3|unstable)/keys/query$                       client_reader
^/_matrix/client/(r0|v3|unstable)/keys/changes$                     client_reader

# On m.org /keys/claim & /room_keys go to the encryption worker but the above 2 go to client-reader
# https://github.com/matrix-org/synapse/pull/11599 makes no claim that there are efficency
# reasons to go to the encryption worker, so put them on the client-reader
^/_matrix/client/(r0|v3|unstable)/keys/claim$                       client_reader
^/_matrix/client/(r0|v3|unstable)/room_keys/                        client_reader
^/_matrix/client/(r0|v3|unstable)/keys/upload                       client_reader
{{- end }}

{{- if hasKey .Values.workers "encryption" }}

^/_matrix/client/(r0|v3|unstable)/sendToDevice/  encryption
{{- end }}

{{- if hasKey .Values.workers "event-creator" }}

^/_matrix/client/(api/v1|r0|v3|unstable)/rooms/.*/redact                                event-creator
# v2_alpha is never used anymore, but there are still tracks of this endpoint in the source code
^/_matrix/client/(api/v1|r0|v3|unstable)/rooms/.*/send                                  event-creator
^/_matrix/client/(api/v1|r0|v3|unstable)/rooms/.*/state/                                event-creator
^/_matrix/client/(api/v1|r0|v3|unstable)/rooms/.*/(join|invite|leave|ban|unban|kick)$   event-creator
^/_matrix/client/(api/v1|r0|v3|unstable)/join/                                          event-creator
^/_matrix/client/(api/v1|r0|v3|unstable)/knock/                                         event-creator
^/_matrix/client/(api/v1|r0|v3|unstable)/profile/                                       event-creator
^/_matrix/client/(api/v1|r0|v3|unstable)/createRoom$                                    event-creator
{{- end }}
{{- if hasKey .Values.workers "federation-inbound" }}
# Inbound federation transaction request
^/_matrix/federation/v1/send/  federation-inbound
{{- end }}

{{- if hasKey .Values.workers "federation-reader" }}
# All Federation REST requests for generic_worker
^/_matrix/federation/v1/event/                        federation-reader
^/_matrix/federation/v1/state/                        federation-reader
^/_matrix/federation/v1/state_ids/                    federation-reader
^/_matrix/federation/v1/backfill/                     federation-reader
^/_matrix/federation/v1/get_missing_events/           federation-reader
^/_matrix/federation/v1/publicRooms                   federation-reader
^/_matrix/federation/v1/query/                        federation-reader
^/_matrix/federation/v1/make_join/                    federation-reader
^/_matrix/federation/v1/make_leave/                   federation-reader
^/_matrix/federation/(v1|v2)/send_join/               federation-reader
^/_matrix/federation/(v1|v2)/send_leave/              federation-reader
^/_matrix/federation/v1/make_knock/                   federation-reader
^/_matrix/federation/v1/send_knock/                   federation-reader
^/_matrix/federation/(v1|v2)/invite/                  federation-reader

# Not in public docs but on matrix.org
^/_matrix/federation/v1/query_auth/                   federation-reader
^/_matrix/federation/v1/event_auth/                   federation-reader
^/_matrix/federation/v1/timestamp_to_event/           federation-reader
^/_matrix/federation/v1/exchange_third_party_invite/  federation-reader
^/_matrix/federation/v1/user/devices/                 federation-reader
^/_matrix/key/v2/query                                federation-reader
^/_matrix/federation/v1/hierarchy/                    federation-reader
{{- end }}

{{- if or (hasKey .Values.workers "initial-synchrotron") (hasKey .Values.workers "synchrotron") }}

^/_matrix/client/(api/v1|r0|v3)/initialSync$              {{ ternary "initial-" "" (hasKey .Values.workers "initial-synchrotron") }}synchrotron
^/_matrix/client/(api/v1|r0|v3)/rooms/[^/]+/initialSync$  {{ ternary "initial-" "" (hasKey .Values.workers "initial-synchrotron") }}synchrotron
{{- end }}

{{- if hasKey .Values.workers "media-repository" }}

^/_matrix/media/                          media-repository
^/_matrix/client/v1/media/                media-repository
^/_matrix/federation/v1/media/            media-repository
^/_synapse/admin/v1/purge_media_cache$    media-repository
^/_synapse/admin/v1/room/.*/media.*       media-repository
^/_synapse/admin/v1/user/.*/media.*$      media-repository
^/_synapse/admin/v1/media/.*$             media-repository
^/_synapse/admin/v1/quarantine_media/.*$  media-repository
^/_synapse/admin/v1/users/.*/media$       media-repository
{{- end }}

{{- if hasKey .Values.workers "presence-writer" }}

^/_matrix/client/(api/v1|r0|v3|unstable)/presence/  presence-writer
{{- end }}

{{- if hasKey .Values.workers "receipts-account" }}

^/_matrix/client/(r0|v3|unstable)/.*/tags                receipts-account
^/_matrix/client/(r0|v3|unstable)/.*/account_data        receipts-account
^/_matrix/client/(r0|v3|unstable)/rooms/.*/receipt       receipts-account
^/_matrix/client/(r0|v3|unstable)/rooms/.*/read_markers  receipts-account
{{- end }}

{{- if hasKey .Values.workers "sliding-sync" }}

^_matrix/client/unstable/org.matrix.simplified_msc3575/.*  sliding-sync
{{- end }}

{{- if hasKey .Values.workers "sso-login" }}

^/_matrix/client/(api/v1|r0|v3|unstable)/login/sso/redirect  sso-login
^/_synapse/client/pick_idp$                                  sso-login
^/_synapse/client/pick_username                              sso-login
^/_synapse/client/new_user_consent$                          sso-login
^/_synapse/client/sso_register$                              sso-login
^/_synapse/client/oidc/callback$                             sso-login
^/_synapse/client/saml2/authn_response$                      sso-login
^/_matrix/client/(api/v1|r0|v3|unstable)/login/cas/ticket$   sso-login
{{- end }}

{{- if hasKey .Values.workers "synchrotron" }}

{{/* Update the initial-synchrotron handling in the haproxy.cfg frontend when updating this*/}}
^/_matrix/client/(r0|v3)/sync$           synchrotron
^/_matrix/client/(api/v1|r0|v3)/events$  synchrotron
{{- end }}

{{- if hasKey .Values.workers "typing-persister" }}

^/_matrix/client/(api/v1|r0|v3|unstable)/rooms/.*/typing  typing-persister
{{- end }}

{{- if hasKey .Values.workers "user-dir" }}

^/_matrix/client/(r0|v3|unstable)/user_directory/search$  user-dir
{{- end }}
