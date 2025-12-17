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

func (h *Handler) getUserIDFromToken(r *http.Request) (string, error) {
	authHeader := r.Header.Get("Authorization")
	token := strings.TrimPrefix(authHeader, "Bearer ")
	return h.service.ValidateToken(r.Context(), token)
}
