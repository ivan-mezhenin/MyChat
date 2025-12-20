package chat

import (
	"context"
	"fmt"
	"time"

	"MyChatServer/internal/database"
	"MyChatServer/internal/websocket"

	"cloud.google.com/go/firestore"
)

type Service struct {
	db       *database.Client
	wsServer *websocket.Server
}

type MessageResponse struct {
	ID        string    `json:"id"`
	ChatID    string    `json:"chat_id"`
	SenderID  string    `json:"sender_id"`
	Text      string    `json:"text"`
	Timestamp time.Time `json:"timestamp"`
}

func NewService(db *database.Client, wsServer *websocket.Server) *Service {
	return &Service{db: db,
		wsServer: wsServer,
	}
}

func (s *Service) ValidateToken(ctx context.Context, idToken string) (string, error) {
	return s.db.ValidateIdToken(ctx, idToken)
}

func (s *Service) GetMessages(ctx context.Context, chatID, userID string) ([]MessageResponse, error) {
	isParticipant, err := s.isChatParticipant(ctx, chatID, userID)
	if !isParticipant || err != nil {
		return nil, fmt.Errorf("access denied or chat not found")
	}

	docs, err := s.db.Firestore.Collection("chats").
		Doc(chatID).
		Collection("messages").
		OrderBy("timestamp", firestore.Asc).
		Documents(ctx).GetAll()

	if err != nil {
		return nil, err
	}

	messages := make([]MessageResponse, len(docs))
	for i, doc := range docs {
		data := doc.Data()

		messages[i] = MessageResponse{
			ID:        doc.Ref.ID,
			ChatID:    chatID,
			SenderID:  data["sender_id"].(string),
			Text:      data["text"].(string),
			Timestamp: data["timestamp"].(time.Time),
		}
	}

	return messages, nil
}

func (s *Service) isChatParticipant(ctx context.Context, chatID, userID string) (bool, error) {
	doc, err := s.db.Firestore.Collection("chats").Doc(chatID).Get(ctx)
	if err != nil {
		return false, err
	}

	data := doc.Data()
	participants, ok := data["participants"].([]interface{})
	if !ok {
		return false, nil
	}

	for _, p := range participants {
		if p.(string) == userID {
			return true, nil
		}
	}

	return false, nil
}

func (s *Service) createSimpleChat(ctx context.Context, creatorID, chatName string, emails []string, chatType string) (string, error) {
	participants := []string{creatorID}

	for _, email := range emails {
		if email == "" {
			continue
		}

		user, err := s.db.GetUserByEmail(ctx, email)
		if err != nil {
			continue
		}

		found := false
		for _, p := range participants {
			if p == user.UID {
				found = true
				break
			}
		}

		if !found {
			participants = append(participants, user.UID)
		}
	}

	if len(participants) < 2 {
		return "", fmt.Errorf("need at least 2 participants")
	}

	return s.createChatDocument(ctx, creatorID, chatName, participants, chatType)
}

func (s *Service) createChatDocument(ctx context.Context, creatorID, chatName string, participants []string, chatType string) (string, error) {
	now := time.Now()

	chatData := map[string]interface{}{
		"name":         chatName,
		"type":         chatType,
		"participants": participants,
		"created_by":   creatorID,
		"created_at":   now,
		"updated_at":   now,
	}

	docRef, _, err := s.db.Firestore.Collection("chats").Add(ctx, chatData)
	if err != nil {
		return "", fmt.Errorf("failed to create chat: %v", err)
	}

	_, err = docRef.Collection("messages").Doc("welcome").Set(ctx, map[string]interface{}{
		"sender_id": "system",
		"text":      fmt.Sprintf("Chat '%s' created", chatName),
		"timestamp": now,
	})

	return docRef.ID, err
}

func (s *Service) getUserProfile(ctx context.Context, userID string) (*database.User, error) {
	doc, err := s.db.Firestore.Collection("users").Doc(userID).Get(ctx)
	if err != nil {
		return nil, err
	}

	var user database.User
	if err := doc.DataTo(&user); err != nil {
		return nil, err
	}

	return &user, nil
}

func (s *Service) findExistingPrivateChat(ctx context.Context, userID1, userID2 string) (string, error) {
	docs, err := s.db.Firestore.Collection("chats").
		Where("type", "==", "private").
		Where("participants", "array-contains", userID1).
		Documents(ctx).GetAll()

	if err != nil {
		return "", err
	}

	for _, doc := range docs {
		data := doc.Data()
		participants, ok := data["participants"].([]interface{})
		if !ok {
			continue
		}

		hasUser1 := false
		hasUser2 := false

		for _, p := range participants {
			if pStr, ok := p.(string); ok {
				if pStr == userID1 {
					hasUser1 = true
				}
				if pStr == userID2 {
					hasUser2 = true
				}
			}
		}

		if hasUser1 && hasUser2 && len(participants) == 2 {
			return doc.Ref.ID, nil
		}
	}

	return "", nil
}
