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

func main() {
	if len(os.Args) < 2 || os.Args[1] != "--render-config" {
		fmt.Println("Usage: go run main.go --render-config <file1> [<file2>, <...>] --output <file> [--tcpwait <server> <port>]")
		os.Exit(1)
	}

	var files []string
	var output string
	var server, port string

	for i := 1; i < len(os.Args); i++ {
		if os.Args[i] == "--tcpwait" && i+2 < len(os.Args) {
			server = os.Args[i+1]
			port = os.Args[i+2]
			i += 2
		} else if os.Args[i] == "--output" && i+1 < len(os.Args) {
			output = os.Args[i+1]
			i++
		} else if os.Args[i] == "--render-config" && i+1 < len(os.Args) {
			for j := i; j < len(os.Args); j++ {
				if strings.HasPrefix(os.Args[j], "--") {
					i = j + 1
					break
				}
				files = append(files, os.Args[j])
			}
		} else if strings.HasPrefix(os.Args[i], "--") {
			fmt.Printf("%s: unknown flag\n", os.Args[i])
			os.Exit(1)
		}
	}

	sourceFiles := os.Args[2:]
	result, err := renderer.RenderConfig(sourceFiles)
	if err != nil {
		fmt.Println("Error:", err)
		os.Exit(1)
	}

	if server != "" && port != "" {
		tcpwait.WaitForTCP(server, port)
	}

	outputYAML, _ := yaml.Marshal(result)
	err = os.WriteFile(output, outputYAML, 0644)
	if err != nil {
		fmt.Println("Error writing to file:", err)
		os.Exit(1)
	}
	fmt.Println(string(output))
}
