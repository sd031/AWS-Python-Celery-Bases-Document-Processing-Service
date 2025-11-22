# Multi-stage build for React frontend
FROM node:18-alpine as build

WORKDIR /app

# Copy package files
COPY frontend/package*.json ./

# Install ALL dependencies (including dev dependencies needed for build)
RUN npm ci

# Copy source code
COPY frontend/ ./

# Build the app
RUN npm run build

# Production stage with nginx
FROM nginx:alpine

# Copy built files from build stage
COPY --from=build /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
