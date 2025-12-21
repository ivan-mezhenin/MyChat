package main

import (
	"context"
	"log"
	"os"

	"MyChatServer/internal/authentication"
	"MyChatServer/internal/chat"
	"MyChatServer/internal/contact"
	"MyChatServer/internal/database"
	"MyChatServer/internal/registration"
	"MyChatServer/internal/websocket"

	"github.com/labstack/echo"
	"github.com/labstack/echo/middleware"
)

func main() {
	ctx := context.Background()

	apiKey := os.Getenv("FIREBASE_API_KEY")
	if apiKey == "" {
		log.Fatal("FIREBASE_API_KEY environment variable is required")
	}

	db, err := database.NewClient(ctx, "myChatAdminKey.json", apiKey)
	if err != nil {
		log.Fatalf("Failed to initialize Firebase: %v", err)
	}
	defer db.Close()

	log.Println("Firebase connected successfully!")

	wsServer := websocket.NewServer(db)

	e := echo.New()

	e.Use(middleware.CORS())
	e.Use(middleware.Logger())

	e.GET("/ws", func(c echo.Context) error {
		wsServer.HandleConnection(c.Response(), c.Request())
		return nil
	})

	regService := registration.NewService(db)
	regHandler := registration.NewHandler(regService)
	e.POST("/api/auth/register", regHandler.RegisterHandler)

	authService := authentication.NewService(db)
	authHandler := authentication.NewHandler(authService)
	e.POST("/api/auth/login", authHandler.LoginHandler)
	e.GET("/api/auth/initial-data", authHandler.VerifyAndGetChatsHandler)

	chatService := chat.NewService(db, wsServer)
	chatHandler := chat.NewHandler(chatService)
	e.GET("/api/chats/:chatId/messages", chatHandler.GetMessages)

	contactService := contact.NewContactService(db)
	contactHandler := contact.NewContactHandler(contactService)

	e.GET("/api/contacts", contactHandler.GetContacts)
	e.POST("/api/contacts", contactHandler.AddContact)
	e.DELETE("/api/contacts/:contactId", contactHandler.DeleteContact)
	e.GET("/api/contacts/search", contactHandler.SearchUsers)
	e.GET("/api/chats/contacts", chatHandler.GetUserContacts)

	e.POST("/api/chats/create-from-contacts", chatHandler.CreateChatFromContacts)
	e.POST("/api/chats/create-private/:contactId", chatHandler.CreatePrivateChat)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server starting on :%s", port)
	e.Start("0.0.0.0:" + port)
}
