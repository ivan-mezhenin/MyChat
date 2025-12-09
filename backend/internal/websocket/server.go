package websocket

import (
	"MyChatServer/internal/database"
	"context"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

func NewServer(db *database.Client) *Server {
	return &Server{
		clients:       make(map[string]*Client),
		chatListeners: make(map[string]context.CancelFunc),
		mu:            &sync.RWMutex{},
		db:            db,
		upgrader: &websocket.Upgrader{
			ReadBufferSize:  1024,
			WriteBufferSize: 1024,
		},
	}
}

func (s *Server) HandleConnection(w http.ResponseWriter, r *http.Request) {
	token := r.URL.Query().Get("token")
	if token == "" {
		http.Error(w, "Token required", http.StatusUnauthorized)
		return
	}

	ctx := r.Context()
	userUID, err := s.db.ValidateIdToken(ctx, token)
	if err != nil {
		http.Error(w, "Invalid token", http.StatusUnauthorized)
		return
	}

	connection, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		http.Error(w, "Failed to upgrade to WebSocket", http.StatusBadRequest)
		return
	}
	defer connection.Close()

	client := &Client{
		Connection: connection,
		UserID:     userUID,
		LastSeen:   time.Now(),
	}

	s.mu.Lock()
	s.clients[userUID] = client
	s.mu.Unlock()

	go s.setupUserListeners(userUID)

	s.handleClientMessages(client)

	s.mu.Lock()
	delete(s.clients, userUID)
	s.mu.Unlock()

	s.stopUserListeners(userUID)
}

func (s *Server) SendToUser(userID string, event WSEvent) error {
	s.mu.RLock()
	client, exists := s.clients[userID]
	s.mu.RUnlock()

	if !exists {
		return fmt.Errorf("user %s not connected", userID)
	}

	client.LastSeen = time.Now()
	return client.Connection.WriteJSON(event)
}

func (s *Server) BroadcastToChat(chatID string, event WSEvent, excludeUserID string) (int, error) {
	participants, err := s.getChatParticipants(chatID)
	if err != nil {
		return 0, fmt.Errorf("failed to get chat participants: %v", err)
	}

	sentCount := 0
	s.mu.RLock()
	defer s.mu.RUnlock()

	for _, userID := range participants {
		if userID == excludeUserID {
			continue
		}

		if client, exists := s.clients[userID]; exists {
			if err := client.Connection.WriteJSON(event); err != nil {
				log.Printf("Failed to send to user %s: %v", userID, err)
				continue
			}
			sentCount++
		}
	}

	return sentCount, nil
}

func (s *Server) handleClientMessages(client *Client) {
	for {
		var event WSEvent
		if err := client.Connection.ReadJSON(&event); err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway) {
				log.Printf("WebSocket read error from user %s: %v", client.UserID, err)
			}
			break
		}

		client.LastSeen = time.Now()

		s.handleIncomingEvent(client.UserID, event)
	}
}

func (s *Server) handleIncomingEvent(userID string, event WSEvent) {
	switch event.Type {
	case "send_message":
		s.handleSendMessage(userID, event)
	case "typing":
		s.handleTyping(userID, event)
	case "message_read":
		s.handleMessageRead(userID, event)
	default:
		log.Printf("Unknown event type from user %s: %s", userID, event.Type)
	}
}

func (s *Server) GetConnectedUsers() []string {
	s.mu.RLock()
	defer s.mu.RUnlock()

	users := make([]string, 0, len(s.clients))
	for userID := range s.clients {
		users = append(users, userID)
	}

	return users
}

func (s *Server) Stop() {
	s.mu.Lock()
	defer s.mu.Unlock()

	for chatID, cancel := range s.chatListeners {
		cancel()
		delete(s.chatListeners, chatID)
	}

	for userID, client := range s.clients {
		client.Connection.Close()
		delete(s.clients, userID)
	}
}
