// Copyright 2025 New Vector Ltd
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

package secret

import (
	"context"
	"encoding/base64"
	"reflect"
	"testing"

	"github.com/element-hq/ess-helm/matrix-tools/internal/pkg/args"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	testclient "k8s.io/client-go/kubernetes/fake"
)

func TestGenerateSecret(t *testing.T) {
	testCases := []struct {
		name       string
		namespace  string
		secretName string
		secretKey  string
		secretData map[string][]byte
		override   bool
	}{
		{
			name:       "Create a new secret",
			namespace:  "create-secret",
			secretName: "test-secret",
			secretKey:  "key",
			secretData: nil,
			override:   false,
		},
		{
			name:       "Secret exists with data",
			namespace:  "secret-exists",
			secretName: "test-secret",
			secretKey:  "key2",
			secretData: map[string][]byte{"key1": []byte("dmFsdWUx")},
			override:   false,
		},
		{
			name:       "Secret exists and we override key",
			namespace:  "override-key",
			secretName: "test-secret",
			secretKey:  "key2",
			secretData: map[string][]byte{"key2": []byte("dmFsdWUx")},
			override:   true,
		},
		{
			name:       "Secret exists and we don't override key",
			namespace:  "override-key",
			secretName: "test-secret",
			secretKey:  "key2",
			secretData: map[string][]byte{"key2": []byte("dmFsdWUx")},
			override:   false,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			existingSecretValue, valueExistsBeforeGen := tc.secretData[tc.secretKey]
			client := testclient.NewClientset()
			// Create a namespace
			_, err := client.CoreV1().Namespaces().Create(context.Background(), &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: tc.namespace}}, metav1.CreateOptions{})
			if err != nil {
				t.Fatalf("Failed to create namespace: %v", err)
			}
			secretsClient := client.CoreV1().Secrets(tc.namespace)
			// Create a secret with data
			if tc.secretData != nil {
				_, err := secretsClient.Create(context.Background(), &corev1.Secret{ObjectMeta: metav1.ObjectMeta{Name: tc.secretName, Namespace: tc.namespace}, Data: tc.secretData}, metav1.CreateOptions{})
				if err != nil {
					t.Fatalf("Failed to create secret: %v", err)
				}
			}
			err = GenerateSecret(client, tc.namespace, tc.secretName, tc.secretKey, args.Rand32, tc.override)
			if err != nil {
				t.Fatalf("GenerateSecret() error = %v, want nil", err)
			}
			// Check if the secret was created successfully
			secret, err := secretsClient.Get(context.Background(), tc.secretName, metav1.GetOptions{})
			if err != nil {
				t.Fatalf("Failed to get secret: %v", err)
			}

			if value, ok := secret.Data[tc.secretKey]; ok {
				if valueExistsBeforeGen {
					existingSecretValueBytes := []byte(existingSecretValue)
					if tc.override {
						if reflect.DeepEqual(value, existingSecretValueBytes) {
							t.Fatalf("The secret has not been updated with the new value: %s", string(value))
						}
					} else {
						if !reflect.DeepEqual(value, existingSecretValueBytes) {
							t.Fatalf("The secret has been updated with the new value but it should not overwrite: %s", string(value))
						}
					}

				} else if decodedValue, err := base64.StdEncoding.DecodeString(string(value)); err != nil {
					t.Fatalf("Unexpected error while decoding secret data: %v", err)
				} else {
					if len(string(decodedValue)) != 32 {
						t.Fatalf("Unexpected data in secret: %v", decodedValue)
					}
				}
			} else {
				t.Errorf("Expected key to be set in the secret")
			}
		})
	}
}
