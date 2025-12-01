#!/bin/sh
# Backend entrypoint script
# Ensures database connection before starting app

set -e

echo "Backend entrypoint: Starting..."

# Wait for MongoDB to be ready
echo "Waiting for MongoDB at $MONGO_URI..."
while ! node -e "
  require('http').get({
    hostname: 'mongo',
    port: 27017,
    path: '/',
    method: 'GET'
  }, function(res) {
    process.exit(res.statusCode === 400 ? 0 : 1)
  }).on('error', function(err) {
    process.exit(1)
  })
" 2>/dev/null; do
  echo "MongoDB not ready, waiting..."
  sleep 2
done

echo "MongoDB is ready!"

# Check if dist exists (production) or build it (development)
if [ -d "dist" ]; then
  echo "Starting backend from compiled code..."
  exec node dist/index.js
else
  echo "Starting backend in development mode..."
  exec npm run dev
fi
