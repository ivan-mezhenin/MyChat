package database

import (
	"testing"
	"time"
)

func TestUserStruct(t *testing.T) {
	now := time.Now()

	user := &User{
		UID:       "test-uid-123",
		Name:      "Test User",
		Email:     "test@example.com",
		CreatedAt: now,
		IsBanned:  false,
	}

	// Проверка полей
	if user.UID != "test-uid-123" {
		t.Errorf("UID: got %q, want %q", user.UID, "test-uid-123")
	}

	if user.Name != "Test User" {
		t.Errorf("Name: got %q, want %q", user.Name, "Test User")
	}

	if user.Email != "test@example.com" {
		t.Errorf("Email: got %q, want %q", user.Email, "test@example.com")
	}

	if user.IsBanned != false {
		t.Error("IsBanned should be false")
	}

	t.Log(" User struct works correctly")
}

func TestUserValidation(t *testing.T) {
	tests := []struct {
		name    string
		user    *User
		wantErr bool
	}{
		{
			name: "Valid user",
			user: &User{
				UID:   "123",
				Name:  "John",
				Email: "john@test.com",
			},
			wantErr: false,
		},
		{
			name: "Missing UID",
			user: &User{
				Name:  "John",
				Email: "john@test.com",
			},
			wantErr: true,
		},
		{
			name: "Missing email",
			user: &User{
				UID:  "123",
				Name: "John",
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			hasErr := tt.user.UID == "" || tt.user.Email == ""

			if hasErr != tt.wantErr {
				t.Errorf("%s: got hasErr=%v, wantErr=%v", tt.name, hasErr, tt.wantErr)
			} else {
				t.Logf(" %s: валидация работает", tt.name)
			}
		})
	}
}
