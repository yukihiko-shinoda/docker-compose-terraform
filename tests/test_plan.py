from pathlib import Path
from config import Project
from tests.testlibraries.runner import Runner


def test(project: Project, environment: dict[str, str]):
    runner = Runner(project, environment)
    result = runner.execute()
    (Path("plan_logs") / f"{environment['environment']}.log").write_text(result.stdout)
    assert result.exited == 0, ("Succeeded with non-empty diff (changes present)" if result.exited == 2 else "Error")
