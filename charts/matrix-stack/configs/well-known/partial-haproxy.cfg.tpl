{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- $root := .root -}}
{{- with required "haproxy.cfg.tpl missing context" .context -}}

frontend well-known-in
  bind *:8010

  acl well-known-server path_beg /.well-known/matrix/server
  use_backend well-known-server if well-known-server

  acl well-known-client path_beg /.well-known/matrix/client
  use_backend well-known-client if well-known-client

  acl well-known-element path_beg /.well-known/element/element.json
  use_backend well-known-element if well-known-element

backend well-known-server
  mode http
  http-request return errorfile "/well-known/server"

backend well-known-client
  mode http
  http-request return errorfile "/well-known/client"

backend well-known-element
  mode http
  http-request return errorfile "/well-known/element.json"

{{- end -}}
