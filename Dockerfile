FROM python:3.10.2-slim-buster

# tfenv
# Reffered: https://github.com/DockerToolbox/docker-tfenv/blob/master/Dockerfiles/alpine/3.10/Dockerfile
RUN apt-get update && \
	apt-get -y upgrade && \
	apt-get -y install \
		curl \
		git \
		libdigest-sha-perl \
		unzip \
		&& \
	git clone https://github.com/tfutils/tfenv.git ~/.tfenv && \
	echo 'PATH=${HOME}/.tfenv/bin:${PATH}' >> ~/.bashrc && \
	. ~/.bashrc && \
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
	# apt-get -y remove --purge \
	# 	git \
	# 	&& \
	apt-get -y autoremove && \
	rm -rf /var/lib/apt/lists/*
# TFLint
RUN sh -c 'curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash'
# build-essential (make): Since project uses shell script with shebang #!/bin/bash
RUN apt-get update && \
	apt-get -y upgrade && \
	apt-get -y install \
        build-essential \
 && apt-get -y autoremove \
 && rm -rf /var/lib/apt/lists/*
# Python packages for automation
RUN pip3 install invoke==1.5.0 pytest-xdist==2.2.0 Jinja2==3.0.3 yamldataclassconfig==1.5.0
# test command
COPY ./fmt-test.sh /usr/local/bin/fmt-test
RUN chmod +x /usr/local/bin/fmt-test
# For compatiblity with Visual Studio Code
WORKDIR /workspace
