# Godot 4.7.1 Recovery and Project Index Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore reliable startup under Godot 4.7.1, or document a proven 4.6 fallback, and add a compact repository-local project index.

**Architecture:** Recovery follows evidence-first diagnosis: capture the current state, reproduce with the installed editor, isolate the first fatal boundary, then create and execute a root-cause-specific repair step. The project index is an independent `.codex/` subsystem generated deterministically from tracked source files.

**Tech Stack:** Godot 4.7.1, GDScript, PowerShell 7/Windows PowerShell, ripgrep, Git.

## Global Constraints

- Preserve every pre-existing working-tree change.
- Do not reset, revert, bulk-resave, or bulk-convert project resources.
- Change one compatibility variable at a time.
- Prefer Godot 4.7.1; use Godot 4.6 only when 4.7.1 requires invasive changes.
- Keep generated diagnostics outside production asset folders.
- Treat warnings separately from fatal startup blockers.

---

## File Structure

- Create: `.codex/PROJECT_MAP.md` — stable overview of project systems and folders.
- Create: `.codex/ENTRY_POINTS.md` — main scene, autoloads, enabled plugins and key managers.
- Create: `.codex/GODOT_COMPATIBILITY.md` — engine, addon and migration status.
- Create: `.codex/TROUBLESHOOTING.md` — exact reproduction commands and confirmed findings.
- Create: `.codex/update-project-index.ps1` — deterministic index generator.
- Create: `.codex/tests/update-project-index.tests.ps1` — generator smoke tests.
- Generate: `.codex/project-index.txt` — searchable source manifest.
- Modify conditionally: the single project/addon file identified by the first confirmed fatal error.

### Task 1: Capture baseline and reproduce editor startup

**Files:**
- Read: `project.godot`
- Read: `.gitignore`
- Read: enabled plugin files under `addons/*/plugin.cfg`
- Create after reproduction: `.codex/TROUBLESHOOTING.md`

**Interfaces:**
- Consumes: installed editor at `C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`.
- Produces: exact exit code, first fatal message, responsible file/resource and reproduction command.

- [ ] **Step 1: Capture baseline without modifying Git state**

Run:

```powershell
git status --short
git diff --stat
git diff -- project.godot
```

Expected: seven pre-existing modified tracked files plus the already committed design documentation; no reset or checkout.

- [ ] **Step 2: Confirm the installed engine**

Run:

```powershell
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --version
```

Expected: `4.7.1.stable`.

- [ ] **Step 3: Reproduce project parsing in headless editor mode**

Run:

```powershell
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' `
  --headless --editor --path 'C:\GodotProjects\zeldaclone' --quit --verbose
```

Expected: either exit code `0`, or a complete fatal/parse error naming the first failing boundary.

- [ ] **Step 4: Reproduce main-scene startup**

Run only if Step 3 parses the project:

```powershell
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' `
  --headless --path 'C:\GodotProjects\zeldaclone' --quit-after 180 --verbose
```

Expected: main scene `res://ui/menus/main_menu.tscn` starts, or output identifies the first runtime blocker.

- [ ] **Step 5: Record the evidence**

Write `.codex/TROUBLESHOOTING.md` with:

```markdown
# Startup troubleshooting

## Environment

- Engine: Godot 4.7.1 stable, Steam Windows build
- Previous project feature tag: Godot 4.6
- Main scene: `res://ui/menus/main_menu.tscn`

## Reproduction

Record the literal command copied from Step 3 or Step 4.

## First fatal error

Record the first fatal category, exact file and reported line or resource.

## Root-cause status

Confirmed only when the same command succeeds after one isolated change.
```

Write the captured values directly; do not leave instructional text in the finished document.

### Task 2: Isolate and repair the confirmed startup blocker

**Files:**
- Modify: exactly one file/resource named by Task 1 evidence.
- Modify: `.codex/TROUBLESHOOTING.md`
- Create or modify after confirmation: `.codex/GODOT_COMPATIBILITY.md`

**Interfaces:**
- Consumes: first fatal error and deterministic reproduction from Task 1.
- Produces: one confirmed root-cause fix or a documented Godot 4.6 fallback decision.

- [ ] **Step 1: Classify the failing boundary**

Use the first fatal message only:

- `res://addons/...` → addon compatibility boundary;
- `.gd` with a reported line number → GDScript parser/runtime boundary;
- `.gdshader` with a reported line number → shader-language boundary;
- `.tscn` or `.tres` load failure → serialized-resource boundary;
- renderer/device initialization failure before resource parsing → driver/rendering boundary.

- [ ] **Step 2: Form one written hypothesis**

Append to `.codex/TROUBLESHOOTING.md`:

```markdown
## Hypothesis 1

State one concrete incompatibility as the root-cause candidate.
Quote the fatal category and identify the directly related 4.6 → 4.7.1 behavior.
Name one isolated configuration or source change as the minimal test.
```

- [ ] **Step 3: Run the minimal test**

Apply only the isolated change named in the hypothesis. Rerun the exact failing command from Task 1.

Expected: the original fatal error disappears. If it remains, restore only the test change and write a new hypothesis; do not stack speculative edits.

