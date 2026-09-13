# Docker Compose Terraform

The develop environment for Terraform projects.

## Advantage

Out of the box📦 for any Terraform project:

- Supports any Terraform version🙆 by [tenv]
- Auto format on save by [HashiCorp Terraform Extension]
- Implements efficient commands🚀 for:
  - Format and test code quickly
    - `terraform fmt -recursive`
    - `terraform validate`
    - [TFLint] (if `.tflint.hcl` exists in Terraform project)
  - Plan all environments in parallel by [tfp]
- Customizable by jinja in YAML configuration file🔧
  - The directory to run terraform command
  - The command to select environment and prepare to plan
  - The command to plan

## Quickstart

### Requirement

- [Docker Desktop]
- [Visual Studio Code]
  - [Remote Development Extension Pack]

### Setup

#### 1\. Clone or download this project

```console
git clone https://github.com/yukihiko-shinoda/docker-compose-terraform.git
```

#### 2\. Clone or download your Terraform project into root directory of this project

```console
cd docker-compose-terraform
git clone <repository of your Terraform project>
```

#### 3\. Open Visual Studio Code on root directory

```console
code .
```

#### 4\. Add an AWS CLI profile for the `ai_agent` role, then seal a session

The devcontainer no longer mounts `~/.aws`: it instead seals a short-lived, read-only AWS session into the
container as Docker secrets, so your long-lived AWS key never enters it. From a real host terminal (not through
Claude Code):

1. Apply an `ai_agent` IAM role in your Terraform project, trusting the AWS profile that already holds your
   (real) access key, then add a matching block to `~/.aws/config`:

   ```ini
   [profile ai_agent]
   role_arn = arn:aws:iam::<ACCOUNT_ID>:role/ai_agent
   source_profile = <source-profile-name>
   ```

2. Run `./aws-agent-session.sh` once to mint the session.

#### 5\. Reopen in Container

Run the `Remote-Containers: Reopen in Container` command from the Command Palette (`F1`) or quick actions Status bar item.

This also re-runs `aws-agent-session.sh` automatically via `initializeCommand`, so the profile from step 4 must
already exist first.

#### 6\. Create tfp.yml to customize for your Terraform project

Copy `tfp.yml.dist` to `tfp.yml`, then edit it.

Details is explained by comments in its file.

<!-- markdownlint-disable-next-line MD026 -->
## How do I...

<!-- markdownlint-disable-next-line MD026 -->
### How do I format and test code quickly?

```console
fmt-test <project directory name>
```

EX:

```console
fmt-test terraform-project-a
```

<!-- markdownlint-disable-next-line MD026 -->
### How do I plan all environments?

Note: If you are using Terraform Enterprise, it requires to login to Terraform Enterprise before run following commands.

```console
tfp run <project name defined in tfp.yml>
```

EX:

```console
tfp run terraform-project-a
```

<!-- markdownlint-disable-next-line MD026 -->
### How do I control the number of parallel workers when planning?

By default, [tfp] runs one worker per environment, capped at the CPU count. Pass `-n` to override it.

```console
tfp run <project name defined in tfp.yml> -n <number of workers>
```

EX:

```console
tfp run terraform-project-a -n 3
```

<!-- markdownlint-disable-next-line MD026 -->
### How do I refresh an AWS session once it has expired?

The sealed `ai_agent` session lasts until the assumed role's own session duration elapses, after which AWS
calls inside the container start failing with an expired-token error. Rerun `./aws-agent-session.sh` from a
host terminal, then:

- Plain `docker compose up`: rerun it as usual — Compose detects the refreshed secret files and recreates the container
- VS Code: run "Dev Containers: Restart Container", or "Dev Containers: Rebuild Container" to re-run the hook itself

[tenv]: https://github.com/tofuutils/tenv
[HashiCorp Terraform Extension]: https://marketplace.visualstudio.com/items?itemName=HashiCorp.terraform
[TFLint]: https://github.com/terraform-linters/tflint
[tfp]: https://github.com/yukihiko-shinoda/tfp
[Docker Desktop]: https://www.docker.com/products/docker-desktop
[Visual Studio Code]: https://code.visualstudio.com/
[Remote Development Extension Pack]: https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack
