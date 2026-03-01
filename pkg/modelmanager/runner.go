package modelmanager

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
)

// Runner manages the lifecycle of the external inference server
type Runner struct {
	downloader *Downloader
	binaryPath string
}

func NewRunner() *Runner {
	return &Runner{
		downloader: NewDownloader(),
	}
}

// EnsureBinary fetches the correct underlying inference server for the host OS/Arch.
// We use a generic pre-compiled llama.cpp server to keep NicaClaw-lite ultra-lightweight.
func (r *Runner) EnsureBinary(ctx context.Context) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get home dir: %w", err)
	}

	binDir := filepath.Join(home, ".nicaclaw-lite", "bin")
	if err := os.MkdirAll(binDir, 0755); err != nil {
		return fmt.Errorf("failed to create bin directory: %w", err)
	}

	ext := ""
	if runtime.GOOS == "windows" {
		ext = ".exe"
	}

	r.binaryPath = filepath.Join(binDir, "llama-server"+ext)

	// In a real production scenario, these URLs would point to official WilbergV/nicaclaw releases
	// For this phase, we use placeholder logic that would mirror standard release naming.
	downloadURL := fmt.Sprintf("https://github.com/WilberGV/nicaclaw-lite-models/releases/download/latest/llama-server-%s-%s%s", runtime.GOOS, runtime.GOARCH, ext)

	if _, err := os.Stat(r.binaryPath); os.IsNotExist(err) {
		fmt.Printf("Inference binary not found. Downloading for %s/%s...\n", runtime.GOOS, runtime.GOARCH)
		if err := r.downloader.DownloadFile(ctx, downloadURL, r.binaryPath); err != nil {
			return fmt.Errorf("failed to download inference binary: %w", err)
		}
		// Make executable
		if runtime.GOOS != "windows" {
			os.Chmod(r.binaryPath, 0755)
		}
	}

	return nil
}

// StartServer launches the inference server as a sub-process
func (r *Runner) StartServer(ctx context.Context, modelPath string) (*exec.Cmd, error) {
	if _, err := os.Stat(modelPath); os.IsNotExist(err) {
		return nil, fmt.Errorf("model file not found at %s", modelPath)
	}

	// Basic execution arguments for llama-server compatible with OpenAI API
	args := []string{
		"-m", modelPath,
		"--host", "127.0.0.1",
		"--port", "8080",
		"--ctx-size", "4096", // Default sensible context
	}

	cmd := exec.CommandContext(ctx, r.binaryPath, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	fmt.Printf("Starting local inference server on http://127.0.0.1:8080...\n")
	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("failed to start inference server: %w", err)
	}

	return cmd, nil
}
