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
			args:     []string{"cmd", "--render-config"},
			expected: &Options{},
			err:      true,
		},
		{
			name: "Missing --output flag",
			args: []string{"cmd", "--render-config", "file1", "--tcpwait", "server:port"},
			expected: &Options{
				Files:   []string{"file1"},
				Address: "server:port",
			},
			err: true,
		},
		{
			name:     "Invalid flag",
			args:     []string{"cmd", "--render-config", "file1", "--invalidflag"},
			expected: &Options{},
			err:      true,
		},
		{
			name: "Multiple files and --output flag",
			args: []string{"cmd", "--render-config", "file1", "file2", "--output", "outputFile"},
			expected: &Options{
				Files:  []string{"file1", "file2"},
				Output: "outputFile",
			},
			err: false,
		},
		{
			name: "Correct usage",
			args: []string{"cmd", "--render-config", "file1", "file2", "--output", "outputFile", "--tcpwait", "server:port"},
			expected: &Options{
				Files:   []string{"file1", "file2"},
				Output:  "outputFile",
				Address: "server:port",
			},
			err: false,
		},
		{
			name:     "--tcpwait without parameters",
			args:     []string{"cmd", "--render-config", "file1", "--tcpwait"},
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
