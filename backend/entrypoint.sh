#!/bin/sh
set -x

echo "==> Env check"
if [ -z "$DATABASE_URL" ]; then
  echo "FATAL: DATABASE_URL is empty"
  exit 10
fi
if [ -z "$DIRECT_URL" ]; then
  echo "FATAL: DIRECT_URL is empty"
  exit 11
fi
echo "DATABASE_URL length: ${#DATABASE_URL}"
echo "DIRECT_URL length: ${#DIRECT_URL}"

echo "==> Prisma version"
npx prisma --version 2>&1 || true

echo "==> Pushing DB schema..."
npx prisma db push --skip-generate --accept-data-loss 2>&1
PUSH_RC=$?
echo "prisma db push exit code: $PUSH_RC"
if [ $PUSH_RC -ne 0 ]; then
  echo "FATAL: prisma db push failed"
  sleep 3
  exit $PUSH_RC
fi

echo "==> Running seed..."
npx tsx src/seed.ts 2>&1
SEED_RC=$?
echo "seed exit code: $SEED_RC"
if [ $SEED_RC -ne 0 ]; then
  echo "WARN: seed failed (continuing, data may already exist)"
fi

echo "==> Starting server..."
exec npx tsx src/index.ts
