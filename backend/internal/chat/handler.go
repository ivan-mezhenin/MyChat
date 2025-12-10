package chat

import (
	"net/http"
	"strings"

	"github.com/labstack/echo"
)

type Handler struct {
	service *Service
}

type SendMessageRequest struct {
	ChatID string `json:"chat_id"`
	Text   string `json:"text"`
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

	return c.JSON(http.StatusOK, messages)
}

func (h *Handler) SendMessage(c echo.Context) error {
	var req SendMessageRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "invalid request body",
		})
	}

	userID, err := h.getUserIDFromToken(c.Request())
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error": "invalid token",
		})
	}

	message, err := h.service.SendMessage(c.Request().Context(), req.ChatID, userID, req.Text)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusCreated, message)
}

func (h *Handler) getUserIDFromToken(r *http.Request) (string, error) {
	authHeader := r.Header.Get("Authorization")
	token := strings.TrimPrefix(authHeader, "Bearer ")
	return h.service.ValidateToken(r.Context(), token)
}
