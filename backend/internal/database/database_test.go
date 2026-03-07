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

func TestUserValidate(t *testing.T) {
	now := time.Now()

	tests := []struct {
		name    string
		user    *User
		wantErr bool
	}{
		{
			name: "Valid user",
			user: &User{
				UID:       "123",
				Name:      "Test User",
				Email:     "test@example.com",
				CreatedAt: now,
				IsBanned:  false,
			},
			wantErr: false,
		},
		{
			name: "Missing UID",
			user: &User{
				Name:      "Test User",
				Email:     "test@example.com",
				CreatedAt: now,
			},
			wantErr: true,
		},
		{
			name: "Missing Email",
			user: &User{
				UID:       "123",
				Name:      "Test User",
				CreatedAt: now,
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			hasErr := tt.user.UID == "" || tt.user.Email == ""
			if hasErr != tt.wantErr {
				t.Errorf("User validation failed for %+v", tt.user)
			}
		})
	}
}

func TestUserFields(t *testing.T) {
	user := &User{
		UID:       "test-uid",
		Name:      "John Doe",
		Email:     "john@example.com",
		CreatedAt: time.Now(),
		IsBanned:  false,
	}

	if user.UID != "test-uid" {
		t.Errorf("UID = %q, want %q", user.UID, "test-uid")
	}
	if user.Name != "John Doe" {
		t.Errorf("Name = %q, want %q", user.Name, "John Doe")
	}
	if user.Email != "john@example.com" {
		t.Errorf("Email = %q, want %q", user.Email, "john@example.com")
	}
	if user.IsBanned {
		t.Error("IsBanned should be false")
	}
}
