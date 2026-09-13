#!/usr/bin/env sh
# Ensures a static JSON key for the claude-code service account exists as a
# Docker secret source file under ~/.gcp-agent-secrets/ -- deliberately outside
# /workspace, since compose.yml's .:/workspace:cached mount would otherwise
# expose a repo-relative secrets directory as plain files inside the container
# too (same reasoning as aws-agent-session.sh). compose.yml's `secrets:` block
# picks this up and Compose mounts it read-only at
# /opt/claude-agent-secrets/claude-code-key.json inside the container, next to
# the AWS secrets.
#
# Unlike the AWS session (which expires and must be re-minted every run), this
# key has no expiration -- Google Cloud Client Libraries (ADC) exchange it for
# short-lived access tokens on their own, refreshed automatically for as long
# as the key stays valid. So this script only creates the key once and exits
# immediately on every later run, instead of re-minting like
# aws-agent-session.sh does.
#
# Prerequisite: the host's own `gcloud` must already be logged in as an
# identity with iam.serviceAccounts.keys.create on this service account (e.g.
# the project owner) -- analogous to aws-agent-session.sh assuming the host's
# `ai_agent` AWS profile is already configured.
set -eu
SECRETS_DIR="${HOME}/.gcp-agent-secrets"
KEY_FILE="$SECRETS_DIR/claude-code-key.json"
# -s (exists AND non-empty), not -f: `gcloud iam service-accounts keys create`
# can leave a truncated 0-byte file behind if it opens the destination before
# failing partway through (e.g. an auth/permission error), and a plain -f
# check would then treat that empty leftover as "already minted" forever.
if [ -s "$KEY_FILE" ]; then
  exit 0
fi
# Project ID (and, optionally, a non-default service account name) come from
# .env rather than being hardcoded here -- .env is gitignored and Read-denied
# for Claude Code, unlike this script itself. Sourced relative to this
# script's own location (not cwd) since this runs both as a manual host
# command and as devcontainer.json's initializeCommand.
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$SCRIPT_DIR/.env"
  set +a
fi
: "${GCP_PROJECT_ID:?Set GCP_PROJECT_ID in .env}"
GCP_SERVICE_ACCOUNT_NAME="${GCP_SERVICE_ACCOUNT_NAME:-claude-code}"
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"
gcloud iam service-accounts keys create "$KEY_FILE" \
  --iam-account="${GCP_SERVICE_ACCOUNT_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --project="$GCP_PROJECT_ID"
chmod 600 "$KEY_FILE"
