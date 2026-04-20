# Release Checklist

Use this before creating any public tag.

## 1. Repo integrity

- Run `bash scripts/release-check.sh`
- Confirm `CHANGELOG.md` has a section for the release version
- Confirm the installer snippet in `README.md` uses a git-based tagged checkout, not a raw-content URL

## 2. Host integration

Run these in a real Claude Code environment:

```bash
claude plugin validate /absolute/path/to/clarity
claude plugin marketplace add /absolute/path/to/clarity
claude plugin install clarity@clarity
claude plugin list | sed -n '/clarity@clarity/,+4p'
```

Confirm:

- `clarity@clarity` is installed
- the version matches the tag you are about to release
- the plugin is enabled

## 3. Final runtime check

In Claude Code itself, run:

```text
/clarity-doctor 1
```

Confirm:

- the slash command is recognized
- it runs without path or manifest errors
- `.clarity/doctor-report.md` is created in the current workspace

## 4. Tag and publish

After the checks above are green:

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

The `release.yml` workflow will:

- run `tests/smoke.sh` on macOS and Linux
- extract the matching section from `CHANGELOG.md`
- create the GitHub Release for the tag

## 5. Post-release spot check

Verify the documented install flow works from a fresh shell:

```bash
bash -lc '
set -euo pipefail
dir="$HOME/.claude/clarity"
repo="https://github.com/robotlearning123/clarity.git"
ref="vX.Y.Z"

if [ -d "$dir/.git" ]; then
  git -C "$dir" fetch --tags origin
elif [ ! -e "$dir" ]; then
  git -c advice.detachedHead=false clone --depth 1 --branch "$ref" "$repo" "$dir"
else
  echo "$dir exists but is not a git checkout" >&2
  exit 1
fi

CLARITY_REPO_REF="$ref" "$dir/install.sh"
'
```

Then restart Claude Code and run:

```text
/clarity-doctor
```
