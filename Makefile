.PHONY: help services-up services-down services-status backend-setup backend-dev \
        backend-test backend-check app-setup app-test app-run check

MONGO_BIN := /opt/homebrew/opt/mongodb-community@8.0/bin
REDIS_BIN := /opt/homebrew/opt/redis/bin
STORY_HOME := $(HOME)/.story-local

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'

services-up: ## Start local MongoDB and Redis
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

services-down: ## Stop local MongoDB and Redis
	@$(REDIS_BIN)/redis-cli shutdown nosave 2>/dev/null || true
	@pkill -f "mongod --dbpath $(STORY_HOME)" 2>/dev/null || true
	@echo "services stopped"

backend-setup: ## Install backend dependencies and seed .env
	cd backend && uv sync && [ -f .env ] || cp backend/.env.example backend/.env

backend-dev: ## Run the API with reload
	cd backend && uv run uvicorn app.main:app --reload --host 127.0.0.1 --port 9000

backend-test: ## Run backend tests
	cd backend && uv run pytest -q

backend-check: ## Lint and test the backend
	cd backend && uv run ruff check . && uv run ruff format --check . && uv run pytest -q

app-setup: ## Install app dependencies
	cd app && flutter pub get

app-test: ## Analyze and test the app
	cd app && flutter analyze && flutter test

app-run: ## Run the app on the connected device
	cd app && flutter run

backend-dev-testing: ## Run the API with rate limits off against the e2e database
	cd backend && RATE_LIMIT_ENABLED=false MONGODB_DB_NAME=story_e2e \
		uv run uvicorn app.main:app --host 127.0.0.1 --port 9000

e2e: ## Start a test-profile API on its own database, run the app suite, tear down
	@cd backend && RATE_LIMIT_ENABLED=false MONGODB_DB_NAME=story_e2e \
		uv run uvicorn app.main:app \
		--host 127.0.0.1 --port 9000 > /tmp/story-e2e.log 2>&1 & \
		echo $$! > /tmp/story-e2e.pid
	@until curl -sf --max-time 2 http://127.0.0.1:9000/v1/health/ready >/dev/null; do sleep 1; done
	@cd app && flutter test; status=$$?; \
		kill `cat /tmp/story-e2e.pid` 2>/dev/null; rm -f /tmp/story-e2e.pid; \
		exit $$status

e2e-reset: ## Drop the e2e database
	@mongosh --quiet --eval 'db.getSiblingDB("story_e2e").dropDatabase()' >/dev/null
	@echo "story_e2e dropped"

web-setup: ## Install web dependencies
	cd web && pnpm install && cp -n .env.example .env.local || true

web-dev: ## Run the user web app
	cd web && pnpm dev -p 3100

web-build: ## Production build of the user web app
	cd web && pnpm build

admin-setup: ## Install admin dependencies
	cd admin && pnpm install

admin-dev: ## Run the admin app
	cd admin && pnpm dev -p 3200

admin-build: ## Production build of the admin app
	cd admin && pnpm build

promote: ## Give an account a staff role: make promote USER=name ROLE=admin
	@cd backend && uv run python -c "\
import asyncio,sys; from motor.motor_asyncio import AsyncIOMotorClient; \
async def go(): \
    c=AsyncIOMotorClient('mongodb://127.0.0.1:27017'); \
    r=await c['story_local']['users'].update_one({'username_lower':'$(USER)'},{'\$$set':{'role':'$(ROLE)'}}); \
    print('updated' if r.modified_count else 'no such account'); \
asyncio.run(go())"

tokens: ## Regenerate design tokens for web and admin
	python3 tools/generate_tokens.py

check: backend-check app-test ## Everything CI runs

secrets: ## Generate strong secrets into backend/.env
	@cd backend && python3 -c "import re,secrets,string,pathlib; \
a=string.ascii_letters+string.digits; \
p=pathlib.Path('.env'); t=p.read_text(); \
[t := re.sub(rf'^{n}=.*$$', n+'='+''.join(secrets.choice(a) for _ in range(48)), t, flags=re.M) \
 for n in ('JWT_SECRET','EMAIL_INDEX_KEY','EMAIL_ENCRYPTION_KEY','OTP_HMAC_SECRET')]; \
p.write_text(t); print('secrets rotated in backend/.env')"
