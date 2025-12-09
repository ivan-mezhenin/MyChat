package main

import (
	"context"
	"log"
	"os"

	"MyChatServer/internal/authentication"
	"MyChatServer/internal/database"
	"MyChatServer/internal/registration"
	"MyChatServer/internal/websocket"

	"github.com/labstack/echo"
	"github.com/labstack/echo/middleware"
)

func main() {
	ctx := context.Background()

	db, err := database.NewClient(ctx, "myChatAdminKey.json")
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

	e.GET("/api/auth/initial-data", authHandler.VerifyAndGetChatsHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	e.Start("0.0.0.0:8080")

	log.Printf("Server starting on :%s", port)
}
