#!/usr/bin/env python3
import argparse
import math
import json
import sys
from pathlib import Path
from jinja2 import Environment, FileSystemLoader, StrictUndefined

ANSI_RESET  = "\033[0m"
ANSI_RED    = "\033[31m"
ANSI_YELLOW = "\033[33m"
ANSI_BOLD   = "\033[1m"

def jinja_warning(message):
    print(f"{ANSI_BOLD}{ANSI_YELLOW}[Warning] {message}{ANSI_RESET}", file=sys.stderr)
    return ""

def jinja_assert(condition, message="Assertion failed"):
    if not condition:
        raise AssertionError(f"{ANSI_BOLD}{ANSI_RED}[Assertion failed]: {message}{ANSI_RESET}")
    return ""

def jinja_clog2(n):
    if n <= 0:
        return 0
    return math.ceil(math.log2(n))

def normalize_config_value(value):
    if isinstance(value, dict):
        return {k: normalize_config_value(v) for k, v in value.items()}
    if isinstance(value, list):
        return [normalize_config_value(v) for v in value]
    if not isinstance(value, str):
        return value

    stripped = value.strip()
    lowered = stripped.lower()

    if lowered == "true":
        return True
    if lowered == "false":
        return False
    if lowered == "null":
        return None

    try:
        return int(stripped, 0)
    except ValueError:
        pass

    if stripped.startswith(("[", "{")):
        try:
            return normalize_config_value(json.loads(stripped))
        except json.JSONDecodeError:
            pass

    return value

def parse_args():
    parser = argparse.ArgumentParser(
        description=".sv.j2 files renderer"
    )
    parser.add_argument(
        "-t",
        "--template",
        required=True,
        type=Path,
        help="Path to templated .sv.j2 file",
    )
    parser.add_argument(
        "-c",
        "--config",
        required=True,
        type=Path,
        help="Path to JSON configuration file",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Path to resulting .sv file (if not stated, resulting file is output in place with template file)",
    )
    return parser.parse_args()

def main():
    args = parse_args()

    try:
        with open(args.config, "r", encoding="utf-8") as f:
            config_data = normalize_config_value(json.load(f))
    except Exception as e:
        print(f"Error while loading JSON configuration: {e}", file=sys.stderr)
        sys.exit(1)

    template_path = args.template

    if template_path.is_absolute():
        try:
            template_path = template_path.relative_to(Path.cwd())
        except ValueError:
            pass

    env = Environment(
        loader=FileSystemLoader("."),
        extensions=["jinja2.ext.do"],
        undefined=StrictUndefined,
        trim_blocks=True,
        lstrip_blocks=True,
    )

    env.globals.update(jinja_assert=jinja_assert)
    env.globals.update(jinja_warning=jinja_warning)

    env.filters['clog2'] = jinja_clog2

    try:
        template = env.get_template(str(template_path).replace("\\", "/"))
        rendered_code = template.render(config_data, ctx=config_data)
    except Exception as e:
        print(f"Error while rendering: {e}", file=sys.stderr)
        sys.exit(1)

    if not args.output:
        default_name = template_path.name.replace(".j2", "")
        args.output = template_path.parent / default_name

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(rendered_code, encoding="utf-8")

    print(f"Rendered {template_path} to {args.output}", file=sys.stderr)

if __name__ == "__main__":
    main()
