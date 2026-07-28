# Godot 4.7.1 recovery and project index

## Goal

Restore reliable editor and game startup after the Steam upgrade from Godot 4.6 to 4.7.1, while preserving existing user changes. Add a compact internal project map that makes future code and asset navigation faster.

## Current evidence

- The last explicit engine migration in Git was to Godot 4.6.
- The installed Steam editor is Godot 4.7.1.
- `project.godot` has already been rewritten from feature tag `4.6` to `4.7`.
- Godot also touched several scenes and resources during the attempted 4.7.1 open.
- The working tree was dirty before any repair work; those changes must not be overwritten or reverted.
- The crash root cause is not confirmed yet because the command-line reproduction and full editor/game log have not been captured.

## Recovery design

### 1. Preserve state

- Record the initial `git status` and diffs for every modified tracked file.
- Do not reset, revert, or bulk-resave resources.
- Keep diagnostic output outside production asset folders.

### 2. Reproduce and isolate

- Run the installed Godot 4.7.1 editor executable from the command line against this project.
- Capture the complete editor startup output.
- Run the main scene headlessly when the editor can parse the project.
- Classify the first fatal failure as one of:
  - editor plugin;
  - GDScript parse/runtime error;
  - shader incompatibility;
  - invalid or migrated resource;
  - rendering/driver problem.
- Disable or change only one suspect at a time and rerun the same reproduction.

### 3. Repair

- Prefer a minimal compatibility fix for Godot 4.7.1.
- If a third-party addon is incompatible, update it when a compatible local version exists; otherwise disable only that addon and document the lost editor functionality.
- Do not combine migration fixes with unrelated refactoring.
- If 4.7.1 cannot be stabilized without invasive changes, restore operation under Godot 4.6 and pin that version as the temporary fallback.

### 4. Verify

Success requires:

- the project opens without a fatal error;
- scripts and enabled plugins parse successfully;
- the configured main scene starts;
- a short smoke run reaches the main menu or gameplay without crashing;
- remaining warnings are listed separately from blockers;
- Git diff contains only understood migration or repair changes.

## Internal project index

Create a repository-local `.codex/` area with:

- `PROJECT_MAP.md` — major folders, ownership, main scenes and gameplay systems;
- `ENTRY_POINTS.md` — main scene, autoloads, enabled editor plugins and important managers;
- `GODOT_COMPATIBILITY.md` — known-good engine version, migration notes and addon compatibility;
- `TROUBLESHOOTING.md` — reproducible startup commands, known failures and fixes;
- `project-index.txt` — generated compact list of scripts, scenes, shaders and addons;
- `update-project-index.ps1` — deterministic index regeneration using `rg`.

The generated index excludes `.git`, `.godot`, imported caches, media references and bulky source assets. Documentation files are tracked; disposable logs are ignored.

## Safety and scope

- Existing user edits are preserved.
- No destructive Git operation is allowed.
- No asset, scene or resource is bulk-converted merely to reduce warnings.
- The repair targets startup compatibility only.
- Project restructuring and gameplay refactoring are out of scope.

## Implementation order

1. Capture baseline state.
2. Reproduce the failure and identify the first root cause.
3. Apply one minimal fix and verify it.
4. Repeat only when a new independent blocker is proven.
5. Create and populate the internal project index.
6. Run final editor/game smoke checks and review the complete diff.
