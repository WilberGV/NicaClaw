package model

import (
	"context"
	"fmt"

	"nicaclaw-lite/pkg/modelmanager"

	"github.com/spf13/cobra"
)

// NewModelCommand creates the `model` subcommand
func NewModelCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "model",
		Short: "Manage and run local AI models (GGUF)",
		Long:  `Download and execute small AI models directly on the device using a lightweight standalone runner.`,
	}

	cmd.AddCommand(newFetchCommand())
	cmd.AddCommand(newRunCommand())

	return cmd
}

func newFetchCommand() *cobra.Command {
	return &cobra.Command{
		Use:   "fetch [URL] [destination]",
		Short: "Download a .gguf model file",
		Args:  cobra.ExactArgs(2),
		RunE: func(cmd *cobra.Command, args []string) error {
			url := args[0]
			dest := args[1]

			fmt.Printf("Fetching model from: %s\n", url)
			fmt.Printf("Destination: %s\n", dest)

			downloader := modelmanager.NewDownloader()
			if err := downloader.DownloadFile(context.Background(), url, dest); err != nil {
				return fmt.Errorf("download failed: %w", err)
			}

			return nil
		},
	}
}

func newRunCommand() *cobra.Command {
	return &cobra.Command{
		Use:   "run [path_to_gguf]",
		Short: "Execute a local AI model",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			modelPath := args[0]
			fmt.Printf("Preparing to run local model: %s\n", modelPath)

			runner := modelmanager.NewRunner()

			// 1. Ensure inference binary
			if err := runner.EnsureBinary(context.Background()); err != nil {
				return fmt.Errorf("failed to prepare inference server: %w", err)
			}

			// 2. Start inference server
			srvCmd, err := runner.StartServer(context.Background(), modelPath)
			if err != nil {
				return fmt.Errorf("server startup failed: %w", err)
			}

			// Block until server closes (e.g., interrupted by user)
			return srvCmd.Wait()
		},
	}
}
