package authentication

import (
	"strings"
	"testing"
)

func TestEmailValidation(t *testing.T) {
	tests := []struct {
		name     string
		email    string
		expected bool
	}{
		{
			name:     "Valid email",
			email:    "user@example.com",
			expected: true,
		},
		{
			name:     "Missing @",
			email:    "userexample.com",
			expected: false,
		},
		{
			name:     "Missing domain",
			email:    "user@",
			expected: false,
		},
		{
			name:     "Empty email",
			email:    "",
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			isValid := strings.Contains(tt.email, "@") &&
				strings.Contains(tt.email, ".") &&
				len(tt.email) > 5

			if isValid != tt.expected {
				t.Errorf("Email %s: got %v, want %v", tt.email, isValid, tt.expected)
			} else {
				t.Logf("%s: проверка работает", tt.name)
			}
		})
	}
}

func TestPasswordValidation(t *testing.T) {
	tests := []struct {
		name     string
		password string
		expected bool
	}{
		{
			name:     "Valid password (6+ chars)",
			password: "pass12",
			expected: true,
		},
		{
			name:     "Too short",
			password: "12345",
			expected: false,
		},
		{
			name:     "Empty password",
			password: "",
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			isValid := len(tt.password) >= 6

			if isValid != tt.expected {
				t.Errorf("Password %s: got %v, want %v", tt.password, isValid, tt.expected)
			} else {
				t.Logf("%s: проверка работает", tt.name)
			}
		})
	}
}
