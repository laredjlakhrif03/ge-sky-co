#!/bin/sh
set -e

echo "Applying database migrations..."
cd /app
npx prisma migrate deploy --schema=apps/api/prisma/schema.prisma || true

echo "Migrations done. Starting API..."
cd /app/apps/api
exec node dist/src/main
