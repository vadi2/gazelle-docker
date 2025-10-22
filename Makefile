.PHONY: help build up down restart logs logs-jboss logs-postgres clean status shell-jboss shell-postgres backup restore

# Detect docker compose command (supports both old and new syntax)
DOCKER_COMPOSE := $(shell command -v docker-compose 2>/dev/null)
ifndef DOCKER_COMPOSE
	DOCKER_COMPOSE := docker compose
endif

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Initial setup - copy .env.example to .env
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "Created .env file. Please edit it with your configuration."; \
	else \
		echo ".env file already exists."; \
	fi
	@mkdir -p deployments
	@echo "Setup complete. Place your XDStarClient.ear in the deployments/ directory."

build: ## Build Docker images
	$(DOCKER_COMPOSE) build

up: ## Start all services
	$(DOCKER_COMPOSE) up -d

down: ## Stop all services
	$(DOCKER_COMPOSE) down

restart: ## Restart all services
	$(DOCKER_COMPOSE) restart

restart-jboss: ## Restart only JBoss service
	$(DOCKER_COMPOSE) restart jboss

restart-postgres: ## Restart only PostgreSQL service
	$(DOCKER_COMPOSE) restart postgres

logs: ## View logs from all services
	$(DOCKER_COMPOSE) logs -f

logs-jboss: ## View logs from JBoss
	$(DOCKER_COMPOSE) logs -f jboss

logs-postgres: ## View logs from PostgreSQL
	$(DOCKER_COMPOSE) logs -f postgres

status: ## Show status of all services
	$(DOCKER_COMPOSE) ps

shell-jboss: ## Open shell in JBoss container
	$(DOCKER_COMPOSE) exec jboss /bin/bash

shell-postgres: ## Open shell in PostgreSQL container
	$(DOCKER_COMPOSE) exec postgres /bin/bash

psql: ## Connect to PostgreSQL database
	$(DOCKER_COMPOSE) exec postgres psql -U gazelle -d xdstar-client

backup: ## Backup PostgreSQL database
	@mkdir -p backups
	@BACKUP_FILE=backups/xdstar-client-$$(date +%Y%m%d-%H%M%S).sql; \
	$(DOCKER_COMPOSE) exec -T postgres pg_dump -U gazelle xdstar-client > $$BACKUP_FILE; \
	echo "Database backed up to $$BACKUP_FILE"

restore: ## Restore PostgreSQL database (usage: make restore FILE=backups/file.sql)
	@if [ -z "$(FILE)" ]; then \
		echo "Error: Please specify FILE=path/to/backup.sql"; \
		exit 1; \
	fi
	$(DOCKER_COMPOSE) exec -T postgres psql -U gazelle -d xdstar-client < $(FILE)
	@echo "Database restored from $(FILE)"

deploy: ## Deploy XDStarClient.ear from deployments directory
	@if [ ! -f deployments/XDStarClient.ear ]; then \
		echo "Error: deployments/XDStarClient.ear not found"; \
		exit 1; \
	fi
	docker cp deployments/XDStarClient.ear gazelle-jboss:/opt/jboss/standalone/deployments/
	@echo "XDStarClient.ear deployed. Monitoring deployment logs..."
	@sleep 2
	$(DOCKER_COMPOSE) logs -f jboss

clean: ## Stop services and remove volumes (WARNING: deletes all data)
	@echo "WARNING: This will delete all data including database and uploaded files!"
	@read -p "Are you sure? (y/N) " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(DOCKER_COMPOSE) down -v; \
		echo "All services stopped and volumes removed."; \
	else \
		echo "Cancelled."; \
	fi

clean-images: ## Remove Docker images
	$(DOCKER_COMPOSE) down
	docker rmi gazelle-docker_jboss || true

rebuild: ## Rebuild and restart all services
	$(DOCKER_COMPOSE) down
	$(DOCKER_COMPOSE) build --no-cache
	$(DOCKER_COMPOSE) up -d

health: ## Check health status of services
	@echo "Checking PostgreSQL health..."
	@docker inspect gazelle-postgres --format='{{.State.Health.Status}}' 2>/dev/null || echo "Container not running"
	@echo "Checking JBoss health..."
	@docker inspect gazelle-jboss --format='{{.State.Health.Status}}' 2>/dev/null || echo "Container not running"

stats: ## Show resource usage statistics
	docker stats --no-stream gazelle-postgres gazelle-jboss
