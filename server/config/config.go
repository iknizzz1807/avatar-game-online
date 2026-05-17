package config

import (
	"os"
)

type Config struct {
	Port      string
	DBPath    string
	JWTSecret string
}

func Load() *Config {
	return &Config{
		Port:      getEnv("PORT", "8080"),
		DBPath:    getEnv("DB_PATH", "game.db"),
		JWTSecret: getEnv("JWT_SECRET", "farmworld-online-secret-key-2024"),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}