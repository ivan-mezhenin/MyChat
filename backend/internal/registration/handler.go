package registration

import (
	"net/http"

	"regexp"

	"github.com/labstack/echo/v4"
)

type Handler struct {
	service *Service
}

var emailRegex = regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) RegisterHandler(c echo.Context) error {
	var req RegisterRequest

	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid JSON format",
		})
	}

	if req.Username == "" || req.Email == "" || req.Password == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "All fields are required",
		})
	}

	if !emailRegex.MatchString(req.Email) {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid email format",
		})
	}

	if len(req.Password) < 6 {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Password must be at least 6 characters",
		})
	}

	response, err := h.service.Register(c.Request().Context(), &req)
	if err != nil {
		errorMsg := "Registration failed"
		if err.Error() == "email already exists" {
			errorMsg = "Email already registered"
		}

		return c.JSON(http.StatusConflict, map[string]string{
			"error": errorMsg,
		})
	}

	return c.JSON(http.StatusCreated, response)
}
