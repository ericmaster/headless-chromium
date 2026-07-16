#!/usr/bin/env bash
#
# resolve-password.sh — resolve CHROMIUM_PASSWORD for docker-compose.yml.
#
# Two supported sources, tried in this order:
#   1. Infisical — if .env sets INFISICAL_PROJECT_ID, fetch the "CHROMIUM_PASSWORD" secret via
#      INFISICAL_CLIENT_ID / INFISICAL_CLIENT_SECRET / INFISICAL_API_URL. These auth credentials are
#      NOT stored per-project — they come from the global profile (/etc/profile.d/nimblerbox-secrets.sh),
#      same as every other project on this host (see the infisical / container-secret-injection skills).
#   2. Plain .env — CHROMIUM_PASSWORD set directly in .env (gitignored). Used as-is if Infisical isn't
#      configured, or as a fallback if the Infisical fetch fails.
#
# Meant to be `source`d (by start.sh) so CHROMIUM_PASSWORD ends up exported in the calling shell for
# docker-compose's ${CHROMIUM_PASSWORD} substitution.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

ENV_FILE=".env"
[[ -f "$ENV_FILE" ]] && { set -a; source "$ENV_FILE"; set +a; }

INFISICAL_ENV="${INFISICAL_ENV:-dev}"

if [[ -n "${INFISICAL_PROJECT_ID:-}" ]]; then
  if [[ -n "${INFISICAL_CLIENT_ID:-}" && -n "${INFISICAL_CLIENT_SECRET:-}" ]]; then
    API_URL="${INFISICAL_API_URL:-https://infisical.ericmaster.ninja}"
    TOKEN="$(curl -s -X POST "${API_URL}/api/v1/auth/universal-auth/login" \
      -H "Content-Type: application/json" \
      -d "{\"clientId\": \"$INFISICAL_CLIENT_ID\", \"clientSecret\": \"$INFISICAL_CLIENT_SECRET\"}" \
      | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)"

    if [[ -n "$TOKEN" ]]; then
      FETCHED="$(curl -s "${API_URL}/api/v4/secrets/CHROMIUM_PASSWORD?projectId=${INFISICAL_PROJECT_ID}&environment=${INFISICAL_ENV}" \
        -H "Authorization: Bearer $TOKEN" \
        | grep -o '"secretValue":"[^"]*' | cut -d'"' -f4)"
      [[ -n "$FETCHED" ]] && CHROMIUM_PASSWORD="$FETCHED"
    fi
    if [[ -z "${FETCHED:-}" ]]; then
      echo "[resolve-password] WARNING: INFISICAL_PROJECT_ID is set but the fetch failed — falling back to .env CHROMIUM_PASSWORD" >&2
    fi
  else
    echo "[resolve-password] WARNING: INFISICAL_PROJECT_ID is set but INFISICAL_CLIENT_ID/INFISICAL_CLIENT_SECRET aren't in the environment (expected from the global profile) — falling back to .env CHROMIUM_PASSWORD" >&2
  fi
fi

if [[ -z "${CHROMIUM_PASSWORD:-}" ]]; then
  echo "[resolve-password] ERROR: no CHROMIUM_PASSWORD available. Either:" >&2
  echo "  - set CHROMIUM_PASSWORD=... directly in .env, or" >&2
  echo "  - set INFISICAL_PROJECT_ID=... in .env (secret name: CHROMIUM_PASSWORD), with global Infisical creds available" >&2
  return 1 2>/dev/null || exit 1
fi

export CHROMIUM_PASSWORD
printf '%s\n' "$CHROMIUM_PASSWORD" > ~/.headless-chromium-webpass.txt
chmod 600 ~/.headless-chromium-webpass.txt
