package main

import (
	"fmt"
	"io"
	"os"
)

// CliConfig keeps output injectable so the command is easy to test.
type CliConfig struct {
	ErrStream, OutStream io.Writer
}

// Option changes one part of the command configuration.
type Option func(*CliConfig)

func WithErrStream(errStream io.Writer) Option {
	return func(c *CliConfig) {
		c.ErrStream = errStream
	}
}

func WithOutStream(outStream io.Writer) Option {
	return func(c *CliConfig) {
		c.OutStream = outStream
	}
}

func NewCliConfig(opts ...Option) CliConfig {
	c := CliConfig{ErrStream: os.Stderr, OutStream: os.Stdout}
	for _, opt := range opts {
		opt(&c)
	}
	return c
}

// app reports whether each word has an even or odd number of Unicode characters.
func app(words []string, cfg CliConfig) error {
	for _, word := range words {
		length := len([]rune(word))
		parity := "odd"
		if length%2 == 0 {
			parity = "even"
		}
		if _, err := fmt.Fprintf(cfg.OutStream, "%s: %d letters (%s)\n", word, length, parity); err != nil {
			return fmt.Errorf("write result: %w", err)
		}
	}
	return nil
}

func main() {
	words := os.Args[1:]
	if len(words) == 0 {
		words = []string{"hello", "gopher", "Stockholm"}
	}
	cfg := NewCliConfig()
	if err := app(words, cfg); err != nil {
		fmt.Fprintln(cfg.ErrStream, err)
		os.Exit(1)
	}
}
