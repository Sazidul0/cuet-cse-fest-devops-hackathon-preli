#!/bin/sh
# Gateway entrypoint script
# Ensures backend is ready before starting

set -e

echo "Gateway entrypoint: Starting..."

# Wait for backend to be ready
echo "Waiting for backend at $BACKEND_URL..."
BACKEND_HOST=$(echo $BACKEND_URL | sed 's|http://||' | cut -d: -f1)
BACKEND_PORT=$(echo $BACKEND_URL | sed 's|.*:||')
BACKEND_PORT=${BACKEND_PORT:-3847}

counter=0
max_attempts=30

while [ $counter -lt $max_attempts ]; do
  if node -e "
    require('http').get('$BACKEND_URL/api/health', function(res) {
      process.exit(res.statusCode === 200 ? 0 : 1)
    }).on('error', function(err) {
      process.exit(1)
    })
  " 2>/dev/null; then
    echo "Backend is ready!"
    break
  fi
  
  counter=$((counter + 1))
  echo "Backend not ready ($counter/$max_attempts), waiting..."
  sleep 1
done

if [ $counter -eq $max_attempts ]; then
  echo "ERROR: Backend did not become ready in time"
  exit 1
fi

# Start the gateway
echo "Starting gateway..."
exec npm start
