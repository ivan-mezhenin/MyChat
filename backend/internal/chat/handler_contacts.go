package chat

import (
	"net/http"
	"strings"
	"time"

	"github.com/labstack/echo"
)

type CreateChatFromContactsRequest struct {
	ChatName   string   `json:"chat_name"`
	ContactIDs []string `json:"contact_ids"`
	ChatType   string   `json:"chat_type"`
}

type ChatResponse struct {
	ID           string    `json:"id"`
	Name         string    `json:"name"`
	Type         string    `json:"type"`
	CreatedBy    string    `json:"created_by"`
	CreatedAt    time.Time `json:"created_at"`
	Participants []string  `json:"participants"`
}

func (h *Handler) CreateChatFromContacts(c echo.Context) error {
	var req CreateChatFromContactsRequest

	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid JSON format",
		})
	}

	if req.ChatName == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Chat name is required",
		})
	}

	if len(req.ContactIDs) == 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "At least one contact is required",
		})
	}

	if req.ChatType != "group" && req.ChatType != "private" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Chat type must be 'group' or 'private'",
		})
	}

	if req.ChatType == "private" && len(req.ContactIDs) != 1 {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Private chat requires exactly one contact",
		})
	}

	userID, err := h.getUserIDFromToken(c.Request())
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error": "Invalid token",
		})
	}

	chatResponse, err := h.service.CreateChatFromContacts(
		c.Request().Context(),
		userID,
		req.ChatName,
		req.ContactIDs,
		req.ChatType,
	)

	if err != nil {
		errorMsg := err.Error()
		if strings.Contains(errorMsg, "contact does not belong") {
			return c.JSON(http.StatusForbidden, map[string]string{
				"error": "You don't have permission to use this contact",
			})
		}
		if strings.Contains(errorMsg, "need at least 2 participants") {
			return c.JSON(http.StatusBadRequest, map[string]string{
				"error": "Need at least one other participant",
			})
		}

		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to create chat: " + errorMsg,
		})
	}

	return c.JSON(http.StatusCreated, map[string]interface{}{
		"success": true,
		"message": "Chat created successfully",
		"chat":    chatResponse,
	})
}

func (h *Handler) CreatePrivateChat(c echo.Context) error {
	contactID := c.Param("contactId")
	if contactID == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Contact ID is required",
		})
	}

	userID, err := h.getUserIDFromToken(c.Request())
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error": "Invalid token",
		})
	}

	chatResponse, err := h.service.CreatePrivateChat(c.Request().Context(), userID, contactID)
	if err != nil {
		errorMsg := err.Error()

		if strings.Contains(errorMsg, "contact not found") {
			return c.JSON(http.StatusNotFound, map[string]string{
				"error": "Contact not found",
			})
		}

		if strings.Contains(errorMsg, "contact does not belong") {
			return c.JSON(http.StatusForbidden, map[string]string{
				"error": "You don't have permission to use this contact",
			})
		}

		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to create private chat: " + errorMsg,
		})
	}

	return c.JSON(http.StatusCreated, map[string]interface{}{
		"success": true,
		"message": "Private chat created successfully",
		"chat":    chatResponse,
	})
}

func (h *Handler) GetUserContacts(c echo.Context) error {
	userID, err := h.getUserIDFromToken(c.Request())
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error": "Invalid token",
		})
	}

	contacts, err := h.service.GetUserContacts(c.Request().Context(), userID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Failed to get contacts: " + err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"success":  true,
		"contacts": contacts,
	})
}
