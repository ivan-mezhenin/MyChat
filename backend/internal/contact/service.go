package contact

import (
	"context"
	"fmt"
	"log"
	"time"

	"MyChatServer/internal/database"

	"cloud.google.com/go/firestore"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type ContactService struct {
	db *database.Client
}

type Contact struct {
	ID           string    `json:"id"`
	OwnerUID     string    `json:"owner_uid"`
	ContactUID   string    `json:"contact_uid"`
	ContactEmail string    `json:"contact_email"`
	ContactName  string    `json:"contact_name"`
	CreatedAt    time.Time `json:"created_at"`
	Notes        string    `json:"notes,omitempty"`
}

type ContactRequest struct {
	Email string `json:"email"`
	Notes string `json:"notes,omitempty"`
}

func NewContactService(db *database.Client) *ContactService {
	return &ContactService{db: db}
}

func (s *ContactService) AddContact(ctx context.Context, ownerUID, email, notes string) (*Contact, error) {
	user, err := s.db.GetUserByEmail(ctx, email)
	if err != nil {
		return nil, fmt.Errorf("user not found")
	}

	if user.UID == ownerUID {
		return nil, fmt.Errorf("cannot add yourself as contact")
	}

	exists, err := s.isContactExists(ctx, ownerUID, user.UID)
	if err != nil {
		return nil, err
	}
	if exists {
		return nil, fmt.Errorf("contact already exists")
	}

	contactID := fmt.Sprintf("%s_%s", ownerUID, user.UID)

	contact := Contact{
		ID:           contactID,
		OwnerUID:     ownerUID,
		ContactUID:   user.UID,
		ContactEmail: user.Email,
		ContactName:  user.Name,
		CreatedAt:    time.Now(),
		Notes:        notes,
	}

	_, err = s.db.Firestore.Collection("contacts").Doc(contactID).Set(ctx, contact)
	if err != nil {
		return nil, fmt.Errorf("failed to save contact: %v", err)
	}

	return &contact, nil
}

func (s *ContactService) isContactExists(ctx context.Context, ownerUID, contactUID string) (bool, error) {
	contactID := fmt.Sprintf("%s_%s", ownerUID, contactUID)
	doc, err := s.db.Firestore.Collection("contacts").Doc(contactID).Get(ctx)
	if err != nil {
		if status.Code(err) == codes.NotFound {
			log.Printf("[DEBUG] Contact does not exist: %s", contactID)
			return false, nil
		}
		return false, err
	}
	return doc.Exists(), nil
}

func (s *ContactService) GetContacts(ctx context.Context, ownerUID string) ([]Contact, error) {
	docs, err := s.db.Firestore.Collection("contacts").
		Where("OwnerUID", "==", ownerUID).
		OrderBy("CreatedAt", firestore.Desc).
		Documents(ctx).GetAll()

	if err != nil {
		return nil, fmt.Errorf("failed to get contacts: %v", err)
	}

	contacts := make([]Contact, len(docs))
	for i, doc := range docs {
		var contact Contact
		if err := doc.DataTo(&contact); err != nil {
			continue
		}
		contacts[i] = contact
	}

	return contacts, nil
}

func (s *ContactService) SearchUsers(ctx context.Context, ownerUID, query string) ([]UserSearchResult, error) {
	results := []UserSearchResult{}

	if len(query) > 3 && contains(query, "@") {
		user, err := s.db.GetUserByEmail(ctx, query)
		if err == nil && user.UID != ownerUID {
			isContact, _ := s.isContactExists(ctx, ownerUID, user.UID)
			results = append(results, UserSearchResult{
				UID:       user.UID,
				Email:     user.Email,
				Name:      user.Name,
				IsContact: isContact,
			})
		}
	}

	docs, err := s.db.Firestore.Collection("users").
		Where("name", ">=", query).
		Where("name", "<=", query+"\uf8ff").
		Documents(ctx).GetAll()

	if err == nil {
		for _, doc := range docs {
			var user database.User
			if err := doc.DataTo(&user); err != nil {
				continue
			}

			if user.UID == ownerUID {
				continue
			}

			isContact, _ := s.isContactExists(ctx, ownerUID, user.UID)

			alreadyAdded := false
			for _, r := range results {
				if r.UID == user.UID {
					alreadyAdded = true
					break
				}
			}

			if !alreadyAdded {
				results = append(results, UserSearchResult{
					UID:       user.UID,
					Email:     user.Email,
					Name:      user.Name,
					IsContact: isContact,
				})
			}
		}
	}

	return results, nil
}

func (s *ContactService) DeleteContact(ctx context.Context, ownerUID, contactUID string) error {
	contactID := fmt.Sprintf("%s_%s", ownerUID, contactUID)
	_, err := s.db.Firestore.Collection("contacts").Doc(contactID).Delete(ctx)
	return err
}

func (s *ContactService) GetContactByID(ctx context.Context, contactID string) (*Contact, error) {
	doc, err := s.db.Firestore.Collection("contacts").Doc(contactID).Get(ctx)
	if err != nil {
		return nil, err
	}

	var contact Contact
	if err := doc.DataTo(&contact); err != nil {
		return nil, err
	}

	return &contact, nil
}

type UserSearchResult struct {
	UID       string `json:"uid"`
	Email     string `json:"email"`
	Name      string `json:"name"`
	IsContact bool   `json:"is_contact"`
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && s[:len(substr)] == substr
}
