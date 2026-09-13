#!/usr/bin/env sh
# gws (Google Workspace CLI) credential source: activates the claude-code
# service account's static JSON key (Docker secret, minted on the host by
# gcp-agent-key.sh) with gcloud, mints a short-lived Drive/Docs-scoped OAuth
# access token from it, and execs into the real gws binary (installed as
# gws-real -- see Dockerfile) with that token.
#
# This script is installed AT /usr/local/bin/gws itself, shadowing the real
# binary, rather than under a separate name like gws-agent: the goal is for
# Claude Code to call the bare `gws <service> <resource> <method>
# --params/--json ...` interface exactly as `gws --help`/`gws schema`
# document it, with credential injection happening transparently underneath
# rather than through a bespoke wrapper command it has to know about.
#
# gcloud stays in the chain as the token minter because gws's officially
# documented credential inputs are all interactive-OAuth-user-flow-shaped
# (GOOGLE_WORKSPACE_CLI_TOKEN for a pre-obtained token, GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE
# for an OAuth client_secret.json, `gws auth login` for a browser consent
# flow) -- none accept a service-account key directly. The gws binary does
# contain internal service-account/ADC support (GOOGLE_APPLICATION_CREDENTIALS
# and "Application Default Credentials (ADC) are also supported" both appear
# in `strings gws-real`, undocumented in --help), and setting
# GOOGLE_APPLICATION_CREDENTIALS to the static key file does make gws attempt
# a real token request instead of failing immediately -- but that request
# fails with a DNS resolution error in this devcontainer's sandbox, while the
# same network path works for gcloud and curl. gws's own HTTP client appears
# not to honor the ambient http_proxy/https_proxy env vars this sandbox
# requires for egress, so ADC support that likely works in a normal
# (non-proxied) environment isn't usable here.
#
# Chain: claude-code service account static key (Docker secret,
#   /opt/claude-agent-secrets/claude-code-key.json)
#   -> gcloud auth activate-service-account + print-access-token
#      (drive + documents scopes)
#   -> GOOGLE_WORKSPACE_CLI_TOKEN env var, read by gws-real
#
# Scope note: the narrower `drive.file` scope was tried first and rejected --
# it only grants visibility into files the app itself created or that were
# opened through a Picker consent flow, so a folder shared with this service
# account purely through the Drive UI's normal sharing dialog was invisible
# under it (drive.files.get returned 404 even though the sharing ACL itself
# was correct -- confirmed by the same call succeeding once the scope was
# widened). `drive` (full) is safe here specifically because this service
# account is dedicated and otherwise empty (0-byte storage quota, no files of
# its own) -- unlike the personal-account "drive.readonly sees everything"
# problem that ruled out Anthropic's own Google Drive connector in the first
# place (its OAuth grant always includes drive.readonly over the real
# account's entire Drive, even when the UI implies "specific files only" --
# https://note.com/kenichiro/n/nbec8bbac1cf2?hl=en,
# https://www.wiredcio.com/insights/connecting-claude-to-google-drive-scoping-access-and-the-multi-account/),
# this scope only ever exposes what someone has explicitly shared with this
# one identity.
#
# Unlike the AWS WIF chain this replaces, the key has no expiration, so each
# call simply mints a fresh short-lived token from the same long-lived key --
# there is no session to keep alive or re-mint separately. See the shared
# Google Doc "Google Drive を Claude Code から安全に編集させる方法"
# (documentId 10tbYTgC5f34VVX-5Rb1NEte594rJYhn5wMwTQIajgsA) for the full
# narrative of why this design looks the way it does, including the
# abandoned WIF-token-lifetime-extension attempt this replaced.
#
# Docs API note for anyone scripting further `docs documents batchUpdate`
# calls through this wrapper: `insertText` rejects a location index equal to
# a segment's end index (must insert strictly before it), so appending at the
# very end of a document means inserting one index short of the end with a
# leading "\n" in the text, not at the end index itself. A paragraph created
# this way inherits the paragraphStyle of whatever paragraph it split from
# (e.g. a document's own HEADING_1 title), so restyling new paragraphs to
# NORMAL_TEXT needs its own explicit updateParagraphStyle request before
# applying any heading/bullet styles on top.
set -eu
# Claude Code's own Bash sandbox makes $HOME/.config read-only (only an
# allow-listed set of paths, including $TMPDIR, are writable there), so both
# gcloud's and gws's own config/cache stores are redirected to a writable
# location. $TMPDIR is unset when this script runs outside that sandbox,
# hence the /tmp fallback.
export CLOUDSDK_CONFIG="${TMPDIR:-/tmp}/gws-agent-gcloud-config"
mkdir -p "$CLOUDSDK_CONFIG"
gcloud auth activate-service-account \
  --key-file=/opt/claude-agent-secrets/claude-code-key.json --quiet
export GOOGLE_WORKSPACE_CLI_TOKEN="$(gcloud auth print-access-token \
  --scopes=https://www.googleapis.com/auth/drive,https://www.googleapis.com/auth/documents)"
export GOOGLE_WORKSPACE_CLI_CONFIG_DIR="${TMPDIR:-/tmp}/gws-agent-cli-config"
mkdir -p "$GOOGLE_WORKSPACE_CLI_CONFIG_DIR"
# Read from the key file's own "project_id" field rather than hardcoding it,
# so the project ID lives in exactly one place (the Docker secret minted by
# gcp-agent-key.sh) instead of being duplicated into this baked-in script.
export GOOGLE_WORKSPACE_PROJECT_ID="$(sed -n 's/.*"project_id": *"\([^"]*\)".*/\1/p' \
  /opt/claude-agent-secrets/claude-code-key.json)"
exec gws-real "$@"
