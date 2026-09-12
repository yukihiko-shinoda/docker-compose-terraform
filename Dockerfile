ARG DOCKER_BASE_IMAGE=futureys/claude-code-python-development:20260906204000
FROM ${DOCKER_BASE_IMAGE}
# - Dockerfileで対象プラットフォームによって処理分岐させる
#   https://zenn.dev/ytdrep/articles/d65c26201042eb
ARG TENV_VERSION \
    TFLINT_VERSION \
	TRIVY_VERSION \
	GUARD_VERSION \
	GCLOUD_VERSION \
	GWS_VERSION \
    BUILDARCH
# tenv
RUN apt-get upgrade \
 && apt-get update \
 &&	apt-get install -y --no-install-recommends \
		curl/stable \
		# Git required when download some aws module:
		#   Could not download module "s3_bucket"
		#   (services/performance_reposync/cloudwatchlogs.tf:11) source code from
		#   "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket?ref=v1.22.0":
		#   error downloading
		#   'https://github.com/terraform-aws-modules/terraform-aws-s3-bucket?ref=v1.22.0':
		#   git must be available and on the PATH.
		# see:
		#   - Module Sources - Terraform by HashiCorp
		#     https://www.terraform.io/docs/language/modules/sources.html#generic-git-repository
		git/stable \
		libdigest-sha-perl/stable \
		unzip/stable \
 && apt-get -y autoremove \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
# Reason: To put raw string into ~/.bashrc .
# hadolint ignore=SC2016
RUN curl -O -L https://github.com/tofuutils/tenv/releases/download/${TENV_VERSION}/tenv_${TENV_VERSION}_${BUILDARCH}.deb \
 && dpkg -i tenv_${TENV_VERSION}_${BUILDARCH}.deb \
 && tenv completion bash > ~/.tenv.completion.bash \
 && echo 'source ${HOME}/.tenv.completion.bash' >> ~/.bashrc
ENV TENV_AUTO_INSTALL=true
# To install TFLint and Trivy
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# TFLint
RUN curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
# Trivy
RUN curl https://mise.run | sh
# Reason: To put raw string into ~/.bashrc .
# hadolint ignore=SC2016
RUN /root/.local/bin/mise install trivy@${TRIVY_VERSION} \
 && /root/.local/bin/mise use -g trivy@${TRIVY_VERSION} \
 && echo 'PATH=${HOME}/.local/share/mise/shims:${PATH}' >> ~/.bashrc
# build-essential (make): Since project uses shell script with shebang #!/bin/bash
RUN apt-get upgrade \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
        build-essential/stable \
 && apt-get -y autoremove \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
# Terraform parallel execution tool (tfpcli)
RUN uv tool install tfpcli
# test command
COPY ./fmt-test.sh /usr/local/bin/fmt-test
RUN chmod +x /usr/local/bin/fmt-test
# AWS CLI
# - Installing or updating to the latest version of the AWS CLI - AWS Command Line Interface
#   https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
# `uname -m` sidesteps that pitfall entirely by reading the architecture directly from the
# build environment instead of a Docker-supplied ARG. Not documented by AWS itself; it's a
# community idiom, e.g.:
#   https://github.com/aws/aws-mwaa-local-runner/pull/370#issuecomment-2062936829
RUN curl --fail "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "awscliv2.zip" \
 && unzip awscliv2.zip \
 && ./aws/install \
 && rm -rf awscliv2.zip aws
# AWS credential source: reads the ai_agent session from Docker secrets (see
# aws-agent-session.sh, compose.yml, iam-role.md) instead of a mounted/env-var
# credential. Baked outside ~/.aws -- AWS_CONFIG_FILE below points AWS CLI/SDK
# at it instead -- so Claude Code's sandbox can deny ~/.aws entirely, for read
# and write alike. This file holds no secret itself, only the credential_process
# pointer, but ~/.aws is also where AWS CLI would otherwise write things like an
# SSO/CLI credential cache.
COPY ./aws-agent-credentials.sh /usr/local/bin/aws-agent-credentials
RUN chmod +x /usr/local/bin/aws-agent-credentials \
 && mkdir -p /root/.aws-agent-config \
 && printf '[default]\ncredential_process = /usr/local/bin/aws-agent-credentials\n' > /root/.aws-agent-config/config
ENV AWS_CONFIG_FILE=/root/.aws-agent-config/config
# Google Cloud CLI (gcloud)
# - Install gcloud CLI | Google Cloud SDK Documentation
#   https://docs.cloud.google.com/sdk/docs/install#deb
RUN apt-get upgrade \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
        apt-transport-https/stable \
        ca-certificates/stable \
        gnupg/stable \
 && apt-get -y autoremove \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends google-cloud-cli=${GCLOUD_VERSION}-0 \
 && apt-get -y autoremove \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
