package authentication

import (
	"MyChatServer/internal/database"
	"context"
	"time"
)

// MockDB реализует методы database.Client, которые нужны Service
type MockDB struct {
	users map[string]*database.User
}

func NewMockDB() *MockDB {
	return &MockDB{
		users: make(map[string]*database.User),
	}
}

// Реализуем метод ValidateIdToken, который ожидает Service
func (m *MockDB) ValidateIdToken(ctx context.Context, idToken string) (string, error) {
	// Для тестов просто возвращаем UID из токена
	// Например, если токен = "valid_token_user123", вернем "user123"
	if len(idToken) > 12 && idToken[:12] == "valid_token_" {
		return idToken[12:], nil
	}
	return "", nil
}

// Реализуем метод GetUserByEmail
func (m *MockDB) GetUserByEmail(ctx context.Context, email string) (*database.User, error) {
	for _, user := range m.users {
		if user.Email == email {
			return user, nil
		}
	}
	return nil, nil
}

// Реализуем метод GetUserByID (если он используется)
func (m *MockDB) GetUserByID(ctx context.Context, uid string) (*database.User, error) {
	user, exists := m.users[uid]
	if !exists {
		return nil, nil
	}
	return user, nil
}

// Добавляем пользователя в мок
func (m *MockDB) AddUser(uid, email, name string) {
	m.users[uid] = &database.User{
		UID:       uid,
		Email:     email,
		Name:      name,
		CreatedAt: time.Now(),
		IsBanned:  false,
	}
}
