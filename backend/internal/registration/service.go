package registration

import (
	"context"
	"fmt"
	"time"

	"MyChatServer/internal/database"
)

type Service struct {
	db *database.Client
}

type RegisterRequest struct {
	Username string `json:"username"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

type RegisterResponse struct {
	UserID string `json:"user_id"`
	Email  string `json:"email"`
	Name   string `json:"name"`
}

func NewService(db *database.Client) *Service {
	return &Service{db: db}
}

func (s *Service) Register(ctx context.Context, req *RegisterRequest) (*RegisterResponse, error) {
	authUser, err := s.db.CreateUserInAuth(ctx, req.Email, req.Password, req.Username)
	if err != nil {
		return nil, fmt.Errorf("failed to create user: %v", err)
	}

	userProfile := &database.User{
		UID:       authUser.UID,
		Name:      req.Username,
		Email:     req.Email,
		CreatedAt: time.Now(),
		IsBanned:  false,
	}

	err = s.db.SaveUserInFirestore(ctx, userProfile)
	if err != nil {
		s.db.DeleteAuthUser(ctx, authUser.UID)
		return nil, fmt.Errorf("failed to save user profile: %v", err)
	}

	return &RegisterResponse{
		UserID: authUser.UID,
		Email:  authUser.Email,
		Name:   req.Username,
	}, nil
}
