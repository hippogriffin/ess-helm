#!/usr/bin/env python3

# Copyright 2025 New Vector Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only

import re
import sys
from typing import Annotated

import typer
from spdx_tools.spdx.model import Document
from spdx_tools.spdx.parser.tagvalue.parser import Parser


def run_spdx_checks(input_file: Annotated[typer.FileText, typer.Argument()] = sys.stdin):
    parser = Parser()

    document: Document = parser.parse(input_file.read())
    failure_messages = []
    for file in document.files:
        textual_licenses = [license.render() for license in file.license_info_in_file]
        if len(textual_licenses) != 2:
            failure_messages.append(f"{file.name} should have exactly 2 licenses. It has {', '.join(textual_licenses)}")
            continue

        if set(["AGPL-3.0-only", "LicenseRef-Element-Commercial"]) != set(textual_licenses):
            failure_messages.append(f"{file.name} has an unexpected licenses. It has {', '.join(textual_licenses)}")

        # REUSE-IgnoreStart
        if re.match(r"^Copyright 202[345](-202[45])? New Vector Ltd$", file.copyright_text) is None:
            # REUSE-IgnoreEnd
            failure_messages.append(f"{file.name} has unexpected copyright text. It has {file.copyright_text}")

    for failure_message in failure_messages:
        print(failure_message)
    sys.exit(0 if len(failure_messages) == 0 else 1)


def main():
    typer.run(run_spdx_checks)


if __name__ == "__main__":
    main()
