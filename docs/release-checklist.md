# Release Checklist

Use this before creating any public tag.

## 1. Repo integrity

- Run `bash scripts/release-check.sh`
- Confirm `CHANGELOG.md` has a section for the release version
- Confirm the installer command in `README.md` points at the release tag

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

Verify the tagged install command works:

```bash
curl -fsSL https://raw.githubusercontent.com/robotlearning123/clarity/vX.Y.Z/install.sh | CLARITY_REPO_REF=vX.Y.Z bash
```

Then restart Claude Code and run:

```text
/clarity-doctor
```
