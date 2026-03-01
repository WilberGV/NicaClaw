package providers

import (
	"context"
	"fmt"
	"regexp"
	"strconv"
	"sync"

	"nicaclaw-lite/pkg/config"
)

// indexedModelRegex matches model names with an index, e.g., "auto[0]"
var indexedModelRegex = regexp.MustCompile(`^(.+)\[(\d+)\]$`)

// DynamicProvider resolves models and creates actual providers on-the-fly.
// This allows a single AgentInstance to use multiple different providers
// (OpenRouter, Gemini, etc.) and handle multi-key switching via FallbackChain.
type DynamicProvider struct {
	cfg     *config.Config
	cache   map[string]LLMProvider
	cacheMu sync.RWMutex
}

func NewDynamicProvider(cfg *config.Config) *DynamicProvider {
	return &DynamicProvider{
		cfg:   cfg,
		cache: make(map[string]LLMProvider),
	}
}

func (p *DynamicProvider) Chat(
	ctx context.Context,
	messages []Message,
	tools []ToolDefinition,
	model string,
	options map[string]any,
) (*LLMResponse, error) {
	// 1. Resolve model to specific config
	var modelCfg *config.ModelConfig
	var err error

	if matches := indexedModelRegex.FindStringSubmatch(model); matches != nil {
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

func (p *DynamicProvider) GetDefaultModel() string {
	return p.cfg.Agents.Defaults.GetModelName()
}

func (p *DynamicProvider) getOrCreateProvider(cfg *config.ModelConfig) (LLMProvider, string, error) {
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
