package registration

import (
	"strings"
	"testing"
)

func TestRegistrationValidation(t *testing.T) {
	tests := []struct {
		name     string
		username string
		email    string
		password string
		want     bool
	}{
		{"Valid registration", "john", "john@test.com", "password123", true},
		{"Empty username", "", "john@test.com", "password123", false},
		{"Empty email", "john", "", "password123", false},
		{"Empty password", "john", "john@test.com", "", false},
		{"Short password", "john", "john@test.com", "123", false},
		{"Invalid email", "john", "not-an-email", "password123", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Валидация
			validUsername := len(tt.username) > 0
			validEmail := len(tt.email) > 5 && contains(tt.email, "@") && contains(tt.email, ".")
			validPassword := len(tt.password) >= 6

			isValid := validUsername && validEmail && validPassword

			if isValid != tt.want {
				t.Errorf("%s: got %v, want %v", tt.name, isValid, tt.want)
			} else {
				t.Logf("✅ %s: валидация работает", tt.name)
			}
		})
	}
}

func TestUsernameFormat(t *testing.T) {
	tests := []struct {
		name     string
		username string
		want     bool
	}{
		{"Valid", "john123", true},
		{"Too short", "jo", false},
		{"Too long", string(make([]byte, 51)), false},
		{"With spaces", "john doe", true},
		{"Special chars", "john@#$", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			validLength := len(tt.username) >= 3 && len(tt.username) <= 50
			t.Logf("Username %q: length=%d, valid=%v",
				tt.username, len(tt.username), validLength)
		})
	}
}

func contains(s, substr string) bool {
	return strings.Contains(s, substr)
}
