// Copyright 2025 New Vector Ltd
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

package main

import (
	"fmt"
	"os"

	"github.com/element-hq/ess-helm/matrix-tools/internal/pkg/renderer"
	"gopkg.in/yaml.v3"
)

func main() {
	if len(os.Args) < 2 || os.Args[1] != "--render-config" {
		fmt.Println("Usage: --render-config <source files>")
		os.Exit(1)
	}

	sourceFiles := os.Args[2:]
	result, err := renderer.RenderConfig(sourceFiles)
	if err != nil {
		fmt.Println("Error:", err)
		os.Exit(1)
	}

	output, _ := yaml.Marshal(result)
	fmt.Println(string(output))
}
