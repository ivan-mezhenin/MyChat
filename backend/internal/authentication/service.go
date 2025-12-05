package authentication

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"MyChatServer/internal/database"
)

type Service struct {
	db *database.Client
}

type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type LoginResponse struct {
	Token string         `json:"token"`
	User  UserResponse   `json:"user"`
	Chats []ChatResponse `json:"chats"`
}

type FirebaseAuthResponse struct {
	IDToken      string `json:"idToken"`
	RefreshToken string `json:"refreshToken"`
	ExpiresIn    string `json:"expiresIn"`
	LocalID      string `json:"localId"`
	Email        string `json:"email"`
}

type AuthResponse struct {
	User  UserResponse   `json:"user"`
	Chats []ChatResponse `json:"chats"`
	Token string         `json:"token"`
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

func (s *Service) FirebaseLogin(ctx context.Context, email, password string) (*FirebaseAuthResponse, error) {
	url := fmt.Sprintf("https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=%s", s.db.APIKey)

	payload := map[string]interface{}{
		"email":             email,
		"password":          password,
		"returnSecureToken": true,
	}

	payloadBytes, _ := json.Marshal(payload)

	req, err := http.NewRequestWithContext(ctx, "POST", url, strings.NewReader(string(payloadBytes)))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to call Firebase API: %v", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %v", err)
	}

	if resp.StatusCode != 200 {
		var errorResp struct {
			Error struct {
				Message string `json:"message"`
				Code    int    `json:"code"`
			} `json:"error"`
		}
		json.Unmarshal(body, &errorResp)
		return nil, fmt.Errorf("firebase auth error: %s (code: %d)", errorResp.Error.Message, errorResp.Error.Code)
	}

	var authResp FirebaseAuthResponse
	if err := json.Unmarshal(body, &authResp); err != nil {
		return nil, fmt.Errorf("failed to parse response: %v", err)
	}

	return &authResp, nil
}

func (s *Service) Login(ctx context.Context, email, password string) (*AuthResponse, error) {
	firebaseResponse, err := s.FirebaseLogin(ctx, email, password)
	if err != nil {
		return nil, fmt.Errorf("authentication failed: %v", err)
	}

	_, err = s.db.Auth.VerifyIDToken(ctx, firebaseResponse.IDToken)
	if err != nil {
		return nil, fmt.Errorf("token verification failed: %v", err)
	}

	user, err := s.getUserData(ctx, firebaseResponse.LocalID)
	if err != nil {
		return nil, fmt.Errorf("failed to get user data: %v", err)
	}

	chats, err := s.getUserChats(ctx, firebaseResponse.LocalID)
	if err != nil {
		return nil, fmt.Errorf("failed to get user chats: %v", err)
	}

	return &AuthResponse{
		User:  user,
		Chats: chats,
		Token: firebaseResponse.IDToken,
	}, nil
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
