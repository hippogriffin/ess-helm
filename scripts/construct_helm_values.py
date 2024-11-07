#!/usr/bin/env python3
# Copyright 2024 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial


from pathlib import Path

import typer
from jinja2 import Environment, FileSystemLoader, select_autoescape


def construct_values_file(source_values_template_path: Path, destination_values_path: Path):
    sub_schemas_path = Path(__file__).parent.parent / "charts" / "matrix-stack" / "sub_schemas"
    env = Environment(
        loader=FileSystemLoader([source_values_template_path.parent, sub_schemas_path]),
        autoescape=select_autoescape,
        keep_trailing_newline=True,
    )
    template = env.get_template(source_values_template_path.name)

    with open(destination_values_path, "w") as destination_values_file:
        destination_values_file.write(template.render())


def main():
    typer.run(construct_values_file)


if __name__ == "__main__":
    main()
