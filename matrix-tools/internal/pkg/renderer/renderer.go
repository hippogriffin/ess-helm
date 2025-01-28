// Copyright 2025 New Vector Ltd
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

package renderer

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"regexp"
	"strings"

	"gopkg.in/yaml.v3"
)

type Config struct {
	Data map[string]any `json:"data"`
}

func deepMergeMaps(source, destination map[string]any) error {
	for key, value := range source {
		if destValue, exists := destination[key]; exists {
			if srcMap, ok := value.(map[string]any); ok {
				if destMap, ok := destValue.(map[string]any); ok {
					if err := deepMergeMaps(srcMap, destMap); err != nil {
						return err
					}
				} else {
					destination[key] = value
				}
			} else {
				destination[key] = value
			}
		} else {
			destination[key] = value
		}
	}
	return nil
}

func ReadFiles(configFiles []string) ([]io.Reader, error) {
	files := make([]io.Reader, 0)
	for _, configFile := range configFiles {
		fileReader, err := os.Open(configFile)
		if err != nil {
			return files, fmt.Errorf("failed to open file: %w", err)
		}
		defer fileReader.Close()
		files = append(files, fileReader)
	}
	return files, nil
}

// RenderConfig takes a list of io.Reader objects representing yaml configuration files
// and returns a single map[string]any containing the deeply merged data as yaml format
// The files are merged in the order they are provided.
func RenderConfig(sourceConfigs []io.Reader) (map[string]any, error) {
	output := make(map[string]any)

	for _, configReader := range sourceConfigs {
		fileContent, err := io.ReadAll(configReader)
		if err != nil {
			return nil, errors.New("failed to read from reader: " + err.Error())
		}

		envVarNames := extractEnvVarNames(string(fileContent))
		for _, envVar := range envVarNames {
			val, ok := os.LookupEnv(envVar)
			if !ok {
				return nil, errors.New(envVar + " is not present in the environment")
			}
			var replacementValue []byte
			if strings.HasPrefix(val, "hostname://") {
				machineHostname, err := os.Hostname()
				if err != nil {
					return nil, err
				}
				replacementValue = []byte(strings.ReplaceAll(machineHostname, strings.TrimPrefix(val, "hostname://"), ""))
			} else if strings.HasPrefix(val, "secret://") {
				filePath := strings.TrimPrefix(val, "secret://")
				fileBytes, err := os.ReadFile(filePath)
				if err != nil {
					return nil, fmt.Errorf("failed to read file: %s", filePath)
				}
				replacementValue, err = json.Marshal(string(fileBytes))
				if err != nil {
					return nil, err
				}
			} else {
				replacementValue, err = json.Marshal(val)
			}
			if err != nil {
				return nil, err
			}
			fileContent = bytes.ReplaceAll(fileContent, []byte("${"+envVar+"}"), replacementValue)
		}

		var data map[string]any
		if err := yaml.Unmarshal(fileContent, &data); err != nil {
			return nil, fmt.Errorf("Post-processed YAML is invalid: %s with error: %v", string(fileContent), err)
		}

		if err := deepMergeMaps(data, output); err != nil {
			return nil, err
		}
	}

	return output, nil
}

func extractEnvVarNames(fileContent string) []string {
	var envVars []string
	re := regexp.MustCompile(`\$\{([^\}]+)\}`)
	matches := re.FindAllStringSubmatch(fileContent, -1)
	for _, match := range matches {
		if len(match) > 1 {
			envVars = append(envVars, match[1])
		}
	}
	return envVars
}
