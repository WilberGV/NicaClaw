//go:build lite

package main

import (
	"os"

	"nicaclaw-lite/cmd/nicaclaw-lite/internal/agent"
)

func main() {
	cmd := agent.NewAgentCommand()
	cmd.Use = "nicaclaw-lite"
	cmd.Short = "nicaclaw-lite (LITE) - Personal AI Assistant"

	// The executable directly runs the interactive agent command without subcommands.
	if err := cmd.Execute(); err != nil {
		os.Exit(1)
	}
}
