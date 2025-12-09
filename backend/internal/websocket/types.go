package websocket

import (
	"github.com/gorilla/websocket"
)

type WSEvent struct {
	Type   string      `json:"type"`
	Data   interface{} `json:"data"`
	ChatID string      `json:"chat_id"`
}

type Client struct {
	Connection *websocket.Conn
	UserID     string
}
