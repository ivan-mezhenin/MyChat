package contact

import (
	"net/http"
	"strings"

	"github.com/labstack/echo"
)

type ContactHandler struct {
	service *ContactService
}

func NewContactHandler(service *ContactService) *ContactHandler {
	return &ContactHandler{service: service}
}

func (h *ContactHandler) AddContact(c echo.Context) error {
	var req ContactRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Invalid JSON format",
		})
	}

	if req.Email == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Email is required",
		})
	}

	ownerUID, err := h.getUserIDFromToken(c.Request())
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error": "Invalid token",
		})
	}

	contact, err := h.service.AddContact(c.Request().Context(), ownerUID, req.Email, req.Notes)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusCreated, map[string]interface{}{
		"contact": contact,
		"message": "Contact added successfully",
	})
}

func (h *ContactHandler) GetContacts(c echo.Context) error {
	ownerUID, err := h.getUserIDFromToken(c.Request())
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error": "Invalid token",
		})
	}

	contacts, err := h.service.GetContacts(c.Request().Context(), ownerUID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"contacts": contacts,
	})
}

func (h *ContactHandler) SearchUsers(c echo.Context) error {
	query := c.QueryParam("q")
	if query == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Search query is required",
		})
	}

	ownerUID, err := h.getUserIDFromToken(c.Request())
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error": "Invalid token",
		})
	}

	users, err := h.service.SearchUsers(c.Request().Context(), ownerUID, query)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"users": users,
	})
}

func (h *ContactHandler) DeleteContact(c echo.Context) error {
	contactID := c.Param("contactId")
	if contactID == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Contact ID is required",
		})
	}

	ownerUID, err := h.getUserIDFromToken(c.Request())
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error": "Invalid token",
		})
	}

	contact, err := h.service.GetContactByID(c.Request().Context(), contactID)
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{
			"error": "Contact not found",
		})
	}

	if contact.OwnerUID != ownerUID {
		return c.JSON(http.StatusForbidden, map[string]string{
			"error": "Access denied",
		})
	}

	err = h.service.DeleteContact(c.Request().Context(), ownerUID, contact.ContactUID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]string{
		"message": "Contact deleted successfully",
	})
}

func (h *ContactHandler) getUserIDFromToken(r *http.Request) (string, error) {
	authHeader := r.Header.Get("Authorization")
	token := strings.TrimPrefix(authHeader, "Bearer ")
	return h.service.db.ValidateIdToken(r.Context(), token)
}
