//go:build lite

package agent

import (
	"nicaclaw-lite/pkg/bus"
	"nicaclaw-lite/pkg/config"
	"nicaclaw-lite/pkg/providers"
	"nicaclaw-lite/pkg/tools"
)

// registerSharedTools registers the absolute minimum set of tools for the lite build.
func registerSharedTools(
	cfg *config.Config,
	msgBus *bus.MessageBus,
	registry *AgentRegistry,
	provider providers.LLMProvider,
) {
	for _, agentID := range registry.ListAgentIDs() {
		agent, ok := registry.GetAgent(agentID)
		if !ok {
			continue
		}

		// Message tool (small and essential for communication)
		messageTool := tools.NewMessageTool()
		messageTool.SetSendCallback(func(channel, chatID, content string) error {
			msgBus.PublishOutbound(bus.OutboundMessage{
				Channel: channel,
				ChatID:  chatID,
				Content: content,
			})
			return nil
		})
		agent.Tools.Register(messageTool)
	}
}
