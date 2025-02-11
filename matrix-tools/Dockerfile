# Copyright 2025 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

FROM golang:1.23 AS buildstage

WORKDIR /app
COPY . /app
RUN go mod download
RUN CGO_ENABLED=0 go build -o /app/matrix-tools cmd/main.go
RUN chmod 755 /app/matrix-tools

FROM gcr.io/distroless/static-debian12
# Label this image with the repo and commit that built it, for freshmaking purposes.
ARG GIT_COMMIT=devel
LABEL git_commit=$GIT_COMMIT
LABEL org.opencontainers.image.licenses="AGPL-3.0-only OR LicenseRef-Element-Commercial"
WORKDIR /

COPY --from=buildstage  /app/matrix-tools /
EXPOSE 8443
ENTRYPOINT ["/matrix-tools"]

USER 30000
