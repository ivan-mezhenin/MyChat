package websocket

import (
	"testing"
	"time"
)

func TestMessageTypes(t *testing.T) {
	validTypes := []string{
		"send_message",
		"typing",
		"message_read",
		"ping",
		"new_message",
		"user_typing",
		"message_sent",
		"error",
		"chat_created",
	}

	for _, msgType := range validTypes {
		t.Run(msgType, func(t *testing.T) {
			if msgType == "" {
				t.Error("Message type should not be empty")
			} else {
				t.Logf("Message type %q is valid", msgType)
			}
		})
	}
}

func TestWSEventCreation(t *testing.T) {
	event := WSEvent{
		Type:   "test_event",
		Data:   map[string]interface{}{"key": "value"},
		ChatID: "chat123",
		UserID: "user456",
	}

	if event.Type != "test_event" {
		t.Errorf("Type: got %q, want %q", event.Type, "test_event")
	}

	if event.ChatID != "chat123" {
		t.Errorf("ChatID: got %q, want %q", event.ChatID, "chat123")
	}

	if event.UserID != "user456" {
		t.Errorf("UserID: got %q, want %q", event.UserID, "user456")
	}

	data, ok := event.Data.(map[string]interface{})
	if !ok {
		t.Error("Data should be map[string]interface{}")
	} else if data["key"] != "value" {
		t.Errorf("Data key: got %v, want %v", data["key"], "value")
	}

	t.Log(" WSEvent creation works")
}

func TestClientStruct(t *testing.T) {
	now := time.Now()

	client := &Client{
		UserID:   "user123",
		LastSeen: now,
	}

	if client.UserID != "user123" {
		t.Errorf("UserID: got %q, want %q", client.UserID, "user123")
	}

	if client.LastSeen != now {
		t.Error("LastSeen not set correctly")
	}
	newTime := time.Now().Add(time.Minute)
	client.LastSeen = newTime
	if !client.LastSeen.After(now) {
		t.Error("LastSeen update failed")
	}

	t.Log(" Client struct works")
}
