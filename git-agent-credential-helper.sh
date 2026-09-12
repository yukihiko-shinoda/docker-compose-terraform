#!/usr/bin/env sh
# git credential helper source for github.com HTTPS operations: reads the
# git_auth_secret Docker secret (compose.yml) mounted at
# /opt/claude-agent-secrets/git_auth_token, minted from the GIT_AUTH_TOKEN
# environment variable, instead of relying on VS Code Dev Containers' own
# git config forwarding from the host.
#
# Registered via `git config --system credential.https://github.com.helper`
# (see Dockerfile), so git only invokes this for github.com HTTPS remotes --
# scoped that way rather than checked inside this script. Being registered at
# the system scope also means it is tried before VS Code's own helper (which
# additionally sets itself at the global scope -- observed at both
# /etc/gitconfig and /root/.gitconfig): git queries configured helpers in
# config-file order and stops once one supplies both username and password,
# so this helper wins whenever the secret is present, with no need to
# disable VS Code's own forwarding.
#
# Mounted outside /run/secrets on purpose, like the AWS/GCP secrets: this
# environment is dedicated to Claude Code, and Claude Code's own sandbox
# keeps /run/secrets denied (see /workspace/.claude/settings.json) while
# allow-listing /opt/claude-agent-secrets/*.
#
# Only answers the `get` operation; `store`/`erase` are no-ops so git never
# tries to persist or clear this credential elsewhere. If the secret file is
# absent or empty -- e.g. GIT_AUTH_TOKEN wasn't set when the container was
# started -- this prints nothing, so git falls through to the next
# configured helper (VS Code's) or an interactive prompt instead of failing.
set -eu
[ "${1:-}" = "get" ] || exit 0
token_file=/opt/claude-agent-secrets/git_auth_token
[ -s "$token_file" ] || exit 0
printf 'username=x-access-token\npassword=%s\n' "$(cat "$token_file")"
