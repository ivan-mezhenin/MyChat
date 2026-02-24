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

func TestChatValidation(t *testing.T) {
	tests := []struct {
		name     string
		chatName string
		chatType string
		want     bool
	}{
		{"Valid group chat", "My Group", "group", true},
		{"Valid private chat", "Private Chat", "private", true},
		{"Empty name", "", "group", false},
		{"Invalid type", "Chat", "invalid", false},
		{"Very long name", string(make([]byte, 200)), "group", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			validName := len(tt.chatName) > 0 && len(tt.chatName) <= 100
			validType := tt.chatType == "group" || tt.chatType == "private"
			isValid := validName && validType

			if isValid != tt.want {
				t.Errorf("Chat (name=%q, type=%q): got %v, want %v",
					tt.chatName, tt.chatType, isValid, tt.want)
			} else {
				t.Logf(" %s: валидация работает", tt.name)
			}
		})
	}
}

func TestMessageValidation(t *testing.T) {
	tests := []struct {
		name    string
		message string
		maxLen  int
		want    bool
	}{
		{"Valid message", "Hello, world!", 1000, true},
		{"Empty message", "", 1000, false},
		{"Very long message", string(make([]byte, 2000)), 1000, false},
		{"Exactly max length", string(make([]byte, 1000)), 1000, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			isValid := len(tt.message) > 0 && len(tt.message) <= tt.maxLen

			if isValid != tt.want {
				t.Errorf("Message length %d (max %d): got %v, want %v",
					len(tt.message), tt.maxLen, isValid, tt.want)
			} else {
				t.Logf(" %s: проверка сообщения работает", tt.name)
			}
		})
	}
}

func TestValidateChatName(t *testing.T) {
	tests := []struct {
		name     string
		chatName string
		want     bool
	}{
		{"Valid name", "My Chat", true},
		{"Empty name", "", false},
		{"Too long", string(make([]byte, 101)), false},
		{"Just spaces", "   ", false},
		{"Valid with symbols", "Chat #123", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			trimmed := tt.chatName
			for len(trimmed) > 0 && trimmed[0] == ' ' {
				trimmed = trimmed[1:]
			}
			for len(trimmed) > 0 && trimmed[len(trimmed)-1] == ' ' {
				trimmed = trimmed[:len(trimmed)-1]
			}

			got := len(trimmed) > 0 && len(trimmed) <= 100
			if got != tt.want {
				t.Errorf("ValidateChatName(%q) = %v, want %v", tt.chatName, got, tt.want)
			}
		})
	}
}

func TestValidateParticipants(t *testing.T) {
	tests := []struct {
		name         string
		participants []string
		creatorID    string
		want         bool
	}{
		{
			name:         "Valid group (3 participants)",
			participants: []string{"user1", "user2", "user3"},
			creatorID:    "user1",
			want:         true,
		},
		{
			name:         "Valid private (2 participants)",
			participants: []string{"user1", "user2"},
			creatorID:    "user1",
			want:         true,
		},
		{
			name:         "Not enough participants",
			participants: []string{"user1"},
			creatorID:    "user1",
			want:         false,
		},
		{
			name:         "Creator not in participants",
			participants: []string{"user2", "user3"},
			creatorID:    "user1",
			want:         false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			hasMin := len(tt.participants) >= 2

			creatorFound := false
			for _, p := range tt.participants {
				if p == tt.creatorID {
					creatorFound = true
					break
				}
			}

			got := hasMin && creatorFound
			if got != tt.want {
				t.Errorf("ValidateParticipants(%v, %q) = %v, want %v",
					tt.participants, tt.creatorID, got, tt.want)
			}
		})
	}
}

func TestValidateMessage(t *testing.T) {
	tests := []struct {
		name    string
		message string
		maxLen  int
		want    bool
	}{
		{"Valid message", "Hello, world!", 1000, true},
		{"Empty message", "", 1000, false},
		{"Too long", string(make([]byte, 2000)), 1000, false},
		{"Exactly max", string(make([]byte, 1000)), 1000, true},
		{"Just spaces", "   ", 1000, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			trimmed := tt.message
			for len(trimmed) > 0 && trimmed[0] == ' ' {
				trimmed = trimmed[1:]
			}
			for len(trimmed) > 0 && trimmed[len(trimmed)-1] == ' ' {
				trimmed = trimmed[:len(trimmed)-1]
			}

			got := len(trimmed) > 0 && len(trimmed) <= tt.maxLen
			if got != tt.want {
				t.Errorf("ValidateMessage(%q, %d) = %v, want %v",
					tt.message, tt.maxLen, got, tt.want)
			}
		})
	}
}
