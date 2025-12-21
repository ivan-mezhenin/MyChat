package websocket

import (
	"MyChatServer/internal/database"
	"context"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

type WSEvent struct {
	Type   string      `json:"type"`
	Data   interface{} `json:"data"`
	ChatID string      `json:"chat_id,omitempty"`
	UserID string      `json:"user_id,omitempty"`
}

type Client struct {
	Connection *websocket.Conn
	UserID     string
	LastSeen   time.Time
}

type Server struct {
	mu            *sync.RWMutex
	clients       map[string]*Client
	chatListeners map[string]context.CancelFunc
	upgrader      *websocket.Upgrader
	db            *database.Client
}

type Message struct {
	ID        string    `json:"id"`
	ChatID    string    `json:"chat_id"`
	SenderID  string    `json:"sender_id"`
	Text      string    `json:"text"`
	Timestamp time.Time `json:"timestamp"`
}

type ChatCreatedEvent struct {
	ChatID       string    `json:"chat_id"`
	ChatName     string    `json:"chat_name"`
	ChatType     string    `json:"chat_type"`
	CreatedBy    string    `json:"created_by"`
	CreatedAt    time.Time `json:"created_at"`
	Participants []string  `json:"participants"`
}

type ChatEvent struct {
	Type   string      `json:"type"`
	ChatID string      `json:"chat_id,omitempty"`
	UserID string      `json:"user_id,omitempty"`
	Data   interface{} `json:"data"`
}
