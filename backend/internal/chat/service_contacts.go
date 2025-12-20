package chat

import (
	"MyChatServer/internal/websocket"
	"context"
	"fmt"
	"log"
	"time"
)

type ContactInfo struct {
	ContactID    string `json:"contact_id"`
	OwnerUID     string `json:"owner_uid"`
	ContactUID   string `json:"contact_uid"`
	ContactEmail string `json:"contact_email"`
	ContactName  string `json:"contact_name"`
}

func (s *Service) GetContactByID(ctx context.Context, contactID string) (*ContactInfo, error) {
	doc, err := s.db.Firestore.Collection("contacts").Doc(contactID).Get(ctx)
	if err != nil {
		return nil, fmt.Errorf("contact not found: %v", err)
	}

	var contact struct {
		OwnerUID     string    `firestore:"OwnerUID"`
		ContactUID   string    `firestore:"ContactUID"`
		ContactEmail string    `firestore:"ContactEmail"`
		ContactName  string    `firestore:"ContactName"`
		CreatedAt    time.Time `firestore:"CreatedAt"`
	}

	if err := doc.DataTo(&contact); err != nil {
		return nil, fmt.Errorf("failed to parse contact: %v", err)
	}

	return &ContactInfo{
		ContactID:    contactID,
		OwnerUID:     contact.OwnerUID,
		ContactUID:   contact.ContactUID,
		ContactEmail: contact.ContactEmail,
		ContactName:  contact.ContactName,
	}, nil
}

func (s *Service) GetUserContacts(ctx context.Context, userID string) ([]ContactInfo, error) {
	docs, err := s.db.Firestore.Collection("contacts").
		Where("OwnerUID", "==", userID).
		Documents(ctx).GetAll()

	if err != nil {
		return nil, fmt.Errorf("failed to get contacts: %v", err)
	}

	contacts := make([]ContactInfo, 0, len(docs))
	for _, doc := range docs {
		var contact struct {
			OwnerUID     string    `firestore:"owner_uid"`
			ContactUID   string    `firestore:"contact_uid"`
			ContactEmail string    `firestore:"contact_email"`
			ContactName  string    `firestore:"contact_name"`
			CreatedAt    time.Time `firestore:"created_at"`
		}

		if err := doc.DataTo(&contact); err != nil {
			continue
		}

		contacts = append(contacts, ContactInfo{
			ContactID:    doc.Ref.ID,
			OwnerUID:     contact.OwnerUID,
			ContactUID:   contact.ContactUID,
			ContactEmail: contact.ContactEmail,
			ContactName:  contact.ContactName,
		})
	}

	return contacts, nil
}

func (s *Service) CreateChatFromContacts(ctx context.Context, creatorID, chatName string, contactIDs []string, chatType string) (*ChatResponse, error) {
	participants := []string{creatorID}

	for _, contactID := range contactIDs {
		contact, err := s.GetContactByID(ctx, contactID)
		if err != nil {
			_, err := s.db.Firestore.Collection("users").Doc(contactID).Get(ctx)
			if err != nil {
				continue
			}

			found := false
			for _, p := range participants {
				if p == contactID {
					found = true
					break
				}
			}

			if !found {
				participants = append(participants, contactID)
			}
			continue
		}

		if contact.OwnerUID != creatorID {
			return nil, fmt.Errorf("contact does not belong to user")
		}

		found := false
		for _, p := range participants {
			if p == contact.ContactUID {
				found = true
				break
			}
		}

		if !found {
			participants = append(participants, contact.ContactUID)
		}
	}

	if len(participants) < 2 {
		return nil, fmt.Errorf("need at least 2 participants including yourself")
	}

	chatID, chatData, err := s.createChatWithData(ctx, creatorID, chatName, participants, chatType)
	if err != nil {
		return nil, err
	}

	return &ChatResponse{
		ID:           chatID,
		Name:         chatName,
		Type:         chatType,
		CreatedBy:    creatorID,
		CreatedAt:    chatData["created_at"].(time.Time),
		Participants: participants,
	}, nil
}

