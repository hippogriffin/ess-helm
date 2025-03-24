// Copyright 2025 New Vector Ltd
//
// SPDX-License-Identifier: AGPL-3.0-only

package secret

import (
	"crypto/ed25519"
	"encoding/base64"
	"fmt"
	"math/rand"
)

type SigningKey struct {
	Alg     string
	Version int
	Key     []byte
}

func generateSigningKey(version int) (*SigningKey, error) {
	_, priv, err := ed25519.GenerateKey(rand.New(rand.NewSource(0)))
	if err != nil {
		return nil, fmt.Errorf("failed to generate key: %w", err)
	}

	// The priv key is made of 32 bytes of private key, and 32 bytes of public key
	// Synapse only wants the first 32 bytes of the private key
	key := make([]byte, 32)
	copy(key, priv)

	return &SigningKey{
		Alg:     "ed25519",
		Version: version,
		Key:     key,
	}, nil
}

func encodeSigningKeyBase64(key *SigningKey) string {
	return base64.StdEncoding.EncodeToString(key.Key)
}

func generateSynapseSigningKey() (string, error) {
	signingKey, err := generateSigningKey(0)
	if err != nil {
		return "", fmt.Errorf("failed to generate signing key: %w", err)
	}

	return fmt.Sprintf("%s %d %s\n", signingKey.Alg, signingKey.Version, encodeSigningKeyBase64(signingKey)), nil
}
