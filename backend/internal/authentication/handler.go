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

func (h *Handler) LoginHandler(c echo.Context) error {
	var req struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}

	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid JSON format",
		})
	}

	if req.Email == "" || req.Password == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Email and password are required",
		})
	}

	response, err := h.service.Login(c.Request().Context(), req.Email, req.Password)
	if err != nil {
		errorMsg := err.Error()
		if strings.Contains(errorMsg, "INVALID_LOGIN_CREDENTIALS") ||
			strings.Contains(errorMsg, "EMAIL_NOT_FOUND") ||
			strings.Contains(errorMsg, "INVALID_PASSWORD") ||
			strings.Contains(errorMsg, "authentication failed") {
			return c.JSON(http.StatusUnauthorized, map[string]string{
				"error": "Invalid email or password",
			})
		}

		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Login failed: " + errorMsg,
		})
	}

	return c.JSON(http.StatusOK, response)
}