func (s *Service) CreatePrivateChat(ctx context.Context, creatorID, contactID string) (*ChatResponse, error) {
	contact, err := s.GetContactByID(ctx, contactID)
	if err != nil {
		return nil, fmt.Errorf("contact not found: %v", err)
	}

	if contact.OwnerUID != creatorID {
		return nil, fmt.Errorf("contact does not belong to user")
	}

	existingChatID, err := s.findExistingPrivateChat(ctx, creatorID, contact.ContactUID)
	if err == nil && existingChatID != "" {
		chatDoc, err := s.db.Firestore.Collection("chats").Doc(existingChatID).Get(ctx)
		if err == nil {
			data := chatDoc.Data()
			return &ChatResponse{
				ID:           existingChatID,
				Name:         data["name"].(string),
				Type:         data["type"].(string),
				CreatedBy:    data["created_by"].(string),
				CreatedAt:    data["created_at"].(time.Time),
				Participants: convertToStringSlice(data["participants"]),
			}, nil
		}
	}

	userProfile, err1 := s.getUserProfile(ctx, creatorID)
	contactProfile, err2 := s.getUserProfile(ctx, contact.ContactUID)

	chatName := "Private Chat"
	if err1 == nil && err2 == nil {
		chatName = fmt.Sprintf("%s & %s", userProfile.Name, contactProfile.Name)
	}

	participants := []string{creatorID, contact.ContactUID}
	chatID, chatData, err := s.createChatWithData(ctx, creatorID, chatName, participants, "private")
	if err != nil {
		return nil, err
	}

	return &ChatResponse{
		ID:           chatID,
		Name:         chatName,
		Type:         "private",
		CreatedBy:    creatorID,
		CreatedAt:    chatData["created_at"].(time.Time),
		Participants: participants,
	}, nil
}

func (s *Service) createChatWithData(ctx context.Context, creatorID, chatName string, participants []string, chatType string) (string, map[string]interface{}, error) {
	now := time.Now()

	chatData := map[string]interface{}{
		"chat_id":      "",
		"name":         chatName,
		"type":         chatType,
		"participants": participants,
		"created_by":   creatorID,
		"created_at":   now,
		"updated_at":   now,
	}

	docRef, _, err := s.db.Firestore.Collection("chats").Add(ctx, chatData)
	if err != nil {
		return "", nil, fmt.Errorf("failed to create chat: %v", err)
	}

	chatID := docRef.ID
	chatData["chat_id"] = chatID

	_, err = docRef.Collection("messages").Doc("welcome").Set(ctx, map[string]interface{}{
		"sender_id": "system",
		"text":      fmt.Sprintf("Chat '%s' created", chatName),
		"timestamp": now,
	})

	if s.wsServer != nil {
		go s.notifyChatCreated(chatID, chatData, creatorID)
	}

	return chatID, chatData, err
}

func (s *Service) notifyChatCreated(chatID string, chatData map[string]interface{}, excludeUserID string) {
	participantsInterface, ok := chatData["participants"].([]interface{})
	if !ok {
		return
	}

	participants := make([]string, len(participantsInterface))
	for i, p := range participantsInterface {
		if str, ok := p.(string); ok {
			participants[i] = str
		}
	}

	wsEvent := websocket.WSEvent{
		Type:   "chat_created",
		ChatID: chatID,
		Data:   chatData,
	}

	sentCount, err := s.wsServer.BroadcastToChat(chatID, wsEvent, excludeUserID)
	if err != nil {
		log.Printf("Failed to broadcast chat creation: %v", err)
	} else {
		log.Printf("Notified %d users about new chat %s", sentCount, chatID)
	}
}

func convertToStringSlice(data interface{}) []string {
	if data == nil {
		return []string{}
	}

	switch v := data.(type) {
	case []string:
		return v
	case []interface{}:
		result := make([]string, 0, len(v))
		for _, item := range v {
			if str, ok := item.(string); ok {
				result = append(result, str)
			}
		}
		return result
	default:
		return []string{}
	}
}
