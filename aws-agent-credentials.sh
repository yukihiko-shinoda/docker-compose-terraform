#!/usr/bin/env sh
# AWS CLI/SDK credential_process source, wired via AWS_CONFIG_FILE
# (/root/.aws-agent-config/config) baked into this image -- reads the short-lived ai_agent session from Docker secrets
# mounted at /opt/claude-agent-secrets/* (aws-agent-session.sh mints them on the
# host; see iam-role.md), never from an env var or a mounted credentials file.
# Mounted outside /run/secrets on purpose: this environment is dedicated to
# Claude Code, and Claude Code's own sandbox keeps /run/secrets denied.
set -eu
printf '{"Version":1,"AccessKeyId":"%s","SecretAccessKey":"%s","SessionToken":"%s"}\n' \
  "$(cat /opt/claude-agent-secrets/aws_access_key_id)" \
  "$(cat /opt/claude-agent-secrets/aws_secret_access_key)" \
  "$(cat /opt/claude-agent-secrets/aws_session_token)"
