// Copyright 2025 New Vector Ltd
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// internal/pkg/secret/secret.go

package secret

import (
	"context"
	"encoding/base64"
	"fmt"

	"math/rand"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
)

func GenerateSecret(client kubernetes.Interface, namespace string, name string, key string, override bool) error {
	ctx := context.Background()

	// Fetch the existing secret
	existingSecret, err := client.CoreV1().Secrets(namespace).Get(ctx, name, metav1.GetOptions{})
	if err != nil {
		return fmt.Errorf("failed to get secret: %w", err)
	}

	// Add or update the key in the data
	if existingSecret.Data == nil {
		existingSecret.Data = make(map[string][]byte)
	}
	if _, ok := existingSecret.Data[key]; !ok || override {
		randomString := generateRandomString(32)
		base64Encoded := base64.StdEncoding.EncodeToString([]byte(randomString))
		existingSecret.Data[key] = []byte(base64Encoded)
		_, err = client.CoreV1().Secrets(namespace).Update(ctx, existingSecret, metav1.UpdateOptions{})
		if err != nil {
			return fmt.Errorf("failed to update secret: %w", err)
		}
	}

	return nil
}

func generateRandomString(size int) string {
	const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	bytes := make([]byte, size)
	for i := range bytes {
		bytes[i] = charset[rand.Intn(len(charset))]
	}
	return string(bytes)
}
