//go:build !lite

// nicaclawlite - Ultra-lightweight personal AI agent
// Inspired by and based on nanobot: https://github.com/HKUDS/nanobot
// License: MIT
//
// Copyright (c) 2026 nicaclawlite contributors

package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"nicaclaw-lite/cmd/nicaclaw-lite/internal"
	"nicaclaw-lite/cmd/nicaclaw-lite/internal/agent"
	"nicaclaw-lite/cmd/nicaclaw-lite/internal/auth"
	"nicaclaw-lite/cmd/nicaclaw-lite/internal/cron"
	"nicaclaw-lite/cmd/nicaclaw-lite/internal/gateway"
	"nicaclaw-lite/cmd/nicaclaw-lite/internal/migrate"
	"nicaclaw-lite/cmd/nicaclaw-lite/internal/model"
	"nicaclaw-lite/cmd/nicaclaw-lite/internal/onboard"
	"nicaclaw-lite/cmd/nicaclaw-lite/internal/skills"
	"nicaclaw-lite/cmd/nicaclaw-lite/internal/status"
	"nicaclaw-lite/cmd/nicaclaw-lite/internal/version"
)

func NewNicaClawLiteCommand() *cobra.Command {
	short := fmt.Sprintf("%s nicaclaw-lite - Personal AI Assistant v%s\n\n", internal.Logo, internal.GetVersion())

	cmd := &cobra.Command{
		Use:     "nicaclaw-lite",
		Short:   short,
		Example: "nicaclaw-lite list",
	}

	cmd.AddCommand(
		onboard.NewOnboardCommand(),
		agent.NewAgentCommand(),
		auth.NewAuthCommand(),
		gateway.NewGatewayCommand(),
		status.NewStatusCommand(),
		cron.NewCronCommand(),
		migrate.NewMigrateCommand(),
		model.NewModelCommand(),
		skills.NewSkillsCommand(),
		version.NewVersionCommand(),
	)

	return cmd
}

func main() {
	cmd := NewNicaClawLiteCommand()
	if err := cmd.Execute(); err != nil {
		os.Exit(1)
	}
}
