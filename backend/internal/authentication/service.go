package authentication

import (
	"context"
	"fmt"
	"time"

	"MyChatServer/internal/database"
)

type Service struct {
	db *database.Client
}

type AuthResponse struct {
	User  UserResponse   `json:"user"`
	Chats []ChatResponse `json:"chats"`
}

type UserResponse struct {
	UID   string `json:"uid"`
	Name  string `json:"name"`
	Email string `json:"email"`
}

type ChatResponse struct {
	ID              string    `json:"id"`
	Name            string    `json:"name"`
	Type            string    `json:"type"`
	LastMessage     string    `json:"last_message,omitempty"`
	LastMessageTime time.Time `json:"last_message_time,omitempty"`
}

func NewService(db *database.Client) *Service {
	return &Service{db: db}
}

func (s *Service) VerifyAndGetChats(ctx context.Context, idToken string) (*AuthResponse, error) {
	userUID, err := s.db.ValidateIdToken(ctx, idToken)
	if err != nil {
		return nil, fmt.Errorf("authentication failed: %v: ", err)
	}

	user, err := s.getUserData(ctx, userUID)
	if err != nil {
		return nil, fmt.Errorf("failed to get user data: %v", err)
	}

	chats, err := s.getUserChats(ctx, userUID)
	if err != nil {
		return nil, fmt.Errorf("failed to get user chats: %v", err)
	}

	return &AuthResponse{
		User:  user,
		Chats: chats,
	}, nil
}

func (s *Service) getUserData(ctx context.Context, userUID string) (UserResponse, error) {
	doc, err := s.db.Firestore.Collection("users").Doc(userUID).Get(ctx)
	if err != nil {
		return UserResponse{}, err
	}

	var user database.User
	if err := doc.DataTo(&user); err != nil {
		return UserResponse{}, err
	}

	return UserResponse{
		UID:   user.UID,
		Name:  user.Name,
		Email: user.Email,
	}, nil
}

func (s *Service) getUserChats(ctx context.Context, userUID string) ([]ChatResponse, error) {
	docs, err := s.db.Firestore.Collection("chats").Where("participants", "array-contains", userUID).Documents(ctx).GetAll()
	if err != nil {
		return nil, err
	}

	chats := make([]ChatResponse, len(docs))

	for i, doc := range docs {
		data := doc.Data()

		chat := ChatResponse{
			ID:   doc.Ref.ID,
			Name: data["name"].(string),
			Type: data["type"].(string),
		}

		if lastMessage, ok := data["last_message"].(map[string]interface{}); ok {
			if text, ok := lastMessage["text"].(string); ok {
				chat.LastMessage = text
			}
			if timestamp, ok := lastMessage["timestamp"].(time.Time); ok {
				chat.LastMessageTime = timestamp
			}
		}

		chats[i] = chat
	}

	return chats, nil
}
