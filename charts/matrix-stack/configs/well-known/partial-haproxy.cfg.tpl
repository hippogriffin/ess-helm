{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- $root := .root -}}
{{- with required "haproxy.cfg.tpl missing context" .context -}}

frontend well-known-in
  bind *:8007
  acl well-known path_beg /.well-known/matrix/server
  use_backend well-known if well-known-server
  acl well-known path_beg /.well-known/matrix/client
  use_backend well-known if well-known-client
  acl well-known path_beg /.well-known/matrix/element.json
  use_backend well-known if well-known-element

backend well-known-server
  mode http
  http-request return status 200 content-type "text/json" file "/well-known/server"
backend well-known-client
  mode http
  http-request return status 200 content-type "text/json" file "/well-known/client"
backend well-known-element
  mode http
  http-request return status 200 content-type "text/json" file "/well-known/element.json"

{{- end -}}