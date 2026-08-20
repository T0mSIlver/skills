#!/usr/bin/env bash
# Vendor third-party skills into this repo as pristine copies.
#
# Every entry in vendor.toml is cloned at its pinned ref, copied verbatim into
# ./<name>/, stamped with ./<name>/.vendored, and the pinned commit in the
# manifest is bumped. Vendored directories are never patched in-tree: a fix
# goes upstream, and the next run brings it back.
set -Eeuo pipefail

REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)}"
MANIFEST="${VENDOR_MANIFEST:-$REPO_DIR/vendor.toml}"
STAMP=".vendored"
DEEPEN="${VENDOR_DEEPEN:-200}"
export GIT_TERMINAL_PROMPT="${GIT_TERMINAL_PROMPT:-0}"

MODE="update"
ONLY=""
FORCE=0
SUMMARY=""
WORKDIR=""

usage() {
  cat <<'EOF'
Usage: vendor-skills.sh [options]

  --check            report stale vendored skills, write nothing, exit 1 if any
  --verify           check manifest <-> .vendored stamps agree (no network)
  --only <name>      act on one manifest entry
  --force            re-vendor even when the pinned commit is already current
  --summary <file>   append a markdown update report for the PR body
  -h, --help         this text
EOF
}

die() {
  printf 'vendor-skills: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  # Plain `if`, not `[[ ]] && rm`: a false test as the trap's last command
  # would take over the script's exit status under `set -e`.
  if [[ -n "$WORKDIR" ]]; then
    rm -rf -- "$WORKDIR"
  fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) MODE="check" ;;
    --verify) MODE="verify" ;;
    --force) FORCE=1 ;;
    --only)
      [[ $# -ge 2 ]] || die "--only needs a skill name"
      ONLY="$2"
      shift
      ;;
    --summary)
      [[ $# -ge 2 ]] || die "--summary needs a file path"
      SUMMARY="$2"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
  shift
done

command -v git >/dev/null 2>&1 || die "git is required but was not found"
command -v python3 >/dev/null 2>&1 || die "python3 is required but was not found"
[[ -f "$MANIFEST" ]] || die "manifest not found: $MANIFEST"

# Manifest reader: one TAB-separated record per skill. tomllib is stdlib on
# python 3.11+, so this needs nothing installed.
READ_MANIFEST_PY='
import sys, tomllib
required = ("name", "repo", "ref", "path", "commit")
with open(sys.argv[1], "rb") as fh:
    doc = tomllib.load(fh)
skills = doc.get("skills") or []
if not isinstance(skills, list):
    sys.exit("vendor-skills: [[skills]] must be an array of tables")
seen = set()
for entry in skills:
    # No single quotes anywhere in this program: it is carried in a
    # single-quoted shell string.
    name = entry.get("name") or "?"
    for key in required:
        if not entry.get(key):
            sys.exit(f"vendor-skills: entry {name} is missing {key}")
    if "/" in name or name.startswith("."):
        sys.exit(f"vendor-skills: illegal skill name {name!r}")
    if name in seen:
        sys.exit(f"vendor-skills: duplicate skill name {name!r}")
    seen.add(name)
    print("\t".join((
        name, entry["repo"], entry["ref"], entry["path"],
        entry.get("license", ""), entry["commit"],
    )))
'

# In-place commit bump. Rewrites the one `commit = "..."` line inside the
# matching [[skills]] table and leaves every comment untouched.
SET_COMMIT_PY='
import re, sys
path, name, sha = sys.argv[1], sys.argv[2], sys.argv[3]
lines = open(path, encoding="utf-8").read().splitlines(keepends=True)
in_table = False
current = None
done = False
for i, line in enumerate(lines):
    stripped = line.strip()
    if stripped.startswith("[["):
        in_table = stripped == "[[skills]]"
        current = None
        continue
    if not in_table:
        continue
    match = re.match(r"\s*name\s*=\s*\"([^\"]*)\"", line)
    if match:
        current = match.group(1)
        continue
    if current == name and re.match(r"\s*commit\s*=", line):
        lines[i] = re.sub(r"\"[^\"]*\"", f"\"{sha}\"", line, count=1)
        done = True
        break
if not done:
    sys.exit(f"vendor-skills: no commit line for {name} in {path}")
open(path, "w", encoding="utf-8").write("".join(lines))
'

manifest_records() {
  python3 -c "$READ_MANIFEST_PY" "$MANIFEST"
}

set_commit() {
  python3 -c "$SET_COMMIT_PY" "$MANIFEST" "$1" "$2"
}

read_stamp() {
  # $1 = stamp file. Prints repo, ref, path and commit, TAB separated.
  python3 -c '
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        stamp = json.load(fh)
except Exception as exc:
    sys.exit(f"unreadable stamp {sys.argv[1]}: {exc}")
print("\t".join(str(stamp.get(k, "")) for k in ("repo", "ref", "path", "commit")))
' "$1"
}

# --verify: manifest and on-disk stamps must describe the same set of skills,
# pinned at the same commits. Cheap, offline, and safe to run in CI — unlike
# --check, it never goes red just because upstream moved.
if [[ "$MODE" == "verify" ]]; then
  fail=0
  declare -A manifest_commit=()
  while IFS=$'\t' read -r name repo ref path _license commit; do
    [[ -n "$name" ]] || continue
    manifest_commit["$name"]="$commit"
    dir="$REPO_DIR/$name"
    if [[ ! -d "$dir" ]]; then
      printf 'MISSING  %s: in %s but no such directory\n' "$name" "$(basename "$MANIFEST")" >&2
      fail=1
      continue
    fi
    if [[ ! -f "$dir/$STAMP" ]]; then
      printf 'MISSING  %s: no %s stamp — run scripts/vendor-skills.sh\n' "$name" "$STAMP" >&2
      fail=1
      continue
    fi
    IFS=$'\t' read -r s_repo s_ref s_path s_commit < <(read_stamp "$dir/$STAMP")
    if [[ "$s_repo$s_ref$s_path$s_commit" != "$repo$ref$path$commit" ]]; then
      printf 'DRIFT    %s: manifest has %s %s %s %s, stamp has %s %s %s %s\n' "$name" \
        "$repo" "$ref" "$path" "${commit:0:12}" \
        "$s_repo" "$s_ref" "$s_path" "${s_commit:0:12}" >&2
      fail=1
      continue
    fi
    printf 'ok       %s (%s)\n' "$name" "${commit:0:12}"
  done < <(manifest_records)

  while IFS= read -r dir; do
    name="$(basename "$dir")"
    if [[ -z "${manifest_commit[$name]+set}" ]]; then
      printf 'ORPHAN   %s: has a %s stamp but no entry in %s\n' \
        "$name" "$STAMP" "$(basename "$MANIFEST")" >&2
      fail=1
    fi
  done < <(find "$REPO_DIR" -mindepth 2 -maxdepth 2 -name "$STAMP" -not -path '*/.git/*' -printf '%h\n' | sort)

  exit "$fail"
fi

WORKDIR="$(mktemp -d)"
stale=0
updated=0
considered=0

if [[ -n "$SUMMARY" ]]; then
  : >"$SUMMARY"
fi

while IFS=$'\t' read -r name repo ref path license commit; do
  [[ -n "$name" ]] || continue
  if [[ -n "$ONLY" && "$ONLY" != "$name" ]]; then
    continue
  fi
  considered=$((considered + 1))
  target="$REPO_DIR/$name"

  # Never clobber a hand-written skill: a directory without a stamp was not
  # put there by this script.
  if [[ -e "$target" && ! -f "$target/$STAMP" ]]; then
    die "$name exists but has no $STAMP stamp — refusing to overwrite a non-vendored directory"
  fi

  src="$WORKDIR/$name"
  echo "==> $name: cloning $repo at $ref"
  git clone --quiet --depth 1 --filter=blob:none --sparse --branch "$ref" \
    -- "$repo" "$src"
  sparse_paths=("$path")
  if [[ -n "$license" ]]; then
    license_dir="$(dirname -- "$license")"
    [[ "$license_dir" == "." ]] || sparse_paths+=("$license_dir")
  fi
  git -C "$src" sparse-checkout set -- "${sparse_paths[@]}"
  head_sha="$(git -C "$src" rev-parse HEAD)"

  [[ -d "$src/$path" ]] || die "$name: $path does not exist in $repo at $ref"

  if [[ "$head_sha" == "$commit" && -d "$target" && "$FORCE" -eq 0 ]]; then
    echo "    up to date at ${head_sha:0:12}"
    continue
  fi

  if [[ "$MODE" == "check" ]]; then
    stale=$((stale + 1))
    printf '    STALE: pinned %s, upstream %s\n' "${commit:0:12}" "${head_sha:0:12}"
    continue
  fi

  # Range log for the PR body. The clone is shallow, so deepen it until the
  # old pin is in history; a pin older than that (or a force-push) just loses
  # the log, not the update.
  log_lines=""
  if [[ "$commit" != "$head_sha" && ! "$commit" =~ ^0+$ ]]; then
    git -C "$src" fetch --quiet --deepen="$DEEPEN" origin "$ref" 2>/dev/null || true
    if git -C "$src" cat-file -e "${commit}^{commit}" 2>/dev/null &&
      git -C "$src" merge-base --is-ancestor "$commit" "$head_sha" 2>/dev/null; then
      log_lines="$(git -C "$src" log --oneline --no-decorate "$commit..$head_sha" -- "$path")"
      if [[ -z "$log_lines" ]]; then
        log_lines="(upstream moved, but no commit in this range touched $path)"
      fi
    else
      log_lines="(history unavailable — the old pin is beyond the shallow fetch, or the ref was rewritten)"
    fi
  fi

  rm -rf -- "${target:?}"
  mkdir -p -- "$target"
  cp -a -- "$src/$path/." "$target/"

  if [[ -n "$license" && ! -e "$target/LICENSE" ]]; then
    if [[ -f "$src/$license" ]]; then
      cp -- "$src/$license" "$target/LICENSE"
    else
      printf 'vendor-skills: %s: license %s not found upstream\n' "$name" "$license" >&2
    fi
  fi

  repo_web="${repo%.git}"
  upstream_url="$repo_web/tree/$head_sha/$path"
  python3 -c '
import json, sys
keys = ("name", "repo", "ref", "path", "commit", "upstream", "vendored_at")
record = dict(zip(keys, sys.argv[2:]))
record["note"] = "Pristine vendored copy. Do not edit in place — send fixes upstream."
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    json.dump(record, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
' "$target/$STAMP" "$name" "$repo" "$ref" "$path" "$head_sha" "$upstream_url" "$(date -u +%F)"

  set_commit "$name" "$head_sha"
  updated=$((updated + 1))
  echo "    vendored ${commit:0:12} -> ${head_sha:0:12}"

  if [[ -n "$SUMMARY" ]]; then
    {
      printf '### %s\n\n' "$name"
      printf 'Vendored from [`%s`](%s) at `%s`.\n\n' "$path" "$upstream_url" "$ref"
      if [[ "$commit" =~ ^0+$ ]]; then
        printf 'Initial vendoring, pinned at `%s`.\n\n' "${head_sha:0:12}"
      else
        printf '`%s` → `%s`\n\n' "${commit:0:12}" "${head_sha:0:12}"
        printf 'Compare: %s/compare/%s...%s\n\n' "$repo_web" "$commit" "$head_sha"
        printf 'Upstream commits touching `%s`:\n\n' "$path"
        printf '```\n%s\n```\n\n' "$log_lines"
      fi
      printf 'This directory is a pristine copy — review it, do not patch it here.\n'
    } >>"$SUMMARY"
  fi
done < <(manifest_records)

if [[ -n "$ONLY" && "$considered" -eq 0 ]]; then
  die "no manifest entry named $ONLY"
fi

if [[ "$MODE" == "check" ]]; then
  if [[ "$stale" -gt 0 ]]; then
    printf '%s vendored skill(s) are stale\n' "$stale" >&2
    exit 1
  fi
  echo "all vendored skills are up to date"
  exit 0
fi

printf '%s skill(s) updated\n' "$updated"
