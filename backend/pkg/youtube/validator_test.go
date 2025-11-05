package youtube

import (
	"net/url"
	"testing"
)

func TestValidateURL(t *testing.T) {
	tests := []struct {
		name        string
		input       string
		wantVideoID string
		wantErr     error
	}{
		// Valid URLs
		{
			name:        "standard youtube.com URL",
			input:       "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
			wantVideoID: "dQw4w9WgXcQ",
			wantErr:     nil,
		},
		{
			name:        "youtube.com without www",
			input:       "https://youtube.com/watch?v=dQw4w9WgXcQ",
			wantVideoID: "dQw4w9WgXcQ",
			wantErr:     nil,
		},
		{
			name:        "youtu.be short URL",
			input:       "https://youtu.be/dQw4w9WgXcQ",
			wantVideoID: "dQw4w9WgXcQ",
			wantErr:     nil,
		},
		{
			name:        "youtube.com embed URL",
			input:       "https://www.youtube.com/embed/dQw4w9WgXcQ",
			wantVideoID: "dQw4w9WgXcQ",
			wantErr:     nil,
		},
		{
			name:        "youtube.com old /v/ URL",
			input:       "https://www.youtube.com/v/dQw4w9WgXcQ",
			wantVideoID: "dQw4w9WgXcQ",
			wantErr:     nil,
		},
		{
			name:        "mobile youtube URL",
			input:       "https://m.youtube.com/watch?v=dQw4w9WgXcQ",
			wantVideoID: "dQw4w9WgXcQ",
			wantErr:     nil,
		},
		{
			name:        "URL with timestamp parameter",
			input:       "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42s",
			wantVideoID: "dQw4w9WgXcQ",
			wantErr:     nil,
		},
		{
			name:        "youtu.be with timestamp",
			input:       "https://youtu.be/dQw4w9WgXcQ?t=42",
			wantVideoID: "dQw4w9WgXcQ",
			wantErr:     nil,
		},
		{
			name:        "URL with extra whitespace",
			input:       "  https://www.youtube.com/watch?v=dQw4w9WgXcQ  ",
			wantVideoID: "dQw4w9WgXcQ",
			wantErr:     nil,
		},
		{
			name:        "video ID with underscore",
			input:       "https://www.youtube.com/watch?v=dQw4w9Wg_cQ",
			wantVideoID: "dQw4w9Wg_cQ",
			wantErr:     nil,
		},
		{
			name:        "video ID with hyphen",
			input:       "https://www.youtube.com/watch?v=dQw4w9Wg-cQ",
			wantVideoID: "dQw4w9Wg-cQ",
			wantErr:     nil,
		},

		// Empty/nil cases (valid - optional field)
		{
			name:        "empty string",
			input:       "",
			wantVideoID: "",
			wantErr:     nil,
		},
		{
			name:        "whitespace only",
			input:       "   ",
			wantVideoID: "",
			wantErr:     nil,
		},

		// Invalid URLs
		{
			name:        "missing video ID parameter",
			input:       "https://www.youtube.com/watch",
			wantVideoID: "",
			wantErr:     ErrMissingVideoID,
		},
		{
			name:        "empty video ID parameter",
			input:       "https://www.youtube.com/watch?v=",
			wantVideoID: "",
			wantErr:     ErrMissingVideoID,
		},
		{
			name:        "youtu.be without video ID",
			input:       "https://youtu.be/",
			wantVideoID: "",
			wantErr:     ErrMissingVideoID,
		},
		{
			name:        "invalid domain",
			input:       "https://notyoutube.com/watch?v=dQw4w9WgXcQ",
			wantVideoID: "",
			wantErr:     ErrInvalidURL,
		},
		{
			name:        "video ID too short",
			input:       "https://www.youtube.com/watch?v=short",
			wantVideoID: "",
			wantErr:     ErrInvalidVideoID,
		},
		{
			name:        "video ID too long",
			input:       "https://www.youtube.com/watch?v=dQw4w9WgXcQextra",
			wantVideoID: "",
			wantErr:     ErrInvalidVideoID,
		},
		{
			name:        "video ID with invalid characters",
			input:       "https://www.youtube.com/watch?v=dQw4w9Wg@cQ",
			wantVideoID: "",
			wantErr:     ErrInvalidVideoID,
		},
		{
			name:        "malformed URL",
			input:       "not a url at all",
			wantVideoID: "",
			wantErr:     ErrInvalidURL,
		},
		{
			name:        "youtube playlist URL",
			input:       "https://www.youtube.com/playlist?list=PLrAXtmErZgOeiKm4sgNOknGvNjby9efdf",
			wantVideoID: "",
			wantErr:     ErrMissingVideoID,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gotVideoID, gotErr := ValidateURL(tt.input)

			if gotErr != tt.wantErr {
				t.Errorf("ValidateURL() error = %v, wantErr %v", gotErr, tt.wantErr)
				return
			}

			if gotVideoID != tt.wantVideoID {
				t.Errorf("ValidateURL() videoID = %v, want %v", gotVideoID, tt.wantVideoID)
			}
		})
	}
}

