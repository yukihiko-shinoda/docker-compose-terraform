"""This module implements configuration."""
from dataclasses import dataclass, field
from dataclasses_json import DataClassJsonMixin, config

from yamldataclassconfig.config import YamlDataClassConfig


@dataclass
class Project(DataClassJsonMixin):
    directory: str
    command_select_environment: str
    command_plan: str
    environments: dict[str, dict[str, str]]

@dataclass
class Config(YamlDataClassConfig):
    """This class implements configuration wrapping."""

    projects: dict[str, Project] = field(
        default_factory=dict,
        metadata=config(mm_field=dict[str, Project]),
    )
