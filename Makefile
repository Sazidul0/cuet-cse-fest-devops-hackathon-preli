.PHONY: help up down build logs restart shell ps clean clean-all clean-volumes health \
  dev-up dev-down dev-build dev-logs dev-restart dev-shell dev-ps \
  prod-up prod-down prod-build prod-logs prod-restart \
  backend-shell gateway-shell mongo-shell backend-build backend-install backend-type-check backend-dev \
  db-reset db-backup status

# Default values
MODE ?= dev
SERVICE ?= backend
ARGS ?=
SERVICES ?=

# Determine compose file and env file based on MODE
ifeq ($(MODE),dev)
  COMPOSE_FILE = docker/compose.development.yaml
  ENV_FILE = .env.development
else ifeq ($(MODE),prod)
  COMPOSE_FILE = docker/compose.production.yaml
  ENV_FILE = .env.production
else
  COMPOSE_FILE = docker/compose.$(MODE).yaml
  ENV_FILE = .env.$(MODE)
endif

# Default target
help:
	@echo "Docker Services (Development/Production):"
	@echo "  up           - Start services (use: make up [service...] or make up MODE=prod)"
	@echo "  down         - Stop services (use: make down [service...] or make down MODE=prod)"
	@echo "  build        - Build containers (use: make build [service...] or make build MODE=prod)"
	@echo "  logs         - View logs (use: make logs SERVICE=backend or make logs MODE=prod)"
	@echo "  restart      - Restart services (use: make restart [service...] or make restart MODE=prod)"
	@echo "  shell        - Open shell in container (use: make shell SERVICE=gateway or make shell MODE=prod)"
	@echo "  ps           - Show running containers (use MODE=prod for production)"
	@echo "  status       - Alias for ps"
	@echo "  health       - Check service health"
	@echo ""
	@echo "Development Aliases:"
	@echo "  dev-up       - Start development services"
	@echo "  dev-down     - Stop development services"
	@echo "  dev-build    - Build development containers"
	@echo "  dev-logs     - View development logs"
	@echo "  dev-restart  - Restart development services"
	@echo "  dev-shell    - Open shell in backend container"
	@echo "  dev-ps       - Show running development containers"
	@echo ""
	@echo "Production Aliases:"
	@echo "  prod-up      - Start production services"
	@echo "  prod-down    - Stop production services"
	@echo "  prod-build   - Build production containers"
	@echo "  prod-logs    - View production logs"
	@echo "  prod-restart - Restart production services"
	@echo ""
	@echo "Container Access:"
	@echo "  backend-shell - Open shell in backend container"
	@echo "  gateway-shell - Open shell in gateway container"
	@echo "  mongo-shell   - Open MongoDB shell"
	@echo ""
	@echo "Backend:"
	@echo "  backend-build       - Build backend TypeScript"
	@echo "  backend-install     - Install backend dependencies"
	@echo "  backend-type-check  - Type check backend code"
	@echo "  backend-dev         - Run backend in development mode (local, not Docker)"
	@echo ""
	@echo "Database:"
	@echo "  db-reset   - Reset MongoDB database (WARNING: deletes all data)"
	@echo "  db-backup  - Backup MongoDB database"
	@echo ""
	@echo "Cleanup:"
	@echo "  clean       - Remove containers and networks (both dev and prod)"
	@echo "  clean-all   - Remove containers, networks, volumes, and images"
	@echo "  clean-volumes - Remove all volumes"
	@echo ""

# Docker Compose Commands
up:
	@echo "Starting $(MODE) environment..."
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) up -d $(SERVICES)
	@echo "✓ Services started"

down:
	@echo "Stopping $(MODE) environment..."
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) down $(ARGS)
	@echo "✓ Services stopped"

build:
	@echo "Building $(MODE) containers..."
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) build $(ARGS) $(SERVICES)
	@echo "✓ Build complete"

logs:
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) logs -f $(SERVICE)

restart:
	@echo "Restarting $(MODE) services..."
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) restart $(SERVICES)
	@echo "✓ Services restarted"

shell:
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec $(SERVICE) sh

ps:
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) ps

# Convenience Aliases - Development
dev-up:
	@$(MAKE) up MODE=dev

