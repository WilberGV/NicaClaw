package modelmanager

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

// Downloader handles robust streaming downloads for large AI models.
type Downloader struct {
	client *http.Client
}

// NewDownloader returns a new instance of Downloader
func NewDownloader() *Downloader {
	return &Downloader{
		client: &http.Client{},
	}
}

// DownloadFile downloads a file securely with chunking, preserving RAM.
// If the destination exists and is fully downloaded, it skips.
// Prints simple progress to stdout without advanced TUI dependencies.
func (d *Downloader) DownloadFile(ctx context.Context, url, destPath string) error {
	// Create destination directory if needed
	if err := os.MkdirAll(filepath.Dir(destPath), 0755); err != nil {
		return fmt.Errorf("failed to create destination directory: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	resp, err := d.client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("bad status: %d %s", resp.StatusCode, resp.Status)
	}

	fileSize := resp.ContentLength
	var currentSize int64

	// Check if already completely downloaded
	if stat, err := os.Stat(destPath); err == nil && fileSize > 0 && stat.Size() == fileSize {
		fmt.Printf("File already downloaded: %s\n", destPath)
		return nil
	}

	// Create a temporary file
	tmpPath := destPath + ".download"
	out, err := os.Create(tmpPath)
	if err != nil {
		return fmt.Errorf("failed to create temp file: %w", err)
	}

	// Clean up temp file on failure
	defer func() {
		out.Close()
		if err != nil {
			os.Remove(tmpPath)
		}
	}()

	fmt.Printf("Downloading model... (Total size: %.2f MB)\n", float64(fileSize)/(1024*1024))

	buf := make([]byte, 32*1024) // 32KB buffer chunks
	var lastPercent int

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
			n, errRead := resp.Body.Read(buf)
			if n > 0 {
				_, errWrite := out.Write(buf[:n])
				if errWrite != nil {
					return fmt.Errorf("failed to write data: %w", errWrite)
				}
				currentSize += int64(n)

				if fileSize > 0 {
					percent := int((float64(currentSize) / float64(fileSize)) * 100)
					if percent > lastPercent {
						// Simple terminal output overwriting
						fmt.Printf("\rProgress: [%-50s] %d%%", strings.Repeat("=", percent/2)+strings.Repeat(" ", 50-(percent/2)), percent)
						lastPercent = percent
					}
				}
			}

			if errRead == io.EOF {
				fmt.Printf("\nDownload complete: %s\n", destPath)
				// Close early before rename
				out.Close()
				return os.Rename(tmpPath, destPath)
			}
			if errRead != nil {
				return errRead
			}
		}
	}
}
