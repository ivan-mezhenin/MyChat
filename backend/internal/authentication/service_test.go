package authentication

import (
	"context"
	"testing"
)

func TestLoginLogic(t *testing.T) {
	mockDB := NewMockDB()

	mockDB.AddUser("user123", "test@example.com", "Test User")

	ctx := context.Background()

	t.Run("Get user by email", func(t *testing.T) {
		user, err := mockDB.GetUserByEmail(ctx, "test@example.com")
		if err != nil {
			t.Fatalf("Failed to get user: %v", err)
		}
		if user == nil {
			t.Fatal("User not found")
		}
		if user.Email != "test@example.com" {
			t.Errorf("Expected email test@example.com, got %s", user.Email)
		}
		if user.UID != "user123" {
			t.Errorf("Expected UID user123, got %s", user.UID)
		}
	})

	t.Run("Get nonexistent user", func(t *testing.T) {
		user, err := mockDB.GetUserByEmail(ctx, "nonexistent@example.com")
		if err != nil {
			t.Fatalf("Unexpected error: %v", err)
		}
		if user != nil {
			t.Error("Expected nil user for nonexistent email")
		}
	})

	t.Run("Validate token", func(t *testing.T) {
		uid, err := mockDB.ValidateIdToken(ctx, "valid_token_user123")
		if err != nil {
			t.Fatalf("Failed to validate token: %v", err)
		}
		if uid != "user123" {
			t.Errorf("Expected UID user123, got %s", uid)
		}
	})
}
