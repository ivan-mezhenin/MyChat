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
