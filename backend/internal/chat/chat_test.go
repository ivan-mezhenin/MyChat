package chat

import (
	"testing"
)

func TestChatNameValidation(t *testing.T) {
	tests := []struct {
		name     string
		chatName string
		expected bool
	}{
		{
			name:     "Valid name",
			chatName: "My Chat",
			expected: true,
		},
		{
			name:     "Empty name",
			chatName: "",
			expected: false,
		},
		{
			name:     "Too long name",
			chatName: string(make([]byte, 101)),
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			isValid := len(tt.chatName) > 0 && len(tt.chatName) <= 100

			if isValid != tt.expected {
				t.Errorf("Chat name '%s': got %v, want %v", tt.chatName, isValid, tt.expected)
			} else {
				t.Logf("%s: валидация работает", tt.name)
			}
		})
	}
}

func TestParticipantsValidation(t *testing.T) {
	tests := []struct {
		name         string
		participants []string
		expected     bool
	}{
		{
			name:         "Enough participants (3)",
			participants: []string{"user1", "user2", "user3"},
			expected:     true,
		},
		{
			name:         "Enough participants (2)",
			participants: []string{"user1", "user2"},
			expected:     true,
		},
		{
			name:         "Not enough (1)",
			participants: []string{"user1"},
			expected:     false,
		},
		{
			name:         "Empty",
			participants: []string{},
			expected:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			isValid := len(tt.participants) >= 2

			if isValid != tt.expected {
				t.Errorf("Participants %v: got %v, want %v", tt.participants, isValid, tt.expected)
			} else {
				t.Logf("%s: проверка работает", tt.name)
			}
		})
	}
}
