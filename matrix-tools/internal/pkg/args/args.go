// Copyright 2025 New Vector Ltd
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

package args

import (
	"fmt"
	"os"
	"strings"
)

type Options struct {
	Files   []string
	Output  string
	Address string
}

func ParseArgs(args []string) (*Options, error) {
	var options Options

	if len(args) < 2 || args[1] != "--render-config" {
		fmt.Println("Usage: go run main.go --render-config <file1> [<file2>, <...>] --output <file> [--tcpwait <server> <port>]")
		os.Exit(1)
	}

	for i := 1; i < len(args); i++ {
		if args[i] == "--tcpwait" && i+1 < len(args) {
			options.Address = args[i+1]
			i++
		} else if args[i] == "--output" && i+1 < len(args) {
			options.Output = args[i+1]
			i++
		} else if args[i] == "--render-config" && i+1 < len(args) {
			for j := i + 1; j < len(args); j++ {
				options.Files = append(options.Files, args[j])
				if j+1 < len(args) && strings.HasPrefix(args[j+1], "--") {
					i = j
					break
				}
			}
		} else if strings.HasPrefix(args[i], "--") {
			return &Options{}, fmt.Errorf("unknown flag")
		}
	}
	if options.Output == "" {
		return &options, fmt.Errorf("missing --output argument\n")
	}
	if len(options.Files) < 1 {
		return &options, fmt.Errorf("missing --render-config argument\n")
	}
	return &options, nil
}
