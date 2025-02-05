// Copyright 2025 New Vector Ltd
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// internal/pkg/secret/secret.go

package secret

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"crypto/ecdsa"
	"crypto/elliptic"

	"github.com/dustinxie/ecc"
)


func marshallKey(key any) ([]byte, error) {
	keyBytes, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		return nil, err
	}

	return keyBytes, nil
}


func generateRSA() ([]byte, error) {
	rsaPrivateKey, err := rsa.GenerateKey(rand.Reader, 4096)
	if err != nil {
		return nil, err
	}
	return marshallKey(rsaPrivateKey)
}


func generateEcdsaPrime256v1() ([]byte, error) {
	ecdsaPrivateKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return nil, err
	}
	return marshallKey(ecdsaPrivateKey)
}


func generateEcdsaSecp256k1() ([]byte, error) {
	ecdsaPrivateKey, err := ecdsa.GenerateKey(ecc.P256k1(), rand.Reader)
	if err != nil {
		return nil, err
	}
	return marshallKey(ecdsaPrivateKey)
}

func generateEcdsaSecp384r1() ([]byte, error) {
	ecdsaPrivateKey, err := ecdsa.GenerateKey(ecc.P384(), rand.Reader)
	if err != nil {
		return nil, err
	}
	return marshallKey(ecdsaPrivateKey)
}
