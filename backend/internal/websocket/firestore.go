package websocket

import (
	"context"
	"fmt"
	"log"
	"time"

	"cloud.google.com/go/firestore"
)

func (s *Server) setupUserListeners(userID string) {
	chats, err := s.getUserChats(userID)
	if err != nil {
		log.Printf("Failed to get chats for users %s: %v", userID, err)
	}

	for _, chatID := range chats {
		s.startChatListener(chatID)
	}
}

func (s *Server) stopUserListeners(userID string) {

}

func (s *Server) startChatListener(chatID string) {
	s.mu.Lock()
	if _, exists := s.chatListeners[chatID]; exists {
		s.mu.Unlock()
		return
	}
	s.mu.Unlock()

	ctx, cancel := context.WithCancel(context.Background())

	s.mu.Lock()
	s.chatListeners[chatID] = cancel
	s.mu.Unlock()

	go s.listenToChatMessages(ctx, chatID)
}

func (s *Server) listenToChatMessages(ctx context.Context, chatID string) {
	defer func() {
		s.mu.Lock()
		delete(s.chatListeners, chatID)
		s.mu.Unlock()
	}()

	query := s.db.Firestore.Collection("chats").Doc(chatID).
		Collection("messages").
		OrderBy("timestamp", firestore.Desc).Limit(1)

	snapshot := query.Snapshots(ctx)

	for {
		select {
		case <-ctx.Done():
			log.Printf("Stopped listener for chat %s", chatID)
			return
		default:
			iter, err := snapshot.Next()
			if err != nil {
				log.Printf("Error in chat %s listener: %v", chatID, err)
				time.Sleep(5 * time.Second)
				continue
			}

			for _, change := range iter.Changes {
				if change.Kind == firestore.DocumentAdded {
					messageData := change.Doc.Data()
					s.broadcastNewMessage(chatID, messageData)
				}
			}
		}
	}
}

func (s *Server) broadcastNewMessage(chatID string, messageData map[string]interface{}) {
	senderID, _ := messageData["sender_id"].(string)

	event := WSEvent{
		Type:   "new_message",
		ChatID: chatID,
		Data:   messageData,
	}

	sent, err := s.BroadcastToChat(chatID, event, senderID)
	if err != nil {
		log.Printf("Failed to broadcast message in chat %s: %v", chatID, err)
		return
	}

	log.Printf("Broadcasted message in chat %s to %d users", chatID, sent)
}

func (s *Server) getUserChats(userID string) ([]string, error) {
	ctx := context.Background()

	docs, err := s.db.Firestore.Collection("chats").
		Where("participants", "array-contains", userID).
		Documents(ctx).GetAll()

	if err != nil {
		return nil, fmt.Errorf("failed to get user chats: %v", err)
	}

	chatIDs := make([]string, len(docs))
	for i, doc := range docs {
		chatIDs[i] = doc.Ref.ID
	}

	return chatIDs, nil
}

func (s *Server) getChatParticipants(chatID string) ([]string, error) {
	ctx := context.Background()

	doc, err := s.db.Firestore.Collection("chats").Doc(chatID).Get(ctx)
	if err != nil {
		return nil, fmt.Errorf("chat not found: %v", err)
	}

	data := doc.Data()
	participantsInterface, ok := data["participants"].([]interface{})
	if !ok {
		return nil, fmt.Errorf("invalid participants format")
	}

	participants := make([]string, len(participantsInterface))
	for i, p := range participantsInterface {
		if str, ok := p.(string); ok {
			participants[i] = str
		}
	}

	return participants, nil
}

func (s *Server) isUserInChat(userID, chatID string) (bool, error) {
	participants, err := s.getChatParticipants(chatID)
	if err != nil {
		return false, err
	}

	for _, participant := range participants {
		if participant == userID {
			return true, nil
		}
	}

	return false, nil
}
