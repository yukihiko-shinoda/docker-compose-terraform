#!/usr/bin/env sh
# Mints a short-lived, ReadOnlyAccess-scoped session from the ai_agent role (see
# iam-role.md) and writes it as Docker secret source files under
# ~/.aws-agent-secrets/ -- deliberately outside /workspace, since compose.yml's
# .:/workspace:cached mount would otherwise expose a repo-relative secrets
# directory as plain files inside the container too, defeating the point.
# compose.yml's `secrets:` block picks these up and Compose mounts them
# read-only at /opt/claude-agent-secrets/* inside the container -- not the
# default /run/secrets/*, since this environment is dedicated to Claude Code
# and Claude Code's own sandbox keeps /run/secrets denied. Never as environment
# variables either way, so they never show up in `docker inspect` output. Used
# both as a manual pre-step before `docker compose up` and as VS Code Dev
# Containers' initializeCommand; the long-lived key never enters the container
# either way.
set -eu
SECRETS_DIR="${HOME}/.aws-agent-secrets"
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"
CREDS=$(aws configure export-credentials --profile ai_agent --format env-no-export)
printf '%s\n' "$CREDS" | sed -n 's/^AWS_ACCESS_KEY_ID=//p' > "$SECRETS_DIR/aws_access_key_id"
printf '%s\n' "$CREDS" | sed -n 's/^AWS_SECRET_ACCESS_KEY=//p' > "$SECRETS_DIR/aws_secret_access_key"
printf '%s\n' "$CREDS" | sed -n 's/^AWS_SESSION_TOKEN=//p' > "$SECRETS_DIR/aws_session_token"
chmod 600 "$SECRETS_DIR/aws_access_key_id" "$SECRETS_DIR/aws_secret_access_key" "$SECRETS_DIR/aws_session_token"
