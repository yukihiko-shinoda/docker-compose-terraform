ARG DOCKER_IMAGE_TAG_PYTHON=3.13.7-slim-trixie
FROM python:${DOCKER_IMAGE_TAG_PYTHON}
# - Dockerfileで対象プラットフォームによって処理分岐させる
#   https://zenn.dev/ytdrep/articles/d65c26201042eb
ARG TENV_VERSION \
    TFLINT_VERSION \
	TRIVY_VERSION \
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
RUN curl -O -L https://github.com/tofuutils/tenv/releases/latest/download/tenv_${TENV_VERSION}_${BUILDARCH}.deb \
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
# Python packages for automation
RUN pip3 install --no-cache-dir \
    invoke==2.2.0 \
	pytest-xdist==3.8.0 \
	Jinja2==3.1.6 \
	yamldataclassconfig==1.5.0
# test command
COPY ./fmt-test.sh /usr/local/bin/fmt-test
RUN chmod +x /usr/local/bin/fmt-test
# Guard
# RUN curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/aws-cloudformation/cloudformation-guard/main/install-guard.sh | sh
# Install legacy version by arranging following method:
# - v2.1 Fails install on Codebuild · Issue #253 · aws-cloudformation/cloudformation-guard
#   https://github.com/aws-cloudformation/cloudformation-guard/issues/253#issuecomment-1315823073
RUN curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/aws-cloudformation/cloudformation-guard/2.1.4/install-guard.sh > /tmp/install-guard.sh \
 && sed -i 's|https://api.github.com/repos/aws-cloudformation/cloudformation-guard/releases/latest|https://api.github.com/repos/aws-cloudformation/cloudformation-guard/releases/tags/2.1.4|g' /tmp/install-guard.sh \
 && sh -x /tmp/install-guard.sh
ENV PATH="$PATH:~/.guard/bin/"
# For compatibility with Visual Studio Code
WORKDIR /workspace
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
