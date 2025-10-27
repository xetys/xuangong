package config

import (
	"fmt"
	"strings"
	"time"

	"github.com/spf13/viper"
)

type Config struct {
	Server    ServerConfig
	Database  DatabaseConfig
	JWT       JWTConfig
	CORS      CORSConfig
	RateLimit RateLimitConfig
	Upload    UploadConfig
	Logging   LoggingConfig
}

type ServerConfig struct {
	Port       string
	Env        string
	APIVersion string
}

type DatabaseConfig struct {
	URL                string
	MaxConnections     int
	MaxIdleConnections int
	MaxLifetimeMinutes int
}

type JWTConfig struct {
	Secret            string
	ExpiryHours       int
	RefreshExpiryDays int
}

type CORSConfig struct {
	AllowedOrigins []string
	AllowedMethods []string
	AllowedHeaders []string
}

type RateLimitConfig struct {
	Requests        int
	DurationMinutes int
}

type UploadConfig struct {
	MaxSizeMB  int
	UploadPath string
}

type LoggingConfig struct {
	Level  string
	Format string
}

// Load reads configuration from environment variables and .env files
func Load() (*Config, error) {
	viper.SetConfigName(".env.development")
	viper.SetConfigType("env")
	viper.AddConfigPath(".")
	viper.AddConfigPath("..")
	viper.AddConfigPath("../..")

	// Allow environment variables to override .env file
	viper.AutomaticEnv()

	// Read config file (ignore error if not found, env vars might be enough)
	_ = viper.ReadInConfig()

	// Set defaults
	setDefaults()

	config := &Config{
		Server: ServerConfig{
			Port:       viper.GetString("PORT"),
			Env:        viper.GetString("ENV"),
			APIVersion: viper.GetString("API_VERSION"),
		},
		Database: DatabaseConfig{
			URL:                viper.GetString("DATABASE_URL"),
			MaxConnections:     viper.GetInt("DB_MAX_CONNECTIONS"),
			MaxIdleConnections: viper.GetInt("DB_MAX_IDLE_CONNECTIONS"),
			MaxLifetimeMinutes: viper.GetInt("DB_MAX_LIFETIME_MINUTES"),
		},
		JWT: JWTConfig{
			Secret:            viper.GetString("JWT_SECRET"),
			ExpiryHours:       viper.GetInt("JWT_EXPIRY_HOURS"),
			RefreshExpiryDays: viper.GetInt("REFRESH_TOKEN_EXPIRY_DAYS"),
		},
		CORS: CORSConfig{
			AllowedOrigins: strings.Split(viper.GetString("ALLOWED_ORIGINS"), ","),
			AllowedMethods: strings.Split(viper.GetString("ALLOWED_METHODS"), ","),
			AllowedHeaders: strings.Split(viper.GetString("ALLOWED_HEADERS"), ","),
		},
		RateLimit: RateLimitConfig{
			Requests:        viper.GetInt("RATE_LIMIT_REQUESTS"),
			DurationMinutes: viper.GetInt("RATE_LIMIT_DURATION_MINUTES"),
		},
		Upload: UploadConfig{
			MaxSizeMB:  viper.GetInt("MAX_UPLOAD_SIZE_MB"),
			UploadPath: viper.GetString("UPLOAD_PATH"),
		},
		Logging: LoggingConfig{
			Level:  viper.GetString("LOG_LEVEL"),
			Format: viper.GetString("LOG_FORMAT"),
		},
	}

	if err := validate(config); err != nil {
		return nil, fmt.Errorf("invalid configuration: %w", err)
	}

	return config, nil
}

func setDefaults() {
	viper.SetDefault("PORT", "8080")
	viper.SetDefault("ENV", "development")
	viper.SetDefault("API_VERSION", "v1")
	viper.SetDefault("DB_MAX_CONNECTIONS", 25)
	viper.SetDefault("DB_MAX_IDLE_CONNECTIONS", 5)
	viper.SetDefault("DB_MAX_LIFETIME_MINUTES", 5)
	viper.SetDefault("JWT_EXPIRY_HOURS", 24)
	viper.SetDefault("REFRESH_TOKEN_EXPIRY_DAYS", 7)
	viper.SetDefault("RATE_LIMIT_REQUESTS", 100)
	viper.SetDefault("RATE_LIMIT_DURATION_MINUTES", 1)
	viper.SetDefault("MAX_UPLOAD_SIZE_MB", 500)
	viper.SetDefault("UPLOAD_PATH", "./uploads")
	viper.SetDefault("LOG_LEVEL", "info")
	viper.SetDefault("LOG_FORMAT", "json")
}

func validate(config *Config) error {
	if config.Database.URL == "" {
		return fmt.Errorf("DATABASE_URL is required")
	}
	if config.JWT.Secret == "" {
		return fmt.Errorf("JWT_SECRET is required")
	}
	if len(config.JWT.Secret) < 32 {
		return fmt.Errorf("JWT_SECRET must be at least 32 characters")
	}
	return nil
}

// GetJWTExpiry returns JWT token expiry duration
func (c *JWTConfig) GetJWTExpiry() time.Duration {
	return time.Duration(c.ExpiryHours) * time.Hour
}

// GetRefreshExpiry returns refresh token expiry duration
func (c *JWTConfig) GetRefreshExpiry() time.Duration {
	return time.Duration(c.RefreshExpiryDays) * 24 * time.Hour
}

// GetRateLimitDuration returns rate limit duration
func (c *RateLimitConfig) GetDuration() time.Duration {
	return time.Duration(c.DurationMinutes) * time.Minute
}
