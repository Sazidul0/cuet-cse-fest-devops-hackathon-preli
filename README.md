# Hackathon Challenge

Your challenge is to take this simple e-commerce backend and turn it into a fully containerized microservices setup using Docker and solid DevOps practices.

## Problem Statement

The backend setup consisting of:

- A service for managing products
- A gateway that forwards API requests

The system must be containerized, secure, optimized, and maintain data persistence across container restarts.

## Architecture

```
                    ┌─────────────────┐
                    │   Client/User   │
                    └────────┬────────┘
                             │
                             │ HTTP (port 5921)
                             │
                    ┌────────▼────────┐
                    │    Gateway      │
                    │  (port 5921)    │
                    │   [Exposed]     │
                    └────────┬────────┘
                             │
                    ┌────────┴────────┐
                    │                 │
         ┌──────────▼──────────┐      │
         │   Private Network   │      │
         │  (Docker Network)   │      │
         └──────────┬──────────┘      │
                    │                 │
         ┌──────────┴──────────┐      │
         │                     │      │
    ┌────▼────┐         ┌──────▼──────┐
    │ Backend │         │   MongoDB   │
    │(port    │◄────────┤  (port      │
    │ 3847)   │         │  27017)     │
    │[Not     │         │ [Not        │
    │Exposed] │         │ Exposed]    │
    └─────────┘         └─────────────┘
```

**Key Points:**
- Gateway is the only service exposed to external clients (port 5921)
- All external requests must go through the Gateway
- Backend and MongoDB should not be exposed to public network

## Project Structure

**DO NOT CHANGE THE PROJECT STRUCTURE.** The following structure must be maintained:

```
.
├── backend/
│   ├── Dockerfile
│   ├── Dockerfile.dev
│   └── src/
├── gateway/
│   ├── Dockerfile
│   ├── Dockerfile.dev
│   └── src/
├── docker/
│   ├── compose.development.yaml
│   └── compose.production.yaml
├── Makefile
└── README.md
```

## Environment Variables

Create a `.env` file in the root directory with the following variables (do not commit actual values):

```env
MONGO_INITDB_ROOT_USERNAME=
MONGO_INITDB_ROOT_PASSWORD=
MONGO_URI=
MONGO_DATABASE=
BACKEND_PORT=3847 # DO NOT CHANGE
GATEWAY_PORT=5921 # DO NOT CHANGE 
NODE_ENV=
```

## Expectations (Open ended, DO YOUR BEST!!!)

- Separate Dev and Prod configs
- Data Persistence
- Follow security basics (limit network exposure, sanitize input) 
- Docker Image Optimization
- Makefile CLI Commands for smooth dev and prod deploy experience (TRY TO COMPLETE THE COMMANDS COMMENTED IN THE Makefile)

**ADD WHAT EVER BEST PRACTICES YOU KNOW**

## Testing

Use the following curl commands to test your implementation.

### Development Environment

```bash
# Start development environment
make dev-up

# Test Gateway Health
curl http://localhost:5921/health

# Test Backend Health
curl http://localhost:3847/api/health

# Create a product
curl -X POST http://localhost:5921/api/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Laptop", "price": 999.99}'

# Get all products
curl http://localhost:5921/api/products

# Access MongoDB
make mongo-shell
```

### Production Environment

```bash
# Build and start production environment
make prod-build
make prod-up

# Test Gateway Health (same external port)
curl http://localhost:5921/health

# Test API
curl -X POST http://localhost:5921/api/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Mouse", "price": 29.99}'

# View logs
make prod-logs
```

## Security Features Implemented

