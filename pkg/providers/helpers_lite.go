//go:build lite

package providers

type AntigravityModelInfo struct {
	ID          string `json:"id"`
	DisplayName string `json:"display_name"`
	IsExhausted bool   `json:"is_exhausted"`
}

func FetchAntigravityProjectID(accessToken string) (string, error) {
	return "", nil
}

func FetchAntigravityModels(accessToken, projectID string) ([]AntigravityModelInfo, error) {
	return nil, nil
}