dev-down:
	@$(MAKE) down MODE=dev

dev-build:
	@$(MAKE) build MODE=dev

dev-logs:
	@$(MAKE) logs MODE=dev SERVICE=backend

dev-restart:
	@$(MAKE) restart MODE=dev

dev-shell:
	@$(MAKE) shell MODE=dev SERVICE=backend

dev-ps:
	@$(MAKE) ps MODE=dev

# Convenience Aliases - Production
prod-up:
	@$(MAKE) up MODE=prod

prod-down:
	@$(MAKE) down MODE=prod

prod-build:
	@$(MAKE) build MODE=prod

prod-logs:
	@$(MAKE) logs MODE=prod SERVICE=backend

prod-restart:
	@$(MAKE) restart MODE=prod

# Container Access
backend-shell:
	@$(MAKE) shell SERVICE=app-backend-$(MODE)

gateway-shell:
	@$(MAKE) shell SERVICE=app-gateway-$(MODE)

mongo-shell:
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec mongo mongosh -u $${MONGO_INITDB_ROOT_USERNAME} -p $${MONGO_INITDB_ROOT_PASSWORD} --authenticationDatabase admin

# Backend commands
backend-build:
	@echo "Building backend TypeScript..."
	@cd backend && npm run build

backend-install:
	@echo "Installing backend dependencies..."
	@cd backend && npm install

backend-type-check:
	@echo "Type checking backend..."
	@cd backend && npm run type-check

backend-dev:
	@echo "Running backend in development mode..."
	@cd backend && npm run dev

# Database commands
db-reset:
	@echo "⚠️  WARNING: This will delete all data from MongoDB!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ] && \
		docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec mongo mongosh -u $${MONGO_INITDB_ROOT_USERNAME} -p $${MONGO_INITDB_ROOT_PASSWORD} --authenticationDatabase admin --eval "db.dropDatabase();" || echo "Cancelled"

db-backup:
	@echo "Backing up MongoDB..."
	@mkdir -p ./backups
	@BACKUP_NAME=backup_$$(date +%Y%m%d_%H%M%S) && \
		docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec -T mongo mongodump --username $${MONGO_INITDB_ROOT_USERNAME} --password $${MONGO_INITDB_ROOT_PASSWORD} --authenticationDatabase admin --out /tmp/$$BACKUP_NAME && \
		docker cp app-mongo-$(MODE):/tmp/$$BACKUP_NAME ./backups/$$BACKUP_NAME && \
		echo "✓ Backup saved to ./backups/$$BACKUP_NAME"

# Health checks
health:
	@echo "Checking service health..."
	@echo ""
	@echo "Gateway:"
	@curl -s http://localhost:5921/health | jq . || echo "Gateway not responding"
	@echo ""
	@echo "Backend:"
	@curl -s http://localhost:3847/api/health | jq . || echo "Backend not responding"
	@echo ""
	@echo "MongoDB:"
	@docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE) exec -T mongo mongosh -u $${MONGO_INITDB_ROOT_USERNAME} -p $${MONGO_INITDB_ROOT_PASSWORD} --authenticationDatabase admin --eval "db.adminCommand('ping')" 2>/dev/null || echo "MongoDB not responding"

# Status alias
status:
	@$(MAKE) ps

# Cleanup commands
clean:
	@echo "Cleaning up development containers and networks..."
	@docker compose -f docker/compose.development.yaml down
	@echo "Cleaning up production containers and networks..."
	@docker compose -f docker/compose.production.yaml down
	@echo "✓ Cleanup complete"

clean-volumes:
	@echo "Removing all volumes..."
	@docker volume rm app-mongo-dev mongo-data-dev mongo-config-dev app-mongo-prod mongo-data-prod mongo-config-prod 2>/dev/null || true
	@echo "✓ Volumes removed"

clean-all: clean clean-volumes
	@echo "Removing images..."
	@docker compose -f docker/compose.development.yaml down -v --rmi all 2>/dev/null || true
	@docker compose -f docker/compose.production.yaml down -v --rmi all 2>/dev/null || true
	@echo "✓ Full cleanup complete"

.DEFAULT_GOAL := help

