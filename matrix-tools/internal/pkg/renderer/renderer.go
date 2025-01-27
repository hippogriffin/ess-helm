// matrix-tools/internal/config/renderer/renderer.go

package renderer

import (
	"bytes"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"regexp"

	"gopkg.in/yaml.v3"
)

type Config struct {
	Data map[string]interface{} `json:"data"`
}

func deepMergeMaps(source, destination map[string]interface{}) error {
	for key, value := range source {
		if destValue, exists := destination[key]; exists {
			if srcMap, ok := value.(map[string]interface{}); ok {
				if destMap, ok := destValue.(map[string]interface{}); ok {
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

func RenderConfig(sourceFiles []string) (map[string]interface{}, error) {
	output := make(map[string]interface{})

	for _, sourceFilename := range sourceFiles {
		if !filepath.IsAbs(sourceFilename) {
			absName, err := filepath.Abs(sourceFilename)
			if err != nil {
				return nil, err
			}
			sourceFilename = absName
		}

		if fileInfo, err := os.Stat(sourceFilename); err == nil && fileInfo.IsDir() {
			continue
		}

		fileContent, err := os.ReadFile(sourceFilename)
		if err != nil {
			return nil, errors.New("failed to read file: " + sourceFilename)
		}

		envVarNames := extractEnvVarNames(string(fileContent))
		for _, envVar := range envVarNames {
			if val, ok := os.LookupEnv(envVar); !ok {
				return nil, errors.New(envVar + " is not present in the environment")
			} else {
				replacementValue, err := json.Marshal(val)
				if err != nil {
					return nil, err
				}
				if err != nil {
					return nil, errors.New("failed to marshal environment variable: " + envVar)
				}
				fileContent = bytes.ReplaceAll(fileContent, []byte("${"+envVar+"}"), replacementValue)
			}
		}

		var data map[string]interface{}
		if err := yaml.Unmarshal(fileContent, &data); err != nil {
			return nil, errors.New("Post-processed YAML of " + sourceFilename + " is invalid: " + string(fileContent) + " with error: " + err.Error())
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
