package authentication

import (
	"fmt"
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

func (h *Handler) VerifyAndGetChatsHandler(c echo.Context) error {
	authHeader := c.Request().Header.Get("Authorization")
	if authHeader == "" {
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error": "Authorization header required",
		})
	}

	token := strings.TrimPrefix(authHeader, "Bearer ")
	if token == "" {
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error": "Bearer token required",
		})
	}

	response, err := h.service.VerifyAndGetChats(c.Request().Context(), token)
	if err != nil {
		fmt.Println(err)
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, response)
}
