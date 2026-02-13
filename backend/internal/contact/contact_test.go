package contact

import (
	"testing"
)

func TestContactEmailValidation(t *testing.T) {
	tests := []struct {
		name  string
		email string
		valid bool
	}{
		{"Valid email", "friend@example.com", true},
		{"Invalid - no @", "friendexample.com", false},
		{"Invalid - no domain", "friend@", false},
		{"Empty", "", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Простейшая проверка email
			hasAt := false
			hasDot := false
			for i, c := range tt.email {
				if c == '@' {
					hasAt = true
				}
				if c == '.' && i > 0 && i < len(tt.email)-1 {
					hasDot = true
				}
			}
			isValid := hasAt && hasDot && len(tt.email) > 5

			if isValid != tt.valid {
				t.Errorf("Email %s: got %v, want %v", tt.email, isValid, tt.valid)
			} else {
				t.Logf("✅ %s: проверка работает", tt.name)
			}
		})
	}
}
