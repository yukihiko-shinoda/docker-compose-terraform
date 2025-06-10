from invoke import run
from invoke.exceptions import UnexpectedExit
from jinja2 import StrictUndefined, Template

from config import Project


class Error(Exception):
    """
    Base class for exceptions in this module.
    @see https://docs.python.org/3/tutorial/errors.html#user-defined-exceptions
    """


class Runner:
    def __init__(self, project: Project, environment):
        self.project_directory = self.render(project.directory, environment)
        self.command_select_environment = self.render(project.command_select_environment, environment)
        self.command_plan = self.render(project.command_plan, environment)

    def execute(self):
        try:
            self.cd_and_run("tenv tf install")
            self.cd_and_run(self.command_select_environment)
            return self.cd_and_run(self.command_plan)
        except UnexpectedExit as error:
            return error.result

    def cd_and_run(self, command):
        return run(f"cd {self.project_directory} && {command}", in_stream=False)

    def render(self, template, variable):
        return Template(template, undefined=StrictUndefined).render(**variable)
