{{- /*
Copyright 2024 New Vector Ltd

SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
*/ -}}

{{- $root := .root -}}
{{- with required "haproxy.cfg.tpl missing context" .context -}}

frontend well-known-in
  bind *:8010

  acl well-known path /.well-known/matrix/server
  acl well-known path /.well-known/matrix/client
  acl well-known path /.well-known/element/element.json

  use_backend well-known-static if well-known

backend well-known-static
  mode http

  http-after-response set-header X-Frame-Options SAMEORIGIN
  http-after-response set-header X-Content-Type-Options nosniff
  http-after-response set-header X-XSS-Protection "1; mode=block"
  http-after-response set-header Content-Security-Policy "frame-ancestors 'self'"
  http-after-response set-header X-Robots-Tag "noindex, nofollow, noarchive, noimageindex"

  http-after-response set-header Access-Control-Allow-Origin *
  http-after-response set-header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
  http-after-response set-header Access-Control-Allow-Headers "X-Requested-With, Content-Type, Authorization"

  http-request return status 200 content-type "application/json" file "/well-known/server" if { path /.well-known/matrix/server }
  http-request return status 200 content-type "application/json" file "/well-known/client" if { path /.well-known/matrix/client }
  http-request return status 200 content-type "application/json" file "/well-known/element.json" if { path /.well-known/element/element.json }

{{- end -}}
