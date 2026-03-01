//go:build lite

package channels

import "context"

// Manager is a stub for the lite build to avoid bringing in Discord, Slack, Telegram, etc dependencies.
type Manager struct {
}

func NewManager(ctx context.Context) *Manager {
	return &Manager{}
}

func (m *Manager) Start() error {
	return nil
}

func (m *Manager) Stop() error {
	return nil
}

func (m *Manager) GetEnabledChannels() []string {
	return []string{}
}

func (m *Manager) GetChannel(id string) (interface{}, bool) {
	return nil, false
}
