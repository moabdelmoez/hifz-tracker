# AGENTS.md

Harness for Hifz Tracker, a SwiftPM macOS app for local Quran memorization tracking.

## Startup Workflow

Before writing code:

1. Confirm the repo root with `pwd`.
2. Read this file, then `feature_list.json`, `progress.md`, and `session-handoff.md` if it has active notes.
3. Review recent context with `git status --short` and `git log --oneline -5`.
4. Run `swift test` and `swift build` when feasible. If either fails, record the failure in `progress.md` before changing scope.
5. Load additional context just in time:
   - `Package.swift` for target/dependency shape.
   - `docs/releases/production-readiness.md` for release, assets, signing, or packaging work.
   - Relevant source/test files only for the active feature.

If baseline verification is failing, repair that first before adding new scope.

Avoid loading large model, font, database, or audio assets unless the task specifically requires them.

## Project Invariants

- Runtime behavior after installation must stay offline.
- Do not persist user audio. Local audio files are fixtures only.
- Keep core recitation logic in `Sources/HifzCore`; keep macOS app wiring in `HifzTracker`.
- Preserve the SwiftPM macOS 14 package shape unless the active feature requires otherwise.

## Working Rules

- **One feature at a time**: Work only the active feature from `feature_list.json`.
- **Evidence required**: Do not claim done without command output or a clear blocked reason.
- **Update artifacts**: Before ending, update `progress.md` and `feature_list.json`.
- **Stay in scope**: Do not modify unrelated code, bundled assets, signing files, or generated output.
- **Work with local changes**: Never revert user changes unless explicitly asked.
- **Search first**: Prefer `rg`/`rg --files` and existing project patterns before introducing new structure.

## Required Artifacts

- `feature_list.json` - Feature state tracker and scope boundary.
- `progress.md` - Session continuity log and verification evidence.
- Verification commands in this file - Standard startup and lightweight verification path.
- `session-handoff.md` - Handoff template for long or interrupted work.

## Tool Safety

- Safe baseline checks: `swift test` and `swift build`.
- `./script/build_and_run.sh` rewrites `dist/`, may kill a running `HifzTracker`, and opens the app.
- `./script/release_checks.sh` is the local release gate; it builds, stages, launches, and codesigns the app.
- `./script/setup_assets.sh` may download and copy model/font/layout assets. Run it only for explicit asset or release work.
- `./script/package_dmg.sh` uses Developer ID/notarization inputs. Do not run it unless release packaging is the active task.

## Definition of Done

A feature is done only when ALL of the following are true:

- [ ] Target behavior is implemented.
- [ ] Required verification commands ran successfully, or the exact blocker is recorded.
- [ ] Release or asset-sensitive changes ran `./script/release_checks.sh` or document why it was skipped.
- [ ] Evidence is recorded in `feature_list.json` or `progress.md`.
- [ ] The repo remains restartable from the standard startup path.

## End of Session

Before ending a session:

1. Update `progress.md` with current state, files touched, evidence, and next step.
2. Update `feature_list.json` status/evidence for the active feature.
3. Use `session-handoff.md` when work is interrupted, multi-step, or not committed.
4. Record unresolved risks or blockers plainly.
5. Leave the repo clean enough for the next session to run the documented verification commands immediately.

## Verification Commands

```bash
swift test
swift build
```

Required checks:
- `swift test`
- `swift build`

Release-sensitive checks:
- `./script/release_checks.sh`
- `./script/release_checks.sh release` only after release assets and signing credentials are ready.

## Escalation

If you encounter:
- **Architecture decisions**: Inspect nearby code and docs, then ask the user if the trade-off is still ambiguous.
- **Unclear requirements**: Ask the user before inventing product behavior.
- **Repeated test failures**: Update `progress.md`, include commands and errors, and narrow the failing area.
- **Scope ambiguity**: Re-read `feature_list.json`; if no active feature matches, stop and ask.
