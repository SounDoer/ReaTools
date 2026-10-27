---
name: releasing-reatools
description: Releases ReaTools tools to ReaPack by bumping versions, writing changelogs, pushing, and verifying the deployed index. Use when the user asks to release, publish, ship, or bump the version of a ReaTools tool, or asks why an installed ReaPack tool still shows old behavior.
---

# Releasing ReaTools

ReaPack only installs a version it has not seen before. Pushing to `main`
redeploys the `reapack` branch, but an existing version entry in `index.xml`
is never rewritten and keeps pointing at its original files. Every
user-visible change therefore needs a new version number.

## Workflow

```
Release progress:
- [ ] 1. Check release status
- [ ] 2. Agree versions and changelogs with the user
- [ ] 3. Edit version files
- [ ] 4. Validate
- [ ] 5. Commit, then push after confirmation
- [ ] 6. Verify CI, deployment, and index
```

### 1. Check release status

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .agents/skills/releasing-reatools/scripts/release_status.ps1
```

For each tool it prints the declared version, the latest indexed version, the
`main` commit that release was built from, a status, and the release files
changed since then. Only tools with status `NEEDS VERSION BUMP` need a release.
`version bumped, not yet published` means the bump is committed locally or
waiting for deployment.

### 2. Agree versions and changelogs with the user

Read the changes (`git log --oneline <released-from>..HEAD -- <changed files>`)
and propose, per tool, a semantic version (minor for features, patch for fixes)
and a short changelog. Wait for the user to confirm both. Never reuse a version
that is already in the index.

### 3. Edit version files

For each released tool, change exactly these:

- `tools/<Tool>/reatools-package.json`: top-level `version`. Leave
  `uiContract.version` alone; it pins ReaToolUI, not the tool.
- The entry script named by `entry`: `-- @version` and the `-- @changelog`
  lines (two-space indented continuation lines, user-facing wording).
- `tools/<Tool>/CHANGELOG.md`, only if the tool has one.

`tooling/build_release.ps1` fails when the header and manifest versions differ.

Edit with the file tools, never PowerShell `Get-Content`/`Set-Content`: they add
a BOM and corrupt non-ASCII characters such as `·`.

### 4. Validate

Run the tool's `tools/<Tool>/tests/run_validation.ps1` when it exists, and
confirm the edited files have no BOM.

### 5. Commit, then push after confirmation

Commit only the version files with explicit paths:

```powershell
git add tools/<Tool>/reatools-package.json tools/<Tool>/<Tool>/<entry>
git commit -m "chore(<tool-id>): release X.Y.Z"
```

Show the user the commit and ask before pushing; the push deploys to every
ReaPack user. Then `git push origin main`.

### 6. Verify CI, deployment, and index

```powershell
gh run list --branch main --workflow check --limit 1
gh run watch <check-run-id> --exit-status
gh run list --workflow "deploy ReaPack" --limit 1
gh run watch <deploy-run-id> --exit-status
```

Deployment starts only after `check` succeeds. When both pass, rerun the status
script: each released tool must show `up to date` with the new indexed version
and `released from` equal to the pushed commit. Then tell the user to run
**Extensions > ReaPack > Synchronize packages** in REAPER.

If `check` fails, diagnose it before anything else; the version is not
published until a later push succeeds.
