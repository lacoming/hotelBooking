#!/bin/sh
set -e

echo "==> Pushing DB schema..."
npx prisma db push --skip-generate --accept-data-loss

echo "==> Running seed..."
npx tsx src/seed.ts

echo "==> Starting server..."
exec npx tsx src/index.ts
