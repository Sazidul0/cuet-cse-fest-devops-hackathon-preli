# Multi-stage build for optimized production image
# Stage 1: Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache python3 make g++

# Copy package files
COPY package*.json tsconfig.json ./

# Install dependencies (use npm install as fallback if no lock file)
RUN npm install --only=production && npm install --only=development || npm install

# Copy source code
COPY src ./src

# Build TypeScript
RUN npm run build

# Stage 2: Runtime stage (minimal image)
FROM node:20-alpine

# Add security: run as non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app

# Copy package files for production
COPY package*.json ./

# Install only production dependencies (use npm install as fallback)
RUN (npm ci --only=production || npm install --only=production) && \
    npm cache clean --force && \
    chown -R nodejs:nodejs /app

# Copy built application from builder
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist

# Switch to non-root user
USER nodejs

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3847/api/health || exit 1

# Expose port (informational only)
EXPOSE 3847

# Start application
CMD ["node", "dist/index.js"]
