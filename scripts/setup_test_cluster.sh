#!/usr/bin/env bash
# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

set -e

kind_cluster_name="ess-helm"
kind_context_name="kind-$kind_cluster_name"

ca_folder="$(git rev-parse --show-toplevel)/.ca"
mkdir -p "$ca_folder"

docker stop "${kind_cluster_name}-registry" || true
docker rm "${kind_cluster_name}-registry" || true

if kind get clusters | grep "$kind_cluster_name"; then
  echo "Cluster '$kind_cluster_name' is already provisioned by Kind"
else
  echo "Creating new Kind cluster '$kind_cluster_name'"
  cat << EOF | kind create cluster --name "$kind_cluster_name" --config -
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |-
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5000"]
      endpoint = ["http://${kind_cluster_name}-registry:5000"]
EOF
fi

network=$(docker inspect $kind_cluster_name-control-plane | jq '.[0].NetworkSettings.Networks | keys | .[0]' -r)
docker run \
    -d --restart=always -p "127.0.0.1:5000:5000" --network "$network" --name "${kind_cluster_name}-registry" \
    registry:2

kubectl --context $kind_context_name create namespace ess 2>/dev/null || true

helm --kube-context $kind_context_name upgrade -i ingress-nginx --repo https://kubernetes.github.io/ingress-nginx ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --hide-notes \
  --set controller.ingressClassResource.default=true \
  --set controller.config.hsts=false \
  --set controller.hostPort.enabled=true \
  --set controller.service.enabled=false

helm --kube-context $kind_context_name upgrade -i cert-manager --repo https://charts.jetstack.io cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --hide-notes \
  --set crds.enabled=true

# Create a new CA certificate
if [[ ! -f "$ca_folder"/ca.crt || ! -f "$ca_folder"/ca.pem ]]; then
  cat <<EOF | kubectl --context $kind_context_name apply -f -
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ess-ca
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ess-ca
  namespace: cert-manager
spec:
  isCA: true
  commonName: ess-ca
  secretName: ess-ca
  # 10 years
  duration: 87660h0m0s
  privateKey:
    algorithm: RSA
  issuerRef:
    name: ess-ca
    kind: ClusterIssuer
    group: cert-manager.io
---
EOF
  kubectl --context $kind_context_name -n cert-manager wait --for condition=Ready Certificate/ess-ca
else
  kubectl --context $kind_context_name delete ClusterIssuer ess-ca 2>/dev/null || true
  kubectl --context $kind_context_name -n cert-manager delete Certificate ess-ca 2>/dev/null || true
  kubectl --context $kind_context_name -n cert-manager delete Secret ess-ca 2>/dev/null || true
  kubectl --context $kind_context_name -n cert-manager create secret generic ess-ca \
    --type=kubernetes.io/tls \
    --from-file=tls.crt="$ca_folder"/ca.crt \
    --from-file=tls.key="$ca_folder"/ca.pem \
    --from-file=ca.crt="$ca_folder"/ca.crt
fi

cat <<EOF | kubectl --context $kind_context_name apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ess-selfsigned
spec:
  ca:
    secretName: ess-ca
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ess-selfsigned
  namespace: ess
spec:
  commonName: "ess.localhost"
  secretName: ess-selfsigned
  privateKey:
    algorithm: RSA
  issuerRef:
    name: ess-selfsigned
    kind: ClusterIssuer
    group: cert-manager.io
  dnsNames:
  - "ess.localhost"
  - "*.ess.localhost"
EOF

helm --kube-context $kind_context_name upgrade -i postgres oci://registry-1.docker.io/bitnamicharts/postgresql \
  --namespace ess \
  --hide-notes \
  --set fullnameOverride=ess-postgres \
  --set auth.database=synapse \
  --set auth.username=synapse_user \
  --set primary.initdb.args='--locale=C --encoding=UTF8'

if [[ ! -f "$ca_folder"/ca.crt || ! -f "$ca_folder"/ca.pem ]]; then
  kubectl --context $kind_context_name -n cert-manager get secret ess-ca -o jsonpath="{.data['ca\.crt']}" | base64 -d > "$ca_folder"/ca.crt
  kubectl --context $kind_context_name -n cert-manager get secret ess-ca -o jsonpath="{.data['tls\.key']}" | base64 -d > "$ca_folder"/ca.pem
fi
