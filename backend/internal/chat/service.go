package chat

import (
	"context"
	"fmt"
	"time"

	"MyChatServer/internal/database"

	"cloud.google.com/go/firestore"
)

type Service struct {
	db *database.Client
}

type MessageResponse struct {
	ID        string    `json:"id"`
	ChatID    string    `json:"chat_id"`
	SenderID  string    `json:"sender_id"`
	Text      string    `json:"text"`
	Timestamp time.Time `json:"timestamp"`
}

func NewService(db *database.Client) *Service {
	return &Service{db: db}
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
