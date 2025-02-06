// Copyright 2025 New Vector Ltd
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

package args

import (
	"reflect"
	"testing"
)

func TestParseArgs(t *testing.T) {
	testCases := []struct {
		name     string
		args     []string
		expected *Options
		err      bool
	}{
		{
			name:     "Invalid number of arguments",
			args:     []string{"cmd", "render-config"},
			expected: &Options{},
			err:      true,
		},
		{
			name: "Missing --output flag",
			args: []string{"cmd", "render-config", "file1"},
			expected: &Options{
				Files: []string{"file1"},
			},
			err: true,
		},
		{
			name:     "Invalid flag",
			args:     []string{"cmd", "render-config", "file1", "-invalidflag"},
			expected: &Options{},
			err:      true,
		},
		{
			name: "Multiple files and --output flag",
			args: []string{"cmd", "render-config", "-output", "outputFile", "file1", "file2"},
			expected: &Options{
				Files:  []string{"file1", "file2"},
				Output: "outputFile",
			},
			err: false,
		},
		{
			name: "Correct usage of render-config",
			args: []string{"cmd", "render-config", "-output", "outputFile", "file1", "file2"},
			expected: &Options{
				Files:  []string{"file1", "file2"},
				Output: "outputFile",
			},
			err: false,
		},
		{
			name: "Correct usage of tcp-wait",
			args: []string{"cmd", "tcpwait", "-address", "address:port"},
			expected: &Options{
				Address: "server:port",
			},
			err: false,
		},
		{
			name: "Correct usage of generate-secrets",
			args: []string{"cmd", "generate-secrets", "-secrets", "secret1:value1:rand32", "-labels", "mykey=myval"},
			expected: &Options{
				GeneratedSecrets: []GeneratedSecret{
					{Name: "secret1", Key: "value1", Type: Rand32},
				},
				SecretLabels: map[string]string{"mykey": "myval"},
			},
			err: false,
		},

		{
			name: "Multiple generated secrets",
			args: []string{"cmd", "generate-secrets", "-secrets", "secret1:value1:rand32,secret2:value2:signingkey"},
			expected: &Options{
				GeneratedSecrets: []GeneratedSecret{
					{Name: "secret1", Key: "value1", Type: Rand32},
					{Name: "secret2", Key: "value2", Type: SigningKey},
				},
			},
			err: false,
		},

		{
			name:     "Invalid secret type",
			args:     []string{"cmd", "generate-secrets", "-secrets", "secret1:value1:unknown"},
			expected: &Options{},
			err:      true,
		},

		{
			name:     "Wrong syntax of generated secret",
			args:     []string{"cmd", "generate-secrets", "-secrets", "value1:rand32"},
			expected: &Options{},
			err:      true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			if options, err := ParseArgs(tc.args); (err != nil) != tc.err && !reflect.DeepEqual(options, tc.expected) {
				t.Errorf("Expected %v, got %v with err: %v", tc.expected, options, err)
			}
		})
	}
}
