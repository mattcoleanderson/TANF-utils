# AGENTS.md

This file provides guidance to coding agents working in this repository.

## 🚨 CRITICAL: Test-Driven Development Workflow

**READ THIS FIRST - Apply to ALL code changes:**

1. **Make your code changes** (edit, add, or modify files)
2. **IMMEDIATELY run tests using the `test` skill**
   - Use `/test backend <path>` for backend tests
   - Use `/test frontend <pattern>` for frontend tests
3. **If tests fail:**
   - Review the detailed failure report
   - Prefer fixing tests first, assuming current app behavior is correct
   - Modify source code only when the failure output and surrounding code clearly show an implementation defect
   - Re-run tests with the `test` skill
   - **Repeat until ALL tests pass**
4. **Never proceed to the next task with failing tests**

**The `test` skill:**
- Executes tests in a tmux pane (non-blocking)
- Captures complete output with `-S -` (no truncation)
- Provides detailed failure analysis
- Suggests fixes for common issues

**When to use the `test` skill:**
- ✅ After editing any Python file in `tdrs-backend/`
- ✅ After editing any JavaScript/JSX file in `tdrs-frontend/src/`
- ✅ After adding new features or fixing bugs
- ✅ Before creating pull requests
- ✅ When explicitly asked to run tests

## Project Overview

TDP (TANF Data Portal) is a secure, web-based data reporting system for TANF (Temporary Assistance for Needy Families) grantees and federal staff. The system replaces the legacy TANF Data Reporting System (TDRS) and allows grantees to submit accurate data while improving data quality for policy and program decision-making.

**Architecture**: Decoupled Django REST Framework backend (`tdrs-backend`) and React frontend (`tdrs-frontend`), deployed to Cloud.gov.

**Authentication**: Dual authentication strategy using ACF AMS for internal ACF users (PIV) and Login.gov for external users, both requiring MFA.

**Main Branch**: `develop` (not `main` or `master`) - use this for PRs.

## Development Commands

