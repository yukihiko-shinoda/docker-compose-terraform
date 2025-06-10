FROM python:3.13.4-slim-bookworm
# - Dockerfileで対象プラットフォームによって処理分岐させる
#   https://zenn.dev/ytdrep/articles/d65c26201042eb
ARG BUILDARCH
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
ENV TENV_VERSION=v4.7.1
# Reason: To put raw string into ~/.bashrc .
# hadolint ignore=SC2016
RUN curl -O -L https://github.com/tofuutils/tenv/releases/latest/download/tenv_${TENV_VERSION}_${BUILDARCH}.deb \
 && dpkg -i tenv_${TENV_VERSION}_${BUILDARCH}.deb \
 && tenv completion bash > ~/.tenv.completion.bash \
 && echo 'source ${HOME}/.tenv.completion.bash' >> ~/.bashrc
# To install tfmigrate, TFLint, and Trivy
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# tfmigrate
RUN curl --location https://github.com/minamijoyo/tfmigrate/releases/download/v0.4.2/tfmigrate_0.4.2_linux_amd64.tar.gz | tar --extract --gzip --directory=/usr/local/bin
# TFLint
ENV TFLINT_VERSION=v0.58.0
RUN curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
# Trivy
ENV TRIVY_VERSION=v0.61.0
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
	pytest-xdist==3.7.0 \
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
# For compatiblity with Visual Studio Code
WORKDIR /workspace
ENV TENV_AUTO_INSTALL=true
