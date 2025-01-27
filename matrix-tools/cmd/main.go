// Copyright 2025 New Vector Ltd
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

package main

import (
	"fmt"
	"os"
	"strings"

	"github.com/element-hq/ess-helm/matrix-tools/internal/pkg/renderer"
	"github.com/element-hq/ess-helm/matrix-tools/internal/pkg/tcpwait"
	"gopkg.in/yaml.v3"
)

type Options struct {
	Files   []string
	Output  string
	Address string
}

func ParseArgs(args []string) (*Options, error) {
	var options Options
	var files []string

	if len(args) < 2 || args[1] != "--render-config" {
		fmt.Println("Usage: go run main.go --render-config <file1> [<file2>, <...>] --output <file> [--tcpwait <server> <port>]")
		os.Exit(1)
	}

	for i := 1; i < len(args); i++ {
		if args[i] == "--tcpwait" && i+2 < len(args) {
			options.Address = args[i+1]
			i++
		} else if args[i] == "--output" && i+1 < len(args) {
			options.Output = args[i+1]
			i++
		} else if args[i] == "--render-config" && i+1 < len(args) {
			for j := i; j < len(args); j++ {
				if strings.HasPrefix(args[j], "--") {
					i = j + 1
					break
				}
				options.Files = append(files, args[j])
			}
		} else if strings.HasPrefix(args[i], "--") {
			fmt.Printf("%s: unknown flag\n", args[i])
			return &Options{}, fmt.Errorf("unknown flag")

		}
	}
	return &options, nil
}

func main() {
	options, err := ParseArgs(os.Args)
	if err != nil {
		fmt.Println(err)
		return
	}
	result, err := renderer.RenderConfig(options.Files)
	if err != nil {
		fmt.Println("Error:", err)
		os.Exit(1)
	}

	if options.Address != "" {
		tcpwait.WaitForTCP(options.Address)
	}

	outputYAML, _ := yaml.Marshal(result)
	err = os.WriteFile(options.Output, outputYAML, 0644)
	if err != nil {
		fmt.Println("Error writing to file:", err)
		os.Exit(1)
	}
}
