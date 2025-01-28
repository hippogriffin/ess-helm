// Copyright 2025 New Vector Ltd
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

package renderer

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"os"
	"regexp"
	"strings"
	"text/template"

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

func ReadFiles(configFiles []string) ([]io.Reader, []func() error, error) {
	files := make([]io.Reader, 0)
	closeFiles := make([]func() error, 0)
	for _, configFile := range configFiles {
		fileReader, err := os.Open(configFile)
		if err != nil {
			return files, closeFiles, fmt.Errorf("failed to open file: %w", err)
		}
		files = append(files, fileReader)
		closeFiles = append(closeFiles, fileReader.Close)
	}
	return files, closeFiles, nil
}

func readfile(path string) (string, error) {
	content, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("failed to read file: %w", err)
	}
	return string(content), nil
}

func replace(old, new, src string) string {
	return strings.Replace(src, old, new, -1)
}

// RenderConfig takes a list of io.Reader objects representing yaml configuration files
// and returns a single map[string]any containing the deeply merged data as yaml format
// The files are merged in the order they are provided.
// Each file can contain variables to replace with the format ${VARNAME}
// Variables to replace are fetched from the environment variables. Their value
// is parsed through go template engine.
// 3 functions are available in the template :
// - readfile(path) : reads a file and returns its content
// - hostname() : returns the current host name
// - replace(old,new,string) : replaces old with new in string
func RenderConfig(sourceConfigs []io.Reader) (map[string]any, error) {
	output := make(map[string]any)

	for _, configReader := range sourceConfigs {
		fileContent, err := io.ReadAll(configReader)
		if err != nil {
			return nil, errors.New("failed to read from reader: " + err.Error())
		}

		funcMap := template.FuncMap{
			"readfile": readfile,
			"hostname": os.Hostname,
			"replace":  replace,
		}

		envVarNames := extractEnvVarNames(string(fileContent))
		for _, envVar := range envVarNames {
			val, ok := os.LookupEnv(envVar)
			if !ok {
				return nil, errors.New(envVar + " is not present in the environment")
			}
			var replacementValue []byte
			tmpl, err := template.New("matrix-tools").Funcs(funcMap).Parse(val)
			if err != nil {
				return nil, err
			}
			var buffer bytes.Buffer
			err = tmpl.Execute(&buffer, output)
			if err != nil {
				return nil, err
			}
			replacementValue = buffer.Bytes()
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
