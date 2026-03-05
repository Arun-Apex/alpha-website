#!/usr/bin/env bash

set -e

# Root folder
mkdir -p Clickup-auth/erp/src/config
mkdir -p Clickup-auth/erp/src/db/migrations
mkdir -p Clickup-auth/erp/src/modules/clickup
mkdir -p Clickup-auth/erp/src/utils
mkdir -p Clickup-auth/erp/scripts

# Root files
touch Clickup-auth/erp/docker-compose.yml
touch Clickup-auth/erp/package.json

# src root
touch Clickup-auth/erp/src/server.js

# config
touch Clickup-auth/erp/src/config/index.js

# db
touch Clickup-auth/erp/src/db/index.js
touch Clickup-auth/erp/src/db/migrations/001_create_clickup_tables.sql
touch Clickup-auth/erp/src/db/migrations/002_indexes.sql

# clickup module
touch Clickup-auth/erp/src/modules/clickup/clickupClient.js
touch Clickup-auth/erp/src/modules/clickup/clickupMapper.js
touch Clickup-auth/erp/src/modules/clickup/clickupRepo.js
touch Clickup-auth/erp/src/modules/clickup/clickupSyncService.js
touch Clickup-auth/erp/src/modules/clickup/clickupRoutes.js
touch Clickup-auth/erp/src/modules/clickup/clickupWorker.js

# utils
touch Clickup-auth/erp/src/utils/logger.js
touch Clickup-auth/erp/src/utils/sleep.js
touch Clickup-auth/erp/src/utils/validate.js

# scripts
touch Clickup-auth/erp/scripts/migrate.js

echo "✅ Clickup-auth ERP structure created successfully."