- [ ] **Step 4: Implement the confirmed minimal repair**

Keep only the change that removes the original failure. If three hypotheses fail, stop repairs and document why the architecture/addon requires a version fallback.

- [ ] **Step 5: Verify both startup layers**

Run:

```powershell
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' `
  --headless --editor --path 'C:\GodotProjects\zeldaclone' --quit

& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' `
  --headless --path 'C:\GodotProjects\zeldaclone' --quit-after 180
```

Expected: no fatal startup error. Runtime warnings may remain but must be listed.

- [ ] **Step 6: Record compatibility**

Write `.codex/GODOT_COMPATIBILITY.md` with the verified engine version, each enabled addon and its observed status, the confirmed root cause, repair, remaining warnings, and fallback version if needed.

### Task 3: Build the deterministic project index

**Files:**
- Create: `.codex/update-project-index.ps1`
- Create: `.codex/tests/update-project-index.tests.ps1`
- Generate: `.codex/project-index.txt`

**Interfaces:**
- Consumes: repository root determined from the script location and files returned by `rg --files`.
- Produces: UTF-8 text manifest grouped into `CONFIG`, `SCRIPTS`, `SCENES`, `RESOURCES`, `SHADERS`, `ADDONS`.

- [ ] **Step 1: Write the failing smoke test**

Create `.codex/tests/update-project-index.tests.ps1` that:

```powershell
$ErrorActionPreference = 'Stop'
$codexDir = Split-Path -Parent $PSScriptRoot
$generator = Join-Path $codexDir 'update-project-index.ps1'
$index = Join-Path $codexDir 'project-index.txt'

& $generator

$content = Get-Content -Raw -LiteralPath $index
if ($content -notmatch '(?m)^\[CONFIG\]$') { throw 'Missing CONFIG section' }
if ($content -notmatch '(?m)^project\.godot$') { throw 'Missing project.godot' }
if ($content -notmatch '(?m)^\[SCRIPTS\]$') { throw 'Missing SCRIPTS section' }
if ($content -match '(?m)^\.godot[\\/]') { throw 'Cache directory leaked into index' }
if ($content -match '(?m)^references[\\/].*\.mp4$') { throw 'Reference media leaked into index' }
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/tests/update-project-index.tests.ps1
```

Expected: FAIL because `.codex/update-project-index.ps1` does not exist.

- [ ] **Step 3: Implement the generator**

Create `.codex/update-project-index.ps1` with one section per extension group. Use `rg --files`, normalize separators to `/`, sort deterministically, and exclude `.git`, `.godot`, `.import`, `references`, binary assets and generated logs.

- [ ] **Step 4: Run the smoke test**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/tests/update-project-index.tests.ps1
```

Expected: PASS with exit code `0`.

- [ ] **Step 5: Verify deterministic output**

Run the generator twice and compare SHA-256:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/update-project-index.ps1
Get-FileHash .codex/project-index.txt -Algorithm SHA256
powershell -NoProfile -ExecutionPolicy Bypass -File .codex/update-project-index.ps1
Get-FileHash .codex/project-index.txt -Algorithm SHA256
```

Expected: both hashes match.

### Task 4: Write the stable navigation map

**Files:**
- Create: `.codex/PROJECT_MAP.md`
- Create: `.codex/ENTRY_POINTS.md`

**Interfaces:**
- Consumes: `project.godot`, source folders and `.codex/project-index.txt`.
- Produces: concise human/agent navigation documentation.

- [ ] **Step 1: Map top-level ownership**

Document `common`, `entities`, `levels`, `ui`, `vfx`, `assets`, `addons` and `references`, including which folders contain runtime code versus source/reference assets.

- [ ] **Step 2: Map runtime entry points**

Document:

- main scene `res://ui/menus/main_menu.tscn`;
- all autoload names and paths from `[autoload]`;
- all enabled plugins from `[editor_plugins]`;
- player, level, scene-management, audio, interaction and VFX manager entry points.

- [ ] **Step 3: Validate every documented path**

Run:

```powershell
rg -o 'res://[^`) ]+' .codex/PROJECT_MAP.md .codex/ENTRY_POINTS.md
```

Check every returned repository path exists. Correct stale casing and missing files.

### Task 5: Final verification and focused commit

**Files:**
- Verify: every file changed during Tasks 1–4.

**Interfaces:**
- Consumes: repaired project and complete `.codex/` documentation/index.
- Produces: verified diff with no unexplained migration changes.

- [ ] **Step 1: Run all checks**

Run the editor parse check, main-scene smoke run and project-index smoke test.

- [ ] **Step 2: Review the complete diff**

Run:

```powershell
git status --short
git diff --check
git diff --stat
```

Expected: no whitespace errors and no accidental edits outside the confirmed repair plus `.codex/` documentation.

- [ ] **Step 3: Commit only Codex infrastructure and the confirmed repair**

Stage explicit paths only. Do not stage unrelated pre-existing scene/resource changes.

Suggested commit:

```powershell
git commit -m "fix: restore Godot 4.7 project startup"
```
