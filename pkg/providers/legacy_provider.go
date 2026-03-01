// nicaclawlite - Ultra-lightweight personal AI agent
// License: MIT
//
// Copyright (c) 2026 nicaclawlite contributors

package providers

import (
	"fmt"

	"nicaclaw-lite/pkg/config"
)

// CreateProvider creates a provider based on the configuration.
// It uses the model_list configuration (new format) to create providers.
// The old providers config is automatically converted to model_list during config loading.
// Returns the provider, the model ID to use, and any error.
// CreateProvider creates a provider based on the configuration.
// It uses the DynamicProvider to allow switching between different models
// and providers transparently during execution.
func CreateProvider(cfg *config.Config) (LLMProvider, string, error) {
	model := cfg.Agents.Defaults.GetModelName()

	// Ensure model_list is populated from providers config if needed
	if cfg.HasProvidersConfig() {
		providerModels := config.ConvertProvidersToModelList(cfg)
		existingModelNames := make(map[string]bool)
		for _, m := range cfg.ModelList {
			existingModelNames[m.ModelName] = true
		}
		for _, pm := range providerModels {
			if !existingModelNames[pm.ModelName] {
				cfg.ModelList = append(cfg.ModelList, pm)
			}
		}
	}

	if len(cfg.ModelList) == 0 {
		return nil, "", fmt.Errorf("no providers configured")
	}

	return NewDynamicProvider(cfg), model, nil
}
