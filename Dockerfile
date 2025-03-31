FROM python:3.13.2-slim-bookworm

# tfenv
# Reffered: https://github.com/DockerToolbox/docker-tfenv/blob/master/Dockerfiles/alpine/3.10/Dockerfile
# Reason: To put raw string into ~/.bashrc .
# hadolint ignore=SC2016
RUN apt-get update && \
	apt-get -y upgrade && \
	apt-get -y install \
		curl \
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
		git \
		libdigest-sha-perl \
		unzip \
		&& \
	git clone --branch v3.0.0 --depth=1 https://github.com/tfutils/tfenv.git ~/.tfenv && \
	echo 'PATH=${HOME}/.tfenv/bin:${PATH}' >> ~/.bashrc && \
	. ~/.bashrc && \
	apt-get -y autoremove && \
	rm -rf /var/lib/apt/lists/*
# To install tfmigrate, TFLint, and Trivy
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# tfmigrate
RUN curl --location https://github.com/minamijoyo/tfmigrate/releases/download/v0.4.1/tfmigrate_0.4.1_linux_amd64.tar.gz | tar --extract --gzip --directory=/usr/local/bin
# TFLint
ENV TFLINT_VERSION=v0.55.1
RUN curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
# Trivy
ENV TRIVY_VERSION=v0.56.1
RUN curl https://mise.run | sh
# Reason: To put raw string into ~/.bashrc .
# hadolint ignore=SC2016
RUN /root/.local/bin/mise install trivy@${TRIVY_VERSION} \
 && /root/.local/bin/mise use -g trivy@${TRIVY_VERSION} \
 && echo 'PATH=${HOME}/.local/share/mise/shims:${PATH}' >> ~/.bashrc \
 && . ~/.bashrc
# build-essential (make): Since project uses shell script with shebang #!/bin/bash
RUN apt-get update && \
	apt-get -y upgrade && \
	apt-get -y install \
        build-essential \
 && apt-get -y autoremove \
 && rm -rf /var/lib/apt/lists/*
# Python packages for automation
RUN pip3 install invoke==2.2.0 pytest-xdist==3.6.1 Jinja2==3.1.6 yamldataclassconfig==1.5.0
# test command
COPY ./fmt-test.sh /usr/local/bin/fmt-test
RUN chmod +x /usr/local/bin/fmt-test
# Guard
# RUN curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/aws-cloudformation/cloudformation-guard/main/install-guard.sh | sh
# Install legacy version by arranging following method:
# - v2.1 Fails install on Codebuild · Issue #253 · aws-cloudformation/cloudformation-guard
#   https://github.com/aws-cloudformation/cloudformation-guard/issues/253#issuecomment-1315823073
RUN curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/aws-cloudformation/cloudformation-guard/2.1.4/install-guard.sh > /tmp/install-guard.sh
RUN sed -i 's|https://api.github.com/repos/aws-cloudformation/cloudformation-guard/releases/latest|https://api.github.com/repos/aws-cloudformation/cloudformation-guard/releases/tags/2.1.4|g' /tmp/install-guard.sh
RUN sh -x /tmp/install-guard.sh
ENV PATH="$PATH:~/.guard/bin/"
# For compatiblity with Visual Studio Code
WORKDIR /workspace
# - Terraform を使用するためのベスト プラクティス  |  Google Cloud
#   https://cloud.google.com/docs/terraform/best-practices-for-terraform?hl=ja
# - Answer: unix - How can I set Bash aliases for docker containers in Dockerfile? - Stack Overflow
#   https://stackoverflow.com/a/45042399/12721873
RUN ln -s /root/.tfenv/bin/terraform /root/.tfenv/bin/tf
