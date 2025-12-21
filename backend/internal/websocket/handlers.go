package websocket

import (
	"context"
	"fmt"
	"log"
	"time"

	"cloud.google.com/go/firestore"
)

func (s *Server) handleSendMessage(userID string, event WSEvent) {
	data, ok := event.Data.(map[string]interface{})
	if !ok {
		log.Printf("Invalid message data from user %s", userID)
		s.SendToUser(userID, WSEvent{
			Type: "error",
			Data: map[string]string{"error": "Invalid message format"},
		})
		return
	}

	chatID, chatOK := data["chat_id"].(string)
	text, textOK := data["text"].(string)

	if !chatOK || !textOK || chatID == "" || text == "" {
		s.SendToUser(userID, WSEvent{
			Type: "error",
			Data: map[string]string{"error": "chat_id and text are required"},
		})
		return
	}

	isParticipant, err := s.isUserInChat(userID, chatID)
	if err != nil || !isParticipant {
		log.Printf("User %s is not in chat %s", userID, chatID)
		s.SendToUser(userID, WSEvent{
			Type: "error",
			Data: map[string]string{"error": "Not a chat participant"},
		})
		return
	}

	messageID, err := s.saveMessageToFirestore(chatID, userID, text)
	if err != nil {
		log.Printf("Failed to save message from user %s: %v", userID, err)
		s.SendToUser(userID, WSEvent{
			Type: "error",
			Data: map[string]string{"error": "Failed to send message"},
		})
		return
	}

	log.Printf("User %s sent message to chat %s: %s", userID, chatID, text)

	s.SendToUser(userID, WSEvent{
		Type: "message_sent",
		Data: map[string]string{
			"message_id": messageID,
			"chat_id":    chatID,
		},
	})

	messageData := map[string]interface{}{
		"id":        messageID,
		"chat_id":   chatID,
		"sender_id": userID,
		"text":      text,
		"timestamp": time.Now(),
	}

	broadcastEvent := WSEvent{
		Type:   "new_message",
		ChatID: chatID,
		Data:   messageData,
	}

	s.BroadcastToChat(chatID, broadcastEvent, userID)

}

func (s *Server) saveMessageToFirestore(chatID, userID, text string) (string, error) {
	ctx := context.Background()

	message := map[string]interface{}{
		"sender_id": userID,
		"text":      text,
		"timestamp": firestore.ServerTimestamp,
		"read_by":   []string{userID},
	}

	docRef, _, err := s.db.Firestore.Collection("chats").Doc(chatID).
		Collection("messages").Add(ctx, message)

	if err != nil {
		return "", fmt.Errorf("failed to save message: %v", err)
	}

	_, err = s.db.Firestore.Collection("chats").Doc(chatID).Update(ctx, []firestore.Update{
		{
			Path:  "last_message",
			Value: message,
		},
		{
			Path:  "updated_at",
			Value: firestore.ServerTimestamp,
		},
	})

	if err != nil {
		log.Printf("Failed to update last_message: %v", err)
	}

	return docRef.ID, nil
}

func (s *Server) handleTyping(userID string, event WSEvent) {
	data, ok := event.Data.(map[string]interface{})
	if !ok {
		return
	}

	chatID, chatOK := data["chat_id"].(string)
	isTyping, typingOK := data["is_typing"].(bool)

	if !chatOK || !typingOK {
		return
	}

	isParticipant, err := s.isUserInChat(userID, chatID)
	if err != nil || !isParticipant {
		return
	}

	typingEvent := WSEvent{
		Type:   "user_typing",
		ChatID: chatID,
		UserID: userID,
		Data: map[string]interface{}{
			"user_id":   userID,
			"chat_id":   chatID,
			"is_typing": isTyping,
		},
	}

	s.BroadcastToChat(chatID, typingEvent, userID)
}

func (s *Server) handleMessageRead(userID string, event WSEvent) {
	data, ok := event.Data.(map[string]interface{})
	if !ok {
		return
	}

	chatID, chatOK := data["chat_id"].(string)
	messageID, msgOK := data["message_id"].(string)

	if !chatOK || !msgOK {
		return
	}

	isParticipant, err := s.isUserInChat(userID, chatID)
	if err != nil || !isParticipant {
		return
	}

	ctx := context.Background()
	messageRef := s.db.Firestore.Collection("chats").Doc(chatID).
		Collection("messages").Doc(messageID)

	_, err = messageRef.Update(ctx, []firestore.Update{
		{
			Path:  "read_by",
			Value: firestore.ArrayUnion(userID),
		},
	})

	if err != nil {
		log.Printf("Failed to mark message as read: %v", err)
	}
}

func (s *Server) handlePing(userID string, event WSEvent) {
	s.SendToUser(userID, WSEvent{
		Type: "pong",
		Data: event.Data,
	})
}
