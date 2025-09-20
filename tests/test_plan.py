import asyncio
from pathlib import Path

from config import Project
from tests.testlibraries.runner import Runner


def test(project: Project, environment: dict[str, str]):
    runner = Runner(project, environment)
    result = asyncio.run(runner.execute())
    (Path("plan_logs") / f"{environment['environment']}.log").write_text(result.stdout)
    assert (
        result.exited == 0 or
        result.exited == 2 and
        isinstance(result.stdout, str) and
        'Plan: 0 to add, 0 to change, 0 to destroy.' in result.stdout
        ), ("Succeeded with non-empty diff (changes present)" if result.exited == 2 else f"Error: {result.stderr}")
