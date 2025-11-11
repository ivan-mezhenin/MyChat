package main

import (
	"context"
	"log"
	"os"

	"MyChatServer/internal/authentication"
	"MyChatServer/internal/database"

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

	e := echo.New()

	e.Use(middleware.CORS())
	e.Use(middleware.Logger())

	authService := authentication.NewService(db)
	authHandler := authentication.NewHandler(authService)

	e.POST("/api/auth/register", authHandler.RegisterHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	e.Start("0.0.0.0:8080")

	log.Printf("Server starting on :%s", port)
}
