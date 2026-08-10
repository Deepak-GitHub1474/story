.PHONY: help setup dev test check format format-check dev-testing \
        services-up services-down services-status \
        docker-up docker-down e2e-reset promote secrets

MONGO_BIN := /opt/homebrew/opt/mongodb-community@8.0/bin
REDIS_BIN := /opt/homebrew/opt/redis/bin
STORY_HOME := $(HOME)/.story-local

help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-16s %s\n", $$1, $$2}'

setup: ## Install dependencies and seed .env
	uv sync
	@[ -f .env ] || { cp .env.example .env; echo ".env created from .env.example"; }

dev: ## Run the API with reload on http://127.0.0.1:9000
	uv run uvicorn app.main:app --reload --host 127.0.0.1 --port 9000

test: ## Run the test suite
	uv run pytest -q

check: ## Lint and test
	uv run ruff check .
	uv run pytest -q

format: ## Rewrite files to ruff format style
	uv run ruff format .

format-check: ## Report files ruff format would rewrite
	uv run ruff format --check .

dev-testing: ## Run the API with rate limits off against the e2e database
	RATE_LIMIT_ENABLED=false MONGODB_DB_NAME=story_e2e \
		uv run uvicorn app.main:app --host 127.0.0.1 --port 9000

services-up: ## Start MongoDB and Redis natively
	@mkdir -p $(STORY_HOME)/mongo-data $(STORY_HOME)/log
	@$(MONGO_BIN)/mongod --dbpath $(STORY_HOME)/mongo-data \
		--logpath $(STORY_HOME)/log/mongod.log --bind_ip 127.0.0.1 --port 27017 --fork \
		|| echo "mongod already running"
	@$(REDIS_BIN)/redis-server --port 6379 --bind 127.0.0.1 --daemonize yes \
		--dir $(STORY_HOME) --appendonly yes || echo "redis already running"
	@$(MAKE) services-status

services-status: ## Ping both services for real
	@$(REDIS_BIN)/redis-cli ping | sed 's/^/redis:  /'
	@$(MONGO_BIN)/mongod --version >/dev/null && \
		(nc -z 127.0.0.1 27017 && echo "mongo:  PONG" || echo "mongo:  DOWN")

services-down: ## Stop MongoDB and Redis
	@$(REDIS_BIN)/redis-cli shutdown nosave 2>/dev/null || true
	@pkill -f "mongod --dbpath $(STORY_HOME)" 2>/dev/null || true
	@echo "services stopped"

docker-up: ## Start MongoDB and Redis in containers instead
	docker compose -f docker-compose.dev.yml up -d

docker-down: ## Stop the container services
	docker compose -f docker-compose.dev.yml down

e2e-reset: ## Drop the e2e database
	@mongosh --quiet --eval 'db.getSiblingDB("story_e2e").dropDatabase()' >/dev/null
	@echo "story_e2e dropped"

promote: ## Give an account a staff role: make promote USER=name ROLE=admin
	@uv run python -c "\
import asyncio,sys; from motor.motor_asyncio import AsyncIOMotorClient; \
async def go(): \
    c=AsyncIOMotorClient('mongodb://127.0.0.1:27017'); \
    r=await c['story_local']['users'].update_one({'username_lower':'$(USER)'},{'\$$set':{'role':'$(ROLE)'}}); \
    print('updated' if r.modified_count else 'no such account'); \
asyncio.run(go())"

secrets: ## Generate strong secrets into .env
	@python3 -c "import re,secrets,string,pathlib; \
a=string.ascii_letters+string.digits; \
p=pathlib.Path('.env'); t=p.read_text(); \
[t := re.sub(rf'^{n}=.*$$', n+'='+''.join(secrets.choice(a) for _ in range(48)), t, flags=re.M) \
 for n in ('JWT_SECRET','EMAIL_INDEX_KEY','EMAIL_ENCRYPTION_KEY','OTP_HMAC_SECRET')]; \
p.write_text(t); print('secrets rotated in .env')"
