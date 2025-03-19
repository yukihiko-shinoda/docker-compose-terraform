FROM python:3.13.2-slim-bookworm

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
RUN curl --location https://github.com/minamijoyo/tfmigrate/releases/download/v0.4.1/tfmigrate_0.4.1_linux_amd64.tar.gz | tar --extract --gzip --directory=/usr/local/bin
# TFLint
ENV TFLINT_VERSION=v0.55.1
RUN curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
# Trivy
RUN apt-get update && \
    apt-get -y install apt-transport-https gnupg lsb-release
RUN curl -s https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | tee /usr/share/keyrings/trivy.gpg > /dev/null
RUN echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | tee -a /etc/apt/sources.list.d/trivy.list
RUN apt-get update && apt-get -y install trivy
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
# For compatiblity with Visual Studio Code
WORKDIR /workspace
# - Terraform を使用するためのベスト プラクティス  |  Google Cloud
#   https://cloud.google.com/docs/terraform/best-practices-for-terraform?hl=ja
# - Answer: unix - How can I set Bash aliases for docker containers in Dockerfile? - Stack Overflow
#   https://stackoverflow.com/a/45042399/12721873
RUN ln -s /root/.tfenv/bin/terraform /root/.tfenv/bin/tf
