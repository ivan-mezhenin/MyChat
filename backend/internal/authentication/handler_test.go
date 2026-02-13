package authentication

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/labstack/echo"
)

func TestLoginHandler_ValidationOnly(t *testing.T) {
	t.Run("Missing email field", func(t *testing.T) {
		jsonBody := `{"password": "123456"}`
		req := httptest.NewRequest(http.MethodPost, "/login", strings.NewReader(jsonBody))
		req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
	})

	t.Run("Valid JSON format", func(t *testing.T) {
		jsonBody := `{"email": "test@test.com", "password": "123456"}`
		req := httptest.NewRequest(http.MethodPost, "/login", strings.NewReader(jsonBody))
		req.Header.Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
	})
}
