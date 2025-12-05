package main

import (
	"context"
	"log"
	"os"

	"MyChatServer/internal/authentication"
	"MyChatServer/internal/chat"
	"MyChatServer/internal/database"
	"MyChatServer/internal/registration"

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

	e := echo.New()

	e.Use(middleware.CORS())
	e.Use(middleware.Logger())

	regService := registration.NewService(db)
	regHandler := registration.NewHandler(regService)

	e.POST("/api/auth/register", regHandler.RegisterHandler)

	authService := authentication.NewService(db)
	authHandler := authentication.NewHandler(authService)

	e.POST("/api/auth/login", authHandler.LoginHandler)
	e.GET("/api/auth/initial-data", authHandler.VerifyAndGetChatsHandler)

	chatService := chat.NewService(db)
	chatHandler := chat.NewHandler(chatService)
	e.GET("/api/chats/:chatId/messages", chatHandler.GetMessages)
	e.POST("/api/chats/:chatId/messages", chatHandler.SendMessage)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	e.Start("0.0.0.0:8080")

	log.Printf("Server starting on :%s", port)
}
