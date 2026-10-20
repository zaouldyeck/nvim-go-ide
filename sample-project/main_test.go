package main

import (
	"bytes"
	"errors"
	"strings"
	"testing"
)

func TestApp(t *testing.T) {
	tests := []struct {
		name string
		word string
		want string
	}{
		{name: "odd", word: "hello", want: "hello: 5 letters (odd)\n"},
		{name: "even", word: "gopher", want: "gopher: 6 letters (even)\n"},
		{name: "unicode", word: "räka", want: "räka: 4 letters (even)\n"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var out bytes.Buffer
			cfg := NewCliConfig(WithOutStream(&out))
			if err := app([]string{tt.word}, cfg); err != nil {
				t.Fatalf("app() error: %v", err)
			}
			if got := out.String(); got != tt.want {
				t.Errorf("app() = %q, want %q", got, tt.want)
			}
		})
	}
}

type failingWriter struct{}

func (failingWriter) Write([]byte) (int, error) {
	return 0, errors.New("output closed")
}

func TestAppReturnsWriteError(t *testing.T) {
	err := app([]string{"gopher"}, NewCliConfig(WithOutStream(failingWriter{})))
	if err == nil || !strings.Contains(err.Error(), "output closed") {
		t.Fatalf("expected output error, got %v", err)
	}
}
