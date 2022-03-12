# Docker Compose Terraform

The develop environment for Terraform projects.

## Advantage

Out of the box📦 for any Terraform project:

- Supports any Terraform version🙆 by [tfenv]
- Auto format on save by [HashiCorp Terraform Extension]
- Implements efficient commands🚀 for:
  - Format and test code quickly
    - `terraform fmt -recursive`
    - `terraform validate`
    - [TFLint] (if `.tflint.hcl` exists in Terraform project)
  - Plan all environment (supports running as parallel)
  - Render differences report of all plans
- Customizable by jinja in YAML configuration file🔧
  - The directory to run terraform command
  - The command to select environment and prepare to plan.
  - The command to plan

### Out of the box for any Terraform project

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

#### 4\. Reopen in Container

Run the `Remote-Containers: Reopen in Container` command from the Command Palette (`F1`) or quick actions Status bar item.

#### 5\. Create config.yml to customize for your Terraform project

Copy `config.yml.dist` to `config.yml`, then edit it.

Details is explained by comments in its file.

#### 6\. Create report.md.jinja to render report of plans

Copy `report.md.jinja.dist` to `report.md.jinja`, then edit it.

The differences of all plan is rendered at point of corresponding environment name which is defined into `config.yml`.

EX:

```yaml
projects:
  terraform-project-a:
# ------------------------------
    environments:
      dev: {}
      prod: {}
```

````jinja
## dev

```console
{{ dev }}
```

## prod

```console
{{ prod }}
```
````

## Usage

### Format and test code quickly

```console
fmt-test <project directory name>
```

EX:

```console
fmt-test terraform-project-a
```

### Plan all environment

Note: If you are using Terraform Enterprise, it requires to login to Terraform Enterprise before run following commands.

```console
pytest tests --prj <project name defined in YAML>
```

EX:

```console
pytest tests --prj terraform-project-a
```

#### As parallel

```console
pytest tests --prj <project name defined in YAML> -n <number of processes>
```

EX:

```console
pytest tests --prj terraform-project-a -n 3
```

### Render report differences of all plans

```console
python report.py
```

Then, report will be render to `./report.md` .

[tfenv]: https://github.com/tfutils/tfenv
[HashiCorp Terraform Extension]: https://marketplace.visualstudio.com/items?itemName=HashiCorp.terraform
[TFLint]: https://github.com/terraform-linters/tflint
[Docker Desktop]: https://www.docker.com/products/docker-desktop
[Visual Studio Code]: https://code.visualstudio.com/
[Remote Development Extension Pack]: https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack
