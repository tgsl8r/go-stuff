package api

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGreeting(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name string
		in   string
		want string
	}{
		{name: "named", in: "Gopher", want: "Hello, Gopher!"},
		{name: "empty falls back", in: "", want: "Hello, world!"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			if got := Greeting(tc.in); got != tc.want {
				t.Errorf("Greeting(%q) = %q, want %q", tc.in, got, tc.want)
			}
		})
	}
}

func TestHandler(t *testing.T) {
	t.Parallel()

	srv := httptest.NewServer(NewHandler(slog.New(slog.NewTextHandler(io.Discard, nil))))
	t.Cleanup(srv.Close)

	tests := []struct {
		name       string
		method     string
		path       string
		wantStatus int
		wantKey    string
		wantValue  string
	}{
		{"health", http.MethodGet, "/healthz", http.StatusOK, "status", "ok"},
		{"hello", http.MethodGet, "/hello/Gopher", http.StatusOK, "message", "Hello, Gopher!"},
		{"version", http.MethodGet, "/version", http.StatusOK, "version", "dev"},
		{"wrong method", http.MethodPost, "/healthz", http.StatusMethodNotAllowed, "", ""},
		{"not found", http.MethodGet, "/nope", http.StatusNotFound, "", ""},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			req, err := http.NewRequestWithContext(t.Context(), tc.method, srv.URL+tc.path, nil)
			if err != nil {
				t.Fatal(err)
			}
			resp, err := http.DefaultClient.Do(req)
			if err != nil {
				t.Fatal(err)
			}
			defer resp.Body.Close()

			if resp.StatusCode != tc.wantStatus {
				t.Fatalf("status = %d, want %d", resp.StatusCode, tc.wantStatus)
			}
			if tc.wantKey == "" {
				return
			}

			var body map[string]string
			if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
				t.Fatalf("decode body: %v", err)
			}
			if got := body[tc.wantKey]; got != tc.wantValue {
				t.Errorf("body[%q] = %q, want %q", tc.wantKey, got, tc.wantValue)
			}
		})
	}
}
