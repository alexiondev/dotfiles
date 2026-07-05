#!/usr/bin/env python3
import os
import subprocess
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict, namedtuple
from pathlib import Path

KCFG_NS = "{http://www.kde.org/standards/kcfg/1.0}"
DEFAULT_SCHEMA_DIR = "/usr/share/config.kcfg"

# .kcfg files that only declare their target rc file at runtime
# (<kcfgfile arg="true">), so it can't be discovered by scanning.
ARG_TRUE_RCFILES = {
    "kwin.kcfg": "kwinrc",
}

SAVE_USAGE = """usage: dot kde save [identifier]

  identifier   declare a new manifest entry, seeded from its current live value
  (no args)    refresh every already-declared manifest entry from the live system
  help         show this message"""

APPLY_USAGE = """usage: dot kde apply

  Pushes every manifest entry's declared value onto the live system.
  help         show this message"""

Setting = namedtuple("Setting", ["file", "group", "key"])


def parse_identifier(identifier):
    parts = identifier.split(".", 2)
    if len(parts) != 3:
        raise ValueError(f"invalid identifier {identifier!r} (expected file.group.key)")
    return Setting(*parts)


def load_manifest(path):
    entries = {}
    if not path.exists():
        return entries
    for line in path.read_text().splitlines():
        if not line.strip():
            continue
        identifier, _, value = line.partition("=")
        entries[identifier] = value
    return entries


def write_manifest(path, entries):
    lines = [f"{identifier}={value}" for identifier, value in entries.items()]
    path.write_text("".join(f"{line}\n" for line in lines))


def _parse_kcfg(path):
    try:
        return ET.parse(path).getroot()
    except ET.ParseError:
        return None


def _kcfgfile_name(root):
    elem = root.find(f"{KCFG_NS}kcfgfile")
    if elem is None:
        return None
    return elem.get("name")


def build_kcfg_map(schema_dir):
    mapping = defaultdict(list)
    if not schema_dir.is_dir():
        return mapping

    for path in sorted(schema_dir.glob("*.kcfg")):
        root = _parse_kcfg(path)
        if root is None:
            continue

        rcfile = _kcfgfile_name(root) or ARG_TRUE_RCFILES.get(path.name)
        if rcfile:
            mapping[rcfile].append(path)

    return mapping


def find_schema_default(kcfg_paths, setting):
    for path in kcfg_paths:
        root = _parse_kcfg(path)
        if root is None:
            continue

        for group_elem in root.iter(f"{KCFG_NS}group"):
            if group_elem.get("name") != setting.group:
                continue
            for entry in group_elem.findall(f"{KCFG_NS}entry"):
                if (entry.get("key") or entry.get("name")) != setting.key:
                    continue
                default_elem = entry.find(f"{KCFG_NS}default")
                return default_elem.text if default_elem is not None and default_elem.text else ""

    return None


def iter_schema_identifiers(kcfg_map):
    for rcfile, paths in kcfg_map.items():
        for path in paths:
            root = _parse_kcfg(path)
            if root is None:
                continue

            for group_elem in root.iter(f"{KCFG_NS}group"):
                group = group_elem.get("name")
                if not group:
                    continue
                for entry in group_elem.findall(f"{KCFG_NS}entry"):
                    key = entry.get("key") or entry.get("name")
                    if key:
                        yield f"{rcfile}.{group}.{key}"


def resolve_mechanism(setting, kcfg_map):
    if setting.file == "kglobalshortcutsrc":
        return "shortcuts", None

    default = find_schema_default(kcfg_map.get(setting.file, []), setting)
    if default is not None:
        return "schema", default

    return "freeform", None


def read_live_value(setting, default):
    cmd = ["kreadconfig6", "--file", setting.file, "--group", setting.group, "--key", setting.key]
    if default is not None:
        cmd += ["--default", default]

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(
            f"kreadconfig6 failed for {setting.file}/{setting.group}/{setting.key}: {result.stderr.strip()}"
        )
    return result.stdout.rstrip("\n")


def write_live_value(setting, value):
    cmd = [
        "kwriteconfig6",
        "--file", setting.file,
        "--group", setting.group,
        "--key", setting.key,
        "--",
        value,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(
            f"kwriteconfig6 failed for {setting.file}/{setting.group}/{setting.key}: {result.stderr.strip()}"
        )


def save_one(identifier, kcfg_map):
    setting = parse_identifier(identifier)
    mechanism, default = resolve_mechanism(setting, kcfg_map)
    if mechanism != "schema":
        raise RuntimeError(f"{identifier}: {mechanism} settings are not yet supported")
    return read_live_value(setting, default)


def apply_one(identifier, value, kcfg_map):
    setting = parse_identifier(identifier)
    mechanism, _default = resolve_mechanism(setting, kcfg_map)
    if mechanism != "schema":
        raise RuntimeError(f"{identifier}: {mechanism} settings are not yet supported")
    write_live_value(setting, value)


def cmd_save(args, manifest_path, schema_dir):
    if args and args[0] == "help":
        print(SAVE_USAGE)
        return 0

    if len(args) > 1:
        print("dot kde save: too many arguments", file=sys.stderr)
        return 1

    kcfg_map = build_kcfg_map(schema_dir)
    manifest = load_manifest(manifest_path)

    try:
        if args:
            manifest[args[0]] = save_one(args[0], kcfg_map)
        else:
            for identifier in manifest:
                manifest[identifier] = save_one(identifier, kcfg_map)
    except (ValueError, RuntimeError) as e:
        print(f"dot kde save: {e}", file=sys.stderr)
        return 1

    write_manifest(manifest_path, manifest)
    return 0


def cmd_apply(args, manifest_path, schema_dir):
    if args and args[0] == "help":
        print(APPLY_USAGE)
        return 0

    if args:
        print("dot kde apply: too many arguments", file=sys.stderr)
        return 1

    kcfg_map = build_kcfg_map(schema_dir)
    manifest = load_manifest(manifest_path)

    try:
        for identifier, value in manifest.items():
            apply_one(identifier, value, kcfg_map)
    except (ValueError, RuntimeError) as e:
        print(f"dot kde apply: {e}", file=sys.stderr)
        return 1

    return 0


def cmd_complete(schema_dir):
    kcfg_map = build_kcfg_map(schema_dir)
    for identifier in sorted(set(iter_schema_identifiers(kcfg_map))):
        print(identifier)
    return 0


def main(argv):
    if not argv:
        print("dot kde: no command given", file=sys.stderr)
        return 1

    command, rest = argv[0], argv[1:]
    schema_dir = Path(os.environ.get("DOT_KDE_KCFG_DIR", DEFAULT_SCHEMA_DIR))
    manifest_path = Path(os.environ["HOME"]) / ".config" / "dot" / "kde-manifest"

    if command == "save":
        return cmd_save(rest, manifest_path, schema_dir)

    if command == "apply":
        return cmd_apply(rest, manifest_path, schema_dir)

    # Internal, not a user-facing `dot kde` subcommand -- called directly by
    # completions/dot.fish to source candidates from the live schema, never
    # dispatched to via kde.fish.
    if command == "complete":
        return cmd_complete(schema_dir)

    print(f"dot kde: unknown command {command!r}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
