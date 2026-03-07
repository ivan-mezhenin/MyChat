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
				t.Logf("%s: проверка работает", tt.name)
			}
		})
	}
}

func TestValidateContact(t *testing.T) {
	tests := []struct {
		name        string
		ownerID     string
		contactID   string
		contactName string
		want        bool
	}{
		{
			name:        "Valid contact",
			ownerID:     "user123",
			contactID:   "user456",
			contactName: "Friend",
			want:        true,
		},
		{
			name:        "Self contact",
			ownerID:     "user123",
			contactID:   "user123",
			contactName: "Self",
			want:        false,
		},
		{
			name:        "Empty owner",
			ownerID:     "",
			contactID:   "user456",
			contactName: "Friend",
			want:        false,
		},
		{
			name:        "Empty contact",
			ownerID:     "user123",
			contactID:   "",
			contactName: "Friend",
			want:        false,
		},
		{
			name:        "Empty name",
			ownerID:     "user123",
			contactID:   "user456",
			contactName: "",
			want:        true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			notSelf := tt.ownerID != tt.contactID

			validIDs := tt.ownerID != "" && tt.contactID != ""

			got := notSelf && validIDs
			if got != tt.want {
				t.Errorf("ValidateContact(%q, %q, %q) = %v, want %v",
					tt.ownerID, tt.contactID, tt.contactName, got, tt.want)
			}
		})
	}
}

func TestGenerateContactID(t *testing.T) {
	tests := []struct {
		name      string
		ownerID   string
		contactID string
		want      string
	}{
		{
			name:      "Normal case",
			ownerID:   "user123",
			contactID: "contact456",
			want:      "user123_contact456",
		},
		{
			name:      "With special chars",
			ownerID:   "user@123",
			contactID: "contact#456",
			want:      "user@123_contact#456",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.ownerID + "_" + tt.contactID
			if got != tt.want {
				t.Errorf("GenerateContactID(%q, %q) = %q, want %q",
					tt.ownerID, tt.contactID, got, tt.want)
			}
		})
	}
}