- ✓ **Network Isolation**: Backend and MongoDB only accessible via internal Docker network
- ✓ **Gateway-Only Exposure**: Only gateway exposed on port 5921
- ✓ **Non-root Containers**: All production containers run as non-root user (nodejs:1001)
- ✓ **Security Headers**: X-Frame-Options, X-Content-Type-Options, X-XSS-Protection, etc.
- ✓ **Request Size Limits**: 10KB limit to prevent DoS attacks
- ✓ **Input Sanitization**: HTML entity encoding for string inputs
- ✓ **CORS Configuration**: Restricted in production, open in development
- ✓ **Health Checks**: Built-in health endpoints with HTTP checks
- ✓ **Signal Handling**: Graceful shutdown with SIGTERM/SIGINT
- ✓ **Resource Limits**: CPU and memory limits in production
- ✓ **Read-Only Filesystems**: Production containers with read-only root filesystem (tmpfs for /tmp and /var/run)
- ✓ **Error Masking**: Stack traces hidden in production
- ✓ **No Privilege Escalation**: security_opt: no-new-privileges:true

## Data Persistence

- MongoDB data persists in named Docker volumes:
  - Development: `mongo-data-dev`, `mongo-config-dev`
  - Production: `mongo-data-prod`, `mongo-config-prod`
- Data survives container restarts
- Backup capability with `make db-backup`

## Docker Image Optimization

- **Multi-stage builds**: Separate build and runtime stages for production
- **Alpine base**: Using Node.js 20-alpine for minimal image size
- **Dependency optimization**: Only production dependencies in final image
- **Build cache**: Leveraging Docker layer caching
- **Build context**: .dockerignore files to exclude unnecessary files
- **Minimal runtime**: Final images contain only essential files

## Makefile Commands

### Quick Start

```bash
# Development
make dev-up      # Start dev environment
make dev-down    # Stop dev environment

# Production
make prod-up     # Start production environment
make prod-down   # Stop production environment
```

### Service Management

```bash
make up MODE=dev                    # Start services
make down MODE=dev                  # Stop services
make build MODE=dev                 # Build containers
make logs SERVICE=backend MODE=dev  # View logs
make restart MODE=dev               # Restart services
make ps MODE=dev                    # Show running containers
```

### Container Access

```bash
make backend-shell    # Open shell in backend
make gateway-shell    # Open shell in gateway
make mongo-shell      # Open MongoDB shell
```

### Development

```bash
make backend-build       # Build TypeScript
make backend-install     # Install dependencies
make backend-type-check  # Type check code
make backend-dev         # Run backend locally (not Docker)
```

### Database Management

```bash
make db-backup  # Backup MongoDB
make db-reset   # Reset database (WARNING: deletes data)
```

### Health & Status

```bash
make health     # Check all services
make status     # Show running containers
```

### Cleanup

```bash
make clean          # Remove containers and networks
make clean-volumes  # Remove volumes
make clean-all      # Full cleanup including images
```

## Environment Configuration

### Development (.env.development)
```env
MONGO_INITDB_ROOT_USERNAME=devuser
MONGO_INITDB_ROOT_PASSWORD=devpassword
MONGO_DATABASE=ecommerce
BACKEND_PORT=3847
GATEWAY_PORT=5921
NODE_ENV=development
```

### Production (.env.production)
```env
MONGO_INITDB_ROOT_USERNAME=secure_prod_user
MONGO_INITDB_ROOT_PASSWORD=secure_password_here
MONGO_DATABASE=ecommerce_prod
BACKEND_PORT=3847
GATEWAY_PORT=5921
NODE_ENV=production
```

## Architecture Overview

- **Gateway** (port 5921): Single entry point for all external requests
- **Backend** (port 3847): Internal microservice, not exposed
- **MongoDB** (port 27017): Internal database, not exposed
- **Network**: Custom Docker bridge network (`app-network`) for secure inter-service communication

## Troubleshooting

### Services not starting?
```bash
make logs SERVICE=backend    # Check backend logs
make logs SERVICE=gateway    # Check gateway logs
make logs SERVICE=mongo      # Check MongoDB logs
```

### Port already in use?
```bash
docker ps              # See what's running
make clean            # Stop all containers
make clean-all        # Nuclear option
```

### Database issues?
```bash
make mongo-shell      # Access MongoDB directly
make db-backup        # Backup before making changes
make db-reset         # Reset database if corrupted
```

## Best Practices Implemented

