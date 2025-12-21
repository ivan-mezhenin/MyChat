package chat

import (
	"net/http"
	"strings"

	"github.com/labstack/echo"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) GetMessages(c echo.Context) error {
	chatId := c.Param("chatId")
	if chatId == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "chatId is required",
		})
	}

	userId, err := h.getUserIDFromToken(c.Request())
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error": "invalid token",
		})
	}

	messages, err := h.service.GetMessages(c.Request().Context(), chatId, userId)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"messages": messages,
	})
}

func (h *Handler) CreateChat(c echo.Context) error {
	var req struct {
		ChatName string   `json:"chat_name"`
		Emails   []string `json:"emails"`
		ChatType string   `json:"chat_type"`
	}

	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid JSON format",
		})
	}

	userID, err := h.getUserIDFromToken(c.Request())
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error": "Invalid token",
		})
	}

	chatID, err := h.service.createSimpleChat(c.Request().Context(), userID, req.ChatName, req.Emails, req.ChatType)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusCreated, map[string]interface{}{
		"chat_id":   chatID,
		"chat_name": req.ChatName,
	})
}

func (h *Handler) getUserIDFromToken(r *http.Request) (string, error) {
	authHeader := r.Header.Get("Authorization")
	token := strings.TrimPrefix(authHeader, "Bearer ")
	return h.service.ValidateToken(r.Context(), token)
}
