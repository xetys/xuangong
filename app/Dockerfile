# Build stage
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# Copy pubspec files
COPY pubspec.yaml pubspec.lock ./

# Get dependencies
RUN flutter pub get

# Copy source code
COPY . .

# Build web app
RUN flutter build web --release

# Production stage
FROM nginx:alpine

# Install envsubst (part of gettext)
RUN apk add --no-cache gettext

# Remove default nginx config and make directories writable for nginx user
# Also configure nginx to use writable PID location
RUN rm -f /etc/nginx/conf.d/default.conf && \
    chown -R nginx:nginx /etc/nginx/conf.d && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    mkdir -p /var/run/nginx && \
    chown -R nginx:nginx /var/run/nginx && \
    sed -i 's|pid.*/run/nginx.pid;|pid /var/run/nginx/nginx.pid;|g' /etc/nginx/nginx.conf

# Copy custom nginx config
COPY <<EOF /etc/nginx/conf.d/default.conf
server {
    listen 8080;
    listen [::]:8080;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    # Enable gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/x-javascript application/xml+rss application/json;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Flutter web routing
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Copy built app from builder and make it writable for nginx user
COPY --from=builder /app/build/web /usr/share/nginx/html
RUN chown -R nginx:nginx /usr/share/nginx/html

# Create entrypoint script to inject environment variables
COPY <<'EOF' /docker-entrypoint.d/40-envsubst-index.sh
#!/bin/sh
set -e

# Default API URL if not provided
export API_URL=${API_URL:-http://localhost:8080}

echo "Injecting API_URL=${API_URL} into index.html"

# Process index.html with envsubst
envsubst '$API_URL' < /usr/share/nginx/html/index.html > /tmp/index.html
cat /tmp/index.html > /usr/share/nginx/html/index.html
rm /tmp/index.html

echo "API_URL injection complete"
EOF

RUN chmod +x /docker-entrypoint.d/40-envsubst-index.sh

# Expose port
EXPOSE 8080

# Default API URL environment variable
ENV API_URL=http://localhost:8080
