//go:build lite

package providers

import (
	"fmt"
	"strings"

	"nicaclaw-lite/pkg/config"
)

// Re-defining internal types needed for lite build
type providerType int

const (
	providerTypeHTTPCompat providerType = iota
)

type providerSelection struct {
	providerType providerType
	apiKey       string
	apiBase      string
	proxy        string
	model        string
}

func resolveProviderSelection(cfg *config.Config) (providerSelection, error) {
	model := cfg.Agents.Defaults.GetModelName()
	providerName := strings.ToLower(cfg.Agents.Defaults.Provider)

	sel := providerSelection{
		providerType: providerTypeHTTPCompat,
		model:        model,
	}

	switch providerName {
	case "openai", "gpt":
		sel.apiKey = cfg.Providers.OpenAI.APIKey
		sel.apiBase = cfg.Providers.OpenAI.APIBase
		if sel.apiBase == "" {
			sel.apiBase = "https://api.openai.com/v1"
		}
	case "anthropic", "claude":
		sel.apiKey = cfg.Providers.Anthropic.APIKey
		sel.apiBase = cfg.Providers.Anthropic.APIBase
		if sel.apiBase == "" {
			sel.apiBase = "https://api.anthropic.com/v1"
		}
	case "ollama":
		sel.apiKey = cfg.Providers.Ollama.APIKey
		sel.apiBase = cfg.Providers.Ollama.APIBase
		if sel.apiBase == "" {
			sel.apiBase = "http://localhost:11434/v1"
		}
	default:
		sel.apiKey = cfg.Providers.OpenAI.APIKey
		sel.apiBase = cfg.Providers.OpenAI.APIBase
	}

	return sel, nil
}

// ExtractProtocol extracts the protocol prefix and model identifier from a model string.
func ExtractProtocol(model string) (protocol, modelID string) {
	model = strings.TrimSpace(model)
	protocol, modelID, found := strings.Cut(model, "/")
	if !found {
		return "openai", model
	}
	return protocol, modelID
}

// CreateProviderFromConfig creates a provider based on the ModelConfig for lite build.
func CreateProviderFromConfig(cfg *config.ModelConfig) (LLMProvider, string, error) {
	if cfg == nil {
		return nil, "", fmt.Errorf("config is nil")
	}
	protocol, modelID := ExtractProtocol(cfg.Model)

	apiBase := cfg.APIBase
	if apiBase == "" {
		switch protocol {
		case "anthropic":
			apiBase = "https://api.anthropic.com/v1"
		case "ollama":
			apiBase = "http://localhost:11434/v1"
		default:
			apiBase = "https://api.openai.com/v1"
		}
	}

	return NewHTTPProvider(cfg.APIKey, apiBase, cfg.Proxy), modelID, nil
}

// CreateProvider creates a provider based on the configuration for lite build.
func CreateProvider(cfg *config.Config) (LLMProvider, string, error) {
	model := cfg.Agents.Defaults.GetModelName()
	_, modelID := ExtractProtocol(model)

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
		// Fallback to resolveProviderSelection if ModelList is empty
		sel, err := resolveProviderSelection(cfg)
		if err != nil {
			return nil, "", err
		}
		return NewHTTPProvider(sel.apiKey, sel.apiBase, sel.proxy), modelID, nil
	}

	// Simple non-dynamic creation for lite build
	// Just use the first matching model config or the first one available
	var modelCfg *config.ModelConfig
	for i := range cfg.ModelList {
		if cfg.ModelList[i].Model == model {
			modelCfg = &cfg.ModelList[i]
			break
		}
	}
	if modelCfg == nil {
		modelCfg = &cfg.ModelList[0]
	}

	return CreateProviderFromConfig(modelCfg)
}