func TestExtractVideoID(t *testing.T) {
	tests := []struct {
		name        string
		inputURL    string
		wantVideoID string
		wantErr     error
	}{
		{
			name:        "youtube.com/watch format",
			inputURL:    "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
			wantVideoID: "dQw4w9WgXcQ",
			wantErr:     nil,
		},
		{
			name:        "youtu.be format",
			inputURL:    "https://youtu.be/dQw4w9WgXcQ",
			wantVideoID: "dQw4w9WgXcQ",
			wantErr:     nil,
		},
		{
			name:        "embed format",
			inputURL:    "https://www.youtube.com/embed/dQw4w9WgXcQ",
			wantVideoID: "dQw4w9WgXcQ",
			wantErr:     nil,
		},
		{
			name:        "/v/ format",
			inputURL:    "https://www.youtube.com/v/dQw4w9WgXcQ",
			wantVideoID: "dQw4w9WgXcQ",
			wantErr:     nil,
		},
		{
			name:        "mobile format",
			inputURL:    "https://m.youtube.com/watch?v=dQw4w9WgXcQ",
			wantVideoID: "dQw4w9WgXcQ",
			wantErr:     nil,
		},
		{
			name:        "invalid domain",
			inputURL:    "https://vimeo.com/123456",
			wantVideoID: "",
			wantErr:     ErrInvalidURL,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			parsedURL, err := url.Parse(tt.inputURL)
			if err != nil {
				t.Fatalf("Failed to parse URL: %v", err)
			}

			gotVideoID, gotErr := ExtractVideoID(parsedURL)

			if gotErr != tt.wantErr {
				t.Errorf("ExtractVideoID() error = %v, wantErr %v", gotErr, tt.wantErr)
				return
			}

			if gotVideoID != tt.wantVideoID {
				t.Errorf("ExtractVideoID() videoID = %v, want %v", gotVideoID, tt.wantVideoID)
			}
		})
	}
}

func TestIsValidVideoID(t *testing.T) {
	tests := []struct {
		name    string
		videoID string
		want    bool
	}{
		{
			name:    "valid 11-char alphanumeric",
			videoID: "dQw4w9WgXcQ",
			want:    true,
		},
		{
			name:    "valid with underscore",
			videoID: "dQw4w9Wg_cQ",
			want:    true,
		},
		{
			name:    "valid with hyphen",
			videoID: "dQw4w9Wg-cQ",
			want:    true,
		},
		{
			name:    "too short",
			videoID: "short",
			want:    false,
		},
		{
			name:    "too long",
			videoID: "dQw4w9WgXcQextra",
			want:    false,
		},
		{
			name:    "invalid character @",
			videoID: "dQw4w9Wg@cQ",
			want:    false,
		},
		{
			name:    "invalid character space",
			videoID: "dQw4w9Wg cQ",
			want:    false,
		},
		{
			name:    "empty string",
			videoID: "",
			want:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := IsValidVideoID(tt.videoID)
			if got != tt.want {
				t.Errorf("IsValidVideoID() = %v, want %v", got, tt.want)
			}
		})
	}
}
