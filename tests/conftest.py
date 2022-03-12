from config import Config


CONFIG = Config()


def pytest_addoption(parser):
    parser.addoption("--prj", help="select project")


def pytest_generate_tests(metafunc):
    if "environment" in metafunc.fixturenames:
        project_name = metafunc.config.getoption("prj")
        CONFIG.load()
        project = CONFIG.projects[project_name]
        metafunc.parametrize("project", [project])
        metafunc.parametrize("environment", [dict(value, environment=key) for key, value in project.environments.items()])
