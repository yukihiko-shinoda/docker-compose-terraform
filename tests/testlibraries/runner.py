import asyncio
import fcntl
from io import TextIOWrapper
from pathlib import Path

from invoke import run
from invoke.exceptions import UnexpectedExit
from jinja2 import StrictUndefined, Template

from config import Project


class Error(Exception):
    """
    Base class for exceptions in this module.
    @see https://docs.python.org/3/tutorial/errors.html#user-defined-exceptions
    """

class FileLock:
    ENCODING = "utf-8"
    FILE = Path("plan_logs") / "plan.lock"
    def __init__(self, text: str) -> None:
        self.text = text
        self.file: TextIOWrapper | None = None

    async def __aenter__(self) -> None:
        while not await self.lock():
            await asyncio.sleep(0.25)

    async def lock(self) -> bool:
        if await self.is_locked():
            return False
        self.file = self.FILE.open("w", encoding=self.ENCODING)
        fcntl.flock(self.file, fcntl.LOCK_EX)
        await asyncio.sleep(0.25)
        # self.file.write(self.text)
        # await asyncio.sleep(0.25)
        # return self.FILE.read_text(encoding=self.ENCODING) == self.text
        return True

    async def __aexit__(self, *args):
        while await self.is_locked():
            if self.file:
                fcntl.flock(self.file, fcntl.LOCK_UN)
                self.file.close()
            self.file = None
            self.FILE.unlink()

    def __await__(self):
        return self.__aenter__()

    async def is_locked(self) -> bool:
        for _ in range(3):
            if self.FILE.exists():
                return True
            await asyncio.sleep(0.25)
        return False

class Runner:
    def __init__(self, project: Project, environment):
        self.project_directory = self.render(project.directory, environment)
        self.command_select_environment = self.render(project.command_select_environment, environment)
        self.command_plan = self.render(project.command_plan, environment)
        self.lock_file = Path("plan_logs") / "plan.lock"

    async def execute(self):
        try:
            async with FileLock(self.command_select_environment):
                self.cd_and_run("tenv tf install")
                self.cd_and_run(self.command_select_environment)
                coroutine = self.cd_and_plan(self.command_plan)
                # Requires at least 1 seconds, otherwise, lock won't work well:
                # E           FileNotFoundError: [Errno 2] No such file or directory: 'plan_logs/plan.lock'
                # or
                # E       AssertionError: Error: 
                # E         Error: HCP Terraform or Terraform Enterprise initialization required: please run "terraform init"
                # E         
                # E         Reason: HCP Terraform configuration block has changed.
                # E         
                # E         Changes to the HCP Terraform configuration block require reinitialization, to
                # E         discover any changes to the available workspaces.
                # E         
                # E         To re-initialize, run:
                # E           terraform init
                # E         
                # E         Terraform has not yet made changes to your existing configuration or state.
                await asyncio.sleep(1.5)
            promise = await coroutine
            return promise.join()
        except UnexpectedExit as error:
            return error.result

    def cd_and_run(self, command):
        return run(f"cd {self.project_directory} && {command}", in_stream=False)

    async def cd_and_plan(self, command):
        return run(f"cd {self.project_directory} && {command}", in_stream=False, asynchronous=True)

    def render(self, template, variable):
        return Template(template, undefined=StrictUndefined).render(**variable)
