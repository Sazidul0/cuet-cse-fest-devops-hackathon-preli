# Production Dockerfile for gateway - minimal image
FROM node:20-alpine

# Add security: run as non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install only production dependencies (use npm install as fallback)
RUN (npm ci --only=production || npm install --only=production) && \
    npm cache clean --force && \
    chown -R nodejs:nodejs /app

# Copy source code
COPY --chown=nodejs:nodejs src ./src

# Switch to non-root user
USER nodejs

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:5921/health || exit 1

# Expose port (informational only)
EXPOSE 5921

# Start application
CMD ["npm", "start"]
