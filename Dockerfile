FROM python:3.11.5-slim-bullseye

# tfenv
# Reffered: https://github.com/DockerToolbox/docker-tfenv/blob/master/Dockerfiles/alpine/3.10/Dockerfile
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
# tfmigrate
RUN curl --location https://github.com/minamijoyo/tfmigrate/releases/download/v0.3.7/tfmigrate_0.3.7_linux_amd64.tar.gz | tar --extract --gzip --directory=/usr/local/bin
# TFLint
ENV TFLINT_VERSION=v0.48.0
RUN curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
# tfsec
RUN curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
# build-essential (make): Since project uses shell script with shebang #!/bin/bash
RUN apt-get update && \
	apt-get -y upgrade && \
	apt-get -y install \
        build-essential \
 && apt-get -y autoremove \
 && rm -rf /var/lib/apt/lists/*
# Python packages for automation
RUN pip3 install invoke==1.7.1 pytest-xdist==2.5.0 Jinja2==3.1.2 yamldataclassconfig==1.5.0
# test command
COPY ./fmt-test.sh /usr/local/bin/fmt-test
RUN chmod +x /usr/local/bin/fmt-test
# For compatiblity with Visual Studio Code
WORKDIR /workspace
