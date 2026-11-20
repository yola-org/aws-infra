#!/usr/bin/env python3
"""Run a command with shared public infrastructure defaults from SSM."""

import argparse
import json
import os
import re
import subprocess
import sys


def load_environment(parameters, path):
    result = {}
    for parameter in parameters:
        name = parameter["Name"]
        key = name.removeprefix(path + "/")
        if not name.startswith(path + "/") or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            raise ValueError("Unexpected parameter path or environment variable name")
        if parameter["Type"] != "String":
            raise ValueError("Only public String parameters may be loaded")
        if key in result:
            raise ValueError("Duplicate environment variable")
        result[key] = parameter["Value"]
    if not result:
        raise ValueError("No public parameters found; verify environment, region, and deployment")
    return result


def parameter_path(environment, service):
    root = f"/{environment.upper()}"
    if service != "backend":
        raise ValueError("Only shared infrastructure defaults are stored; configure service settings directly")
    return root


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--environment", choices=["dev", "prod"], required=True)
    parser.add_argument("--service", choices=["backend"], default="backend")
    parser.add_argument("--region", default="ca-central-1")
    parser.add_argument("--profile")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("Provide a command after --")

    path = parameter_path(args.environment, args.service)
    aws_command = [
        "aws", "ssm", "get-parameters-by-path", "--path", path,
        "--no-recursive", "--region", args.region, "--output", "json", "--no-cli-pager",
    ]
    if args.profile:
        aws_command.extend(["--profile", args.profile])
    # AWS CLI handles pagination. Do not print values or use shell evaluation.
    response = subprocess.run(aws_command, check=True, capture_output=True, text=True)
    loaded = load_environment(json.loads(response.stdout)["Parameters"], path)
    environment = os.environ.copy()
    # Explicit caller overrides win over stored defaults.
    for key, value in loaded.items():
        environment.setdefault(key, value)
    print(f"Loaded {len(loaded)} public defaults from {path}", file=sys.stderr)
    return subprocess.call(command, env=environment)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError):
        print("Could not load public configuration or start the command. Check AWS CLI authentication, SSM read permissions, and deployment.", file=sys.stderr)
        sys.exit(1)
