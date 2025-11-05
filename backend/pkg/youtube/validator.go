package youtube

import (
	"errors"
	"net/url"
	"regexp"
	"strings"
)

var (
	// ErrInvalidURL indicates the URL format is not a valid URL
	ErrInvalidURL = errors.New("invalid YouTube URL format")

	// ErrMissingVideoID indicates the URL does not contain a video ID
	ErrMissingVideoID = errors.New("YouTube URL missing video ID")

	// ErrInvalidVideoID indicates the video ID format is invalid
	ErrInvalidVideoID = errors.New("invalid YouTube video ID format")
)

// videoIDPattern matches valid YouTube video IDs (11 characters: alphanumeric, underscore, hyphen)
var videoIDPattern = regexp.MustCompile(`^[a-zA-Z0-9_-]{11}$`)

// ValidateURL validates a YouTube URL and returns the extracted video ID
func ValidateURL(youtubeURL string) (string, error) {
	if youtubeURL == "" {
		return "", nil // Empty URLs are valid (optional field)
	}

	// Trim whitespace
	youtubeURL = strings.TrimSpace(youtubeURL)
	if youtubeURL == "" {
		return "", nil
	}

	// Parse the URL
	parsedURL, err := url.Parse(youtubeURL)
	if err != nil {
		return "", ErrInvalidURL
	}

	// Extract video ID based on URL format
	videoID, err := ExtractVideoID(parsedURL)
	if err != nil {
		return "", err
	}

	// Validate video ID format
	if !IsValidVideoID(videoID) {
		return "", ErrInvalidVideoID
	}

	return videoID, nil
}

// ExtractVideoID extracts the video ID from a parsed YouTube URL
func ExtractVideoID(parsedURL *url.URL) (string, error) {
	host := strings.ToLower(parsedURL.Host)

	// Remove www. prefix
	host = strings.TrimPrefix(host, "www.")

	// Check for youtu.be short URLs first
	if host == "youtu.be" {
		path := strings.TrimPrefix(parsedURL.Path, "/")
		if path == "" {
			return "", ErrMissingVideoID
		}
		// Handle timestamp parameters (e.g., /VIDEO_ID?t=123)
		videoID := strings.Split(path, "?")[0]
		return videoID, nil
	}

	// For youtube.com and m.youtube.com, check path-based formats first
	if host == "youtube.com" || host == "m.youtube.com" {
		// youtube.com/embed/VIDEO_ID
		if strings.HasPrefix(parsedURL.Path, "/embed/") {
			videoID := strings.TrimPrefix(parsedURL.Path, "/embed/")
			if videoID == "" {
				return "", ErrMissingVideoID
			}
			return videoID, nil
		}

		// youtube.com/v/VIDEO_ID (old format)
		if strings.HasPrefix(parsedURL.Path, "/v/") {
			videoID := strings.TrimPrefix(parsedURL.Path, "/v/")
			if videoID == "" {
				return "", ErrMissingVideoID
			}
			return videoID, nil
		}

		// youtube.com/watch?v=VIDEO_ID (standard format)
		videoID := parsedURL.Query().Get("v")
		if videoID == "" {
			return "", ErrMissingVideoID
		}
		return videoID, nil
	}

	return "", ErrInvalidURL
}

// IsValidVideoID checks if a string matches the YouTube video ID format
func IsValidVideoID(videoID string) bool {
	return videoIDPattern.MatchString(videoID)
}