1. **Separation of Concerns**: Each service in its own container
2. **Data Persistence**: Named volumes for production data
3. **Health Checks**: All services have health checks
4. **Resource Limits**: Production containers have CPU/memory limits
5. **Logging**: Structured logging with timestamps
6. **Security**: Multiple security layers (CORS, headers, sanitization)
7. **Graceful Shutdown**: Proper signal handling
8. **CI/CD Ready**: Makefile enables easy automation
9. **Developer Experience**: Simple commands for common tasks
10. **Production Hardening**: Read-only filesystems, non-root users

## Project Structure

```
.
├── backend/
│   ├── Dockerfile          # Production multi-stage build
│   ├── Dockerfile.dev      # Development with hot-reload
│   ├── .dockerignore       # Optimize build context
│   ├── package.json
│   ├── tsconfig.json
│   └── src/
│       ├── index.ts        # Enhanced with security middleware
│       ├── config/
│       │   ├── db.ts
│       │   ├── envConfig.ts
│       │   └── index.ts
│       ├── models/
│       │   └── product.ts
│       ├── routes/
│       │   └── products.ts
│       └── types/
│           ├── index.ts
│           └── product.ts
├── gateway/
│   ├── Dockerfile          # Production optimized
│   ├── Dockerfile.dev      # Development with hot-reload
│   ├── .dockerignore       # Optimize build context
│   ├── package.json
│   └── src/
│       └── gateway.js      # Enhanced with security & error handling
├── docker/
│   ├── compose.development.yaml  # Dev environment setup
│   └── compose.production.yaml   # Production setup with security hardening
├── .env.development   # Dev environment variables
├── .env.production    # Production environment variables
├── Makefile          # Complete DevOps CLI
└── README.md         # This file
```

## Next Steps / Future Enhancements

1. **Kubernetes**: Convert Docker Compose to Kubernetes manifests
2. **Monitoring**: Add Prometheus/Grafana for metrics
3. **Logging**: Implement ELK stack for centralized logging
4. **CI/CD**: Add GitHub Actions for automated testing and deployment
5. **API Gateway**: Consider adding Kong or Traefik
6. **Rate Limiting**: Implement rate limiting in gateway
7. **Caching**: Add Redis for caching layer
8. **Load Balancing**: Add multiple backend instances with load balancing
9. **HTTPS/TLS**: Configure SSL certificates for production
10. **Database Replication**: Set up MongoDB replica sets

### Health Checks

Check gateway health:
```bash
curl http://localhost:5921/health
```

Check backend health via gateway:
```bash
curl http://localhost:5921/api/health
```

### Product Management

Create a product:
```bash
curl -X POST http://localhost:5921/api/products \
  -H 'Content-Type: application/json' \
  -d '{"name":"Test Product","price":99.99}'
```

Get all products:
```bash
curl http://localhost:5921/api/products
```

### Security Test

Verify backend is not directly accessible (should fail or be blocked):
```bash
curl http://localhost:3847/api/products
```

## Submission Process

1. **Fork the Repository**
   - Fork this repository to your GitHub account
   - Push the solution 5-10 before the contest ends
   - Also you can have your own private repo

2. **Make Repository Public**
   - In the **last 5 minutes** of the contest, make your repository **public**
   - Repositories that remain private after the contest ends will not be evaluated

3. **Submit Repository URL**
   - Submit your repository URL at [arena.bongodev.com](https://arena.bongodev.com)
   - Ensure the URL is correct and accessible

4. **Code Evaluation**
   - All submissions will be both **automated and manually evaluated**
   - Plagiarism and code copying will result in disqualification

## Rules

- ⚠️ **NO COPYING**: All code must be your original work. Copying code from other participants or external sources will result in immediate disqualification.

- ⚠️ **NO POST-CONTEST COMMITS**: Pushing any commits to the git repository after the contest ends will result in **disqualification**. All work must be completed and committed before the contest deadline.

- ✅ **Repository Visibility**: Keep your repository private during the contest, then make it public in the last 5 minutes.

- ✅ **Submission Deadline**: Ensure your repository is public and submitted before the contest ends.

Good luck!

