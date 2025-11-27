package database

import (
	"context"
	"fmt"
	"time"

	"cloud.google.com/go/firestore"
	firebase "firebase.google.com/go"
	"firebase.google.com/go/auth"
	"google.golang.org/api/option"
)

type Client struct {
	Auth      *auth.Client
	Firestore *firestore.Client
}

type User struct {
	UID       string    `firestore:"uid"`
	Name      string    `firestore:"name"`
	Email     string    `firestore:"email"`
	CreatedAt time.Time `firestore:"created_at"`
	IsBanned  bool      `firestore:"is_banned"`
}

func NewClient(ctx context.Context, serviceAccountPath string) (*Client, error) {
	sa := option.WithCredentialsFile(serviceAccountPath)
	app, err := firebase.NewApp(ctx, nil, sa)
	if err != nil {
		return nil, fmt.Errorf("failed to create app: %w", err)
	}

	authClient, err := app.Auth(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to create auth client: %w", err)
	}

	firestoreClient, err := app.Firestore(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to create firestore client: %w", err)
	}

	return &Client{
		Auth:      authClient,
		Firestore: firestoreClient,
	}, nil
}

func (c *Client) Close() error {
	if c.Firestore != nil {
		return c.Firestore.Close()
	}
	return nil
}

func (c *Client) CreateUserInAuth(ctx context.Context, email, password, name string) (*auth.UserRecord, error) {
	user, err := c.Auth.CreateUser(ctx, (&auth.UserToCreate{}).
		Email(email).
		Password(password).
		DisplayName(name))
	if err != nil {
		return nil, err
	}

	return user, nil
}

func (c *Client) SaveUserInFirestore(ctx context.Context, user *User) error {
	_, err := c.Firestore.Collection("users").Doc(user.UID).Set(ctx, map[string]interface{}{
		"uid":        user.UID,
		"name":       user.Name,
		"email":      user.Email,
		"created_at": user.CreatedAt,
		"is_banned":  user.IsBanned,
	})
	return err
}

func (c *Client) DeleteAuthUser(ctx context.Context, uid string) error {
	return c.Auth.DeleteUser(ctx, uid)
}

func (c *Client) GetUserByEmail(ctx context.Context, email string) (*User, error) {
	authUser, err := c.Auth.GetUserByEmail(ctx, email)
	if err != nil {
		return nil, err
	}

	doc, err := c.Firestore.Collection("users").Doc(authUser.UID).Get(ctx)
	if err != nil {
		return nil, err
	}

	var user User
	if err := doc.DataTo(&user); err != nil {
		return nil, err
	}

	return &user, nil
}

func (c *Client) ValidateIdToken(ctx context.Context, idToken string) (string, error) {
	token, err := c.Auth.VerifyIDToken(ctx, idToken)
	if err != nil {
		return "", fmt.Errorf("invalid idToken: %v", err)
	}

	return token.UID, nil
}
