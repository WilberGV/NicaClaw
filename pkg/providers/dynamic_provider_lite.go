//go:build lite

package providers

import (
	"context"
	"fmt"
	"regexp"
	"strconv"
	"sync"

	"nicaclaw-lite/pkg/config"
)

// indexedModelRegexLite matches model names with an index, e.g., "gemini-flash[2]"
var indexedModelRegexLite = regexp.MustCompile(`^(.+)\[(\d+)\]$`)

// DynamicProviderLite resolves models and creates actual providers on-the-fly
// for the lite build. This allows a single AgentInstance to use multiple
// different providers (OpenRouter, Gemini, etc.) and handle multi-key
// switching via FallbackChain.
type DynamicProviderLite struct {
	cfg     *config.Config
	cache   map[string]LLMProvider
	cacheMu sync.RWMutex
}

// NewDynamicProviderLite creates a new dynamic provider for lite build.
func NewDynamicProviderLite(cfg *config.Config) *DynamicProviderLite {
	return &DynamicProviderLite{
		cfg:   cfg,
		cache: make(map[string]LLMProvider),
	}
}

func (p *DynamicProviderLite) Chat(
	ctx context.Context,
	messages []Message,
	tools []ToolDefinition,
	model string,
	options map[string]any,
) (*LLMResponse, error) {
	// 1. Resolve model to specific config
	var modelCfg *config.ModelConfig
	var err error

	if matches := indexedModelRegexLite.FindStringSubmatch(model); matches != nil {
		name := matches[1]
		idx, _ := strconv.Atoi(matches[2])
		modelCfg, err = p.cfg.GetModelConfigByIndex(name, idx)
	} else {
		modelCfg, err = p.cfg.GetModelConfig(model)
	}

	if err != nil {
		return nil, fmt.Errorf("dynamic resolve failed for %q: %w", model, err)
	}

	// 2. Get or create provider for this config
	provider, modelID, err := p.getOrCreateProvider(modelCfg)
	if err != nil {
		return nil, err
	}

	// 3. Dispatch to actual provider
	return provider.Chat(ctx, messages, tools, modelID, options)
}

func (p *DynamicProviderLite) GetDefaultModel() string {
	return p.cfg.Agents.Defaults.GetModelName()
}

func (p *DynamicProviderLite) getOrCreateProvider(cfg *config.ModelConfig) (LLMProvider, string, error) {
	// Simple cache key based on API key and base URL
	cacheKey := fmt.Sprintf("%s|%s|%s", cfg.APIKey, cfg.APIBase, cfg.Model)

	p.cacheMu.RLock()
	cached, ok := p.cache[cacheKey]
	p.cacheMu.RUnlock()

	if ok {
		_, modelID := ExtractProtocol(cfg.Model)
		return cached, modelID, nil
	}

	p.cacheMu.Lock()
	defer p.cacheMu.Unlock()

	// Double-check after lock
	if cached, ok := p.cache[cacheKey]; ok {
		_, modelID := ExtractProtocol(cfg.Model)
		return cached, modelID, nil
	}

	provider, modelID, err := CreateProviderFromConfig(cfg)
	if err != nil {
		return nil, "", err
	}

	p.cache[cacheKey] = provider
	return provider, modelID, nil
}
