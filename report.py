from pathlib import Path
import re
from jinja2 import Template


REGEX_NO_DIFF = r"No\schanges\.\sInfrastructure\sis\sup-to-date\."
REGEX_NO_DIFF_0_15_4 = r"No\schanges\.\sYour\sinfrastructure\smatches\sthe\sconfiguration\."
REGEX_EXISTS_DIFF = r"Terraform\sused\sthe\sselected\sproviders\sto\sgenerate\sthe\sfollowing\sexecution"
REGEX_EXISTS_DIFF_OUTPUT = r"Changes\sto\sOutputs\:"
REGEX_EXISTS_DIFF_0_13 = r"An\sexecution\splan\shas\sbeen\sgenerated\sand\sis\sshown\sbelow\."
REGEX_FAILED = r"Setup\sfailed:\sFailed\ssetting\sup\sTerraform binary:\sFailed\spushing\sbinary\sto\senvironment:\sexit\sstatus\s125"

class Splitter:
    def __init__(self) -> None:
        # ---               : for Terraform 0.14 or less
        # ───               : for Terraform 0.15 ~ 1.0.5
        # "Terraform used ~": for Terraform 1.0.6 or more
        self.regex = re.compile(fr"({REGEX_NO_DIFF}|{REGEX_NO_DIFF_0_15_4}|{REGEX_EXISTS_DIFF}|{REGEX_EXISTS_DIFF_OUTPUT}|{REGEX_EXISTS_DIFF_0_13}|{REGEX_FAILED})\n")

    def cut(self, path_to_file: Path):
        log = path_to_file.read_text()
        list_log = self.regex.split(log)
        keyword = self.regex.search(log)
        return keyword[0] + list_log[-1].strip()


def main():
    log_files = Path("plan_logs").glob("*.log")
    generator = (Path(log_file) for log_file in log_files)
    splitter = Splitter()
    arguments = {log_file.stem: splitter.cut(log_file) for log_file in generator}
    template = Template(Path("report.md.jinja").read_text())
    Path("report.md").write_text(template.render(**arguments) + "\n")

if __name__ == "__main__":
    main()
