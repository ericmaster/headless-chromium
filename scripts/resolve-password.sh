#!/usr/bin/env bash
# Resolve CHROMIUM_PASSWORD from the project's Infisical secrets.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
source load-secrets

if [[ -z "${CHROMIUM_PASSWORD:-}" ]]; then
  echo "[resolve-password] ERROR: CHROMIUM_PASSWORD was not returned by Infisical" >&2
  return 1 2>/dev/null || exit 1
fi

printf '%s\n' "$CHROMIUM_PASSWORD" > ~/.headless-chromium-webpass.txt
chmod 600 ~/.headless-chromium-webpass.txt
