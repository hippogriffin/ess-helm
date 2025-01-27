package main

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/element-hq/ess-helm/matrix-tools/internal/pkg/renderer"
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

	output, _ := json.MarshalIndent(result, "", "  ")
	fmt.Println(string(output))
}