All commands use [Task](https://taskfile.dev) (not npm scripts or make). Run `task --list` to see all available tasks.

### Backend (Django)

Located in `tdrs-backend/` directory.

**Setup & Running:**
```bash
# Initial setup (creates network, builds containers, runs migrations)
task init-backend

# Start backend server (http://localhost:8080)
task backend-up

# Stop backend server
task backend-down

# Restart backend server
task backend-restart

# View logs
task backend-logs

# Drop database completely
task drop-db
```

**Development:**
```bash
# Open bash shell in container
task backend-bash

# Open Django shell (with shell_plus)
task backend-shell

# Execute Django management command
task backend-exec CMD="makemigrations"
task backend-exec CMD="migrate"

# Seed database
task backend-exec-seed-db

# Access PostgreSQL
task psql
```

**Testing & Quality:**
```bash
# Run all pytest tests
task backend-pytest

# Run specific tests (pass pytest args)
task backend-pytest PYTEST_ARGS="tdpservice/reports/test/test_models.py -v"
task backend-pytest PYTEST_ARGS="tdpservice/parsers/test/ -s -vv"

# Run tests with coverage
task backend-pytest-cov

# Linting (flake8)
task backend-lint
```

### Frontend (React)

Located in `tdrs-frontend/` directory.

**Running:**
```bash
# Start frontend server (http://localhost:3000)
task frontend-up

# Stop frontend server
task frontend-down

# Restart frontend server
task frontend-restart

# View logs
task frontend-logs

# Open shell in container
task frontend-bash
```

**Testing & Quality:**
```bash
# Run unit tests
task frontend-test

# Run tests with coverage
task frontend-test-cov

# Run Cypress e2e tests
task cypress

# Linting (eslint)
task frontend-lint
```

### Full Stack

```bash
# Start both frontend and backend
task up

# Stop both frontend and backend
task down
```

## Architecture & Code Structure

### Backend (`tdrs-backend/tdpservice/`)

Django app structure with these key modules:

- **`users/`** - User models, authentication, permissions, and role-based access control (RBAC)
- **`data_files/`** - File upload handling, S3 storage, error reports
- **`parsers/`** - TANF data parsing logic, validators, schema definitions, field definitions
- **`reports/`** - Report models and feedback system
- **`stts/`** - State, Tribe, and Territory models
- **`search_indexes/`** - Elasticsearch integration for data search
- **`security/`** - Security models and ClamAV antivirus integration
- **`scheduling/`** - Celery task scheduling
- **`settings/`** - Environment-specific Django settings (common.py, development.py, production.py, etc.)

**Key Files:**
- `conftest.py` - Pytest fixtures and test configuration
- `urls.py` - Main URL routing
- `backends.py` - Custom authentication backends

**AWS Integration**: Uses localstack for local S3 simulation. Always use `get_s3_client()` from `tdpservice.clients` instead of `boto3.client()` directly - this ensures proper routing between localstack (local/CI) and production AWS.

### Frontend (`tdrs-frontend/src/`)

React app using Redux for state management, React Router for navigation, and USWDS (U.S. Web Design System) for UI components.

- **`components/`** - React components (Header, Footer, FileUpload, etc.)
- **`actions/`** - Redux action creators
- **`reducers/`** - Redux reducers
- **`selectors/`** - Redux selectors
- **`utils/`** - Utility functions
- **`hooks/`** - Custom React hooks

**Environment Variables**: Uses Create React App's `.env` file system. Variables must be prefixed with `REACT_APP_` to be accessible in the app.

### Key Architectural Decisions

- **ADR 002**: Backend is Django REST Framework, frontend is React
- **ADR 005**: ACF AMS for internal users, Login.gov for external users
- **ADR 003**: Cloud.gov (PaaS) for hosting
- **ADR 007**: AWS S3 for object storage (with localstack for local dev)

See `docs/Technical-Documentation/Architecture-Decision-Record/` for all ADRs.

## Testing

**CRITICAL TESTING WORKFLOW:**
1. **Run tests after making code changes** to verify nothing broke
2. **If tests fail, fix either the tests or the code until all tests pass**
3. **Never leave broken tests** - iterate until the test suite is green

### Using the `/test` Skill

Use the `test` skill for test execution with detailed failure analysis:

```
/test                              # Prompts for what to test
/test backend                      # Run all backend tests
/test frontend                     # Run all frontend tests
/test backend tdpservice/reports/  # Run specific backend module
/test frontend Header              # Run frontend tests matching "Header"
/test backend-cov                  # Backend tests with coverage
/test frontend-cov                 # Frontend tests with coverage
```

The skill uses background execution to capture complete output without truncation.

### Backend Testing

- **Framework**: pytest with pytest-django
- **Fixtures**: Defined in `conftest.py` files throughout the codebase
- **Factory Pattern**: Uses factory-boy for test data generation
- **Coverage Target**: 90% (statements, branches, functions, lines)

### Frontend Testing

- **Unit Tests**: Jest with enzyme and React Testing Library
- **E2E Tests**: Cypress
- **Accessibility**: Pa11y for automated a11y testing
- **Coverage Target**: 90% (configured in `package.json`)

**⚠️ CRITICAL: Frontend tests MUST include `--watchAll=false`**

Without `--watchAll=false`, Jest enters watch mode and waits forever for keyboard input. The `test` skill handles this automatically.

### CI/CD

CircleCI runs all tests on every push. Configuration uses dynamic setup in `.circleci/config.yml` which generates workflows based on `generate_config.sh`.

## Database Migrations

**Important**: Always check for migration conflicts before creating new migrations.

```bash
# Create migrations
task backend-exec CMD="makemigrations"

# Apply migrations
task backend-exec CMD="migrate"

# Show migration status
task backend-exec CMD="showmigrations"
```

See `docs/Technical-Documentation/migration-best-practices.md` for detailed guidance.

## Environment Variables

### Backend

- Local: `.env` file in `tdrs-backend/` (copy from `.env.example`)
- Never commit secrets - use `.env` for local overrides only
- Production secrets managed via Cloud.gov environment variables

### Frontend

- Environment-specific: `.env.development`, `.env.test`, `.env.production`
- Local overrides: `.env.local`, `.env.development.local`, etc.
- All variables must start with `REACT_APP_` to be accessible

## File Upload & Parsing

The system parses TANF data files uploaded by grantees:

1. Files uploaded via frontend (`FileUpload` component)
2. Files scanned by ClamAV antivirus
3. Stored in S3 (`data_files/` module)
4. Parsed by validators in `parsers/` module
5. Errors generated and stored (`error_generator.py`, `error_reports.py`)
6. Results searchable via Elasticsearch (`search_indexes/`)

**Parser Structure**: Schema-based validation using `row_schema.py`, `fields.py`, and validators in `parsers/validators/`.

## Common Workflows

### Adding a New Django Model

1. Create model in appropriate app's `models.py`
2. Create migration: `task backend-exec CMD="makemigrations"`
3. Apply migration: `task backend-exec CMD="migrate"`
4. Add to admin if needed in `admin.py`
5. Write tests in `test/` directory
6. **Run tests with `/test backend <module>`**
7. **Fix any failing tests** - iterate until all tests pass

### Adding a New React Component

1. Create directory in `src/components/ComponentName/`
2. Add `ComponentName.jsx` and `ComponentName.test.js`
3. Write tests first (TDD approach encouraged)
4. Implement the component
5. **Run tests with `/test frontend <ComponentName>`**
6. **Fix any failing tests** - iterate until all tests pass
7. Ensure 90% coverage with `/test frontend-cov`
8. Run linter: `task frontend-lint`

### Modifying Existing Code

**CRITICAL: Always test after modifications!**

1. Make your code changes
2. **IMMEDIATELY run tests with `/test`**
   - Backend changes → `/test backend <affected-module>`
   - Frontend changes → `/test frontend <pattern>`
3. **If tests fail:**
   - Analyze the failure report
   - Prefer fixing tests first, assuming current app behavior is correct
   - Modify source code only when the failure output and surrounding code clearly show an implementation defect
   - Make fixes
   - Re-run tests with the `test` skill
   - **Repeat until all tests pass**
4. Never commit code with failing tests

### Running Tests for Specific Module

Use the `test` skill:
```
/test backend tdpservice/reports/test/   # Run specific backend module
/test frontend ComponentName              # Run specific frontend tests
/test backend-cov tdpservice/parsers/    # Backend with coverage
/test frontend-cov                        # Frontend with coverage
```

See `.agents/skills/test/SKILL.md` for complete command reference.

## Docker & Container Management

All services run in Docker containers orchestrated by docker-compose:

- **Backend**: Django app + Postgres + Localstack (S3) + ZAP (security scanning)
- **Frontend**: React app served via nginx
- **Network**: External network `external-net` created by `task create-network`

**Volumes**: Database and localstack data persisted in Docker named volumes. Remove with `task backend-remove-volumes` to reset state.

## Security & Compliance

- **Authentication**: All endpoints require authentication (except health checks)
- **Authorization**: Role-based permissions in `users/permissions.py`
- **File Scanning**: All uploads scanned by ClamAV before processing
- **OWASP ZAP**: Security scanning in CI/CD pipeline
- **Secrets Management**: Vault integration (see `vault/`)
- **CSP**: Content Security Policy configured via django-csp

## Deployment

**DO NOT** manually deploy unless absolutely necessary - CircleCI handles deployments.

- **develop** branch → deploys to staging environment
- **main/master** branch → deploys to production environment
- Cloud.gov spaces: `tanf-dev`, `tanf-staging`, `tanf-prod`

See `docs/Technical-Documentation/TDP-environments-README.md` for environment details.

## Documentation

- **Architecture Decisions**: `docs/Technical-Documentation/Architecture-Decision-Record/`
- **User Research**: `docs/User-Experience/`
- **Technical Docs**: `docs/Technical-Documentation/`
- **Sprint Reviews**: `docs/Sprint-Review/`
- **API Docs**: Available at `/swagger/` and `/redoc/` when backend is running

## Troubleshooting

**Backend won't start:**
- Check `.env` file exists and has required variables
- Try `task drop-db` then `task init-backend`
- Check logs: `task backend-logs`

**Frontend won't connect to backend:**
- Ensure backend is running: `task backend-up`
- Check `REACT_APP_BACKEND_URL` in frontend `.env` files
- Verify CORS settings in backend `settings/common.py`

**Tests failing:**
- Backend: Ensure containers are up: `task backend-up`
- Frontend: Clear cache: `cd tdrs-frontend && npm test -- --clearCache`
- Check for conflicting migrations

**Database issues:**
- Reset database: `task drop-db` then `task init-backend`
- Access DB directly: `task psql`
- Check migration status: `task backend-exec CMD="showmigrations"`
