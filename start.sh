#!/usr/bin/env bash
# start.sh — resolve CHROMIUM_PASSWORD (Infisical or .env) then bring the stack up.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

source scripts/resolve-password.sh
docker compose up -d