# gws (Google Workspace CLI): single Rust binary from GitHub Releases, no Node.js
# runtime needed.
# - Releases · googleworkspace/cli
#   https://github.com/googleworkspace/cli/releases
RUN case "${BUILDARCH}" in \
        amd64) GWS_TARGET=x86_64-unknown-linux-gnu ;; \
        arm64) GWS_TARGET=aarch64-unknown-linux-gnu ;; \
        *) echo "Unsupported BUILDARCH for gws: ${BUILDARCH}" >&2; exit 1 ;; \
    esac \
 && curl -O -L "https://github.com/googleworkspace/cli/releases/download/v${GWS_VERSION}/google-workspace-cli-${GWS_TARGET}.tar.gz" \
 && curl -O -L "https://github.com/googleworkspace/cli/releases/download/v${GWS_VERSION}/google-workspace-cli-${GWS_TARGET}.tar.gz.sha256" \
 && sha256sum -c "google-workspace-cli-${GWS_TARGET}.tar.gz.sha256" \
 && tar -xzf "google-workspace-cli-${GWS_TARGET}.tar.gz" -C /usr/local/bin ./gws \
 && mv /usr/local/bin/gws /usr/local/bin/gws-real \
 && chmod +x /usr/local/bin/gws-real \
 && rm -f "google-workspace-cli-${GWS_TARGET}.tar.gz" "google-workspace-cli-${GWS_TARGET}.tar.gz.sha256"
# GCP credential source for gws: activates the claude-code service account's
# static JSON key (Docker secret, minted by gcp-agent-key.sh, mounted at
# /opt/claude-agent-secrets/claude-code-key.json -- see compose.yml) with
# gcloud, mints a short-lived GCP OAuth token scoped to Drive/Docs from it,
# then execs into the real gws binary (renamed to gws-real above) with that
# token. Installed AT /usr/local/bin/gws itself (shadowing the real binary),
# not under a separate name like gws-agent, so Claude Code calls the bare
# `gws <service> <resource> <method> --params/--json ...` interface exactly
# as documented by `gws --help`/`gws schema`, with credential injection
# invisible to it. See terraform-google-personal's service_accounts.tf for
# the claude-code service account, and CLAUDE.md for the full chain. gcloud
# stays installed above for this token-minting step even though this wrapper
# no longer uses it for WIF impersonation (see the wrapper's own comments).
# A WIF credential-config JSON for the same fallback path may exist locally
# at ./google-wif-cred-config.json on a given host, but it's gitignored, not
# committed (it names this GCP project's number and the claude-code service
# account's email, which the account owner doesn't want in version control,
# even though the file holds no credential itself) -- regenerate it with
# `gcloud iam workload-identity-pools create-cred-config` (see
# terraform-google-personal/service_accounts.tf's comment above the
# claude_code WIF IAM policy binding) if that fallback path is ever revived.
COPY ./gws-agent.sh /usr/local/bin/gws
RUN chmod +x /usr/local/bin/gws
# git credential source for github.com HTTPS operations: reads the
# git_auth_secret Docker secret (compose.yml), mounted at
# /opt/claude-agent-secrets/git_auth_token like the AWS/GCP secrets above,
# instead of relying solely on VS Code Dev Containers' own git config
# forwarding from the host -- see git-agent-credential-helper.sh for why
# this coexists with, rather than replaces, that forwarding.
COPY ./git-agent-credential-helper.sh /usr/local/bin/git-agent-credential-helper
RUN chmod +x /usr/local/bin/git-agent-credential-helper \
 && git config --system credential.https://github.com.helper /usr/local/bin/git-agent-credential-helper
# Guard
# RUN curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/aws-cloudformation/cloudformation-guard/main/install-guard.sh | sh
# Install legacy version by arranging following method:
# - v2.1 Fails install on Codebuild · Issue #253 · aws-cloudformation/cloudformation-guard
#   https://github.com/aws-cloudformation/cloudformation-guard/issues/253#issuecomment-1315823073
RUN curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/aws-cloudformation/cloudformation-guard/${GUARD_VERSION}/install-guard.sh > /tmp/install-guard.sh \
 && sed -i "s|https://api.github.com/repos/aws-cloudformation/cloudformation-guard/releases/latest|https://api.github.com/repos/aws-cloudformation/cloudformation-guard/releases/tags/${GUARD_VERSION}|g" /tmp/install-guard.sh \
 && sh -x /tmp/install-guard.sh
ENV PATH="$PATH:~/.guard/bin/"
# To prevent following error when run `terraform validate`:
# │ Error: Missing required argument
# │ 
# │   on providers.tf line 20, in provider "vault":
# │   20: provider "vault" {
# │ 
# │ The argument "address" is required, but no definition was found.
# - terraform validate fails on module with vault resources · Issue #666 · hashicorp/terraform-provider-vault
#   https://github.com/hashicorp/terraform-provider-vault/issues/666#issuecomment-586080769
ENV VAULT_ADDR=https://example.com
