# ReaProjectLink Non-blocking Operations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Media hashing and copying run in background processes with measured progress and cancel, so REAPER never freezes during ReaProjectLink reviews and publishes.

**Architecture:** `filesystem.lua` gains background hash and copy primitives that write result files. A job runner (`jobs.lua`) runs existing service functions inside a Lua coroutine with a job filesystem whose `hash_file` and `copy_file` start background processes and yield until their result exists. Checking phases use a two-pass hash prefetch (`hash_prefetch.lua`) so the final review build runs in one frame from one project state. The adapter can be bound to the project a job started in. Domain services stay unchanged.

**Tech Stack:** Lua 5.4 inside REAPER, ReaImGui 0.9 API, ReaToolUI (`reaui`), PowerShell / `sh` child processes via `reaper.ExecProcess`.

**Spec:** `tools/ReaProjectLink/docs/superpowers/specs/2026-10-22-nonblocking-operations-design.md`

## Global Constraints

- No new runtime dependencies. Child processes are `powershell.exe -NoProfile -NonInteractive` on Windows and `/bin/sh` elsewhere.
- Published package layout, manifests, staging, locks, and atomic pointer replacement do not change.
- Domain services (`delivery_publish.lua`, `reference_publish.lua`, `delivery_review.lua`, `reference_subscription.lua`, `delivery_import.lua`, `delivery_update.lua`, `delivery_writer.lua` and `reference_writer.lua` except Task 6) are not restructured.
- Apply steps (Synchronize, Import, Sync) stay synchronous single-frame calls.
- Progress is measured: completed bytes over total bytes, advancing only when a file's hash completes. No animation.
- UI status uses `env.design_system.patterns.external_operation_status`; no new ReaToolUI component.
- Code, comments, docs English; Conventional Commits with explicit `git add` paths; never rewrite files through PowerShell `Get-Content`/`Set-Content`; check BOM and the `路` mojibake before each commit.
- Validation: `powershell -NoProfile -ExecutionPolicy Bypass -File tools\ReaProjectLink\tests\run_validation.ps1` (core, UI smoke, layout scan) and, when ReaToolUI changes, `packages\ReaToolUI\tests\run_validation.ps1`.

## Review Focus

- Cancel pressed while a copy is in flight: the publish must clean `.staging/<transaction>` and release the lock, and a following publish must succeed (Task 4 and Task 9 tests).
- User edits the project while a Publish Review is checking: the review must come back Out of Date, not silently current (Task 5 test).
- Project tab switched mid-publish: project values and the save go to the original project, never the active one (Task 3 and Task 7 tests).
- A background process never writes a result (killed, crashed): the job fails after the timeout with the file name instead of hanging forever (Task 2 test).
- Paths with spaces, apostrophes, non-ASCII characters, and UNC roots (the user's NAS path contains Chinese characters): background hash equals `fs.hash_file` and background copy is byte-identical (Task 2 test).

---

### Task 1: Spike - background process and background-tab save

Throwaway, not committed. Decides whether Task 7 needs the "wait for project" fallback.

**Files:**
- Create: `.superpowers/sdd/2026-10-22-nonblocking/spike.lua` (gitignored)
- Create: `.superpowers/sdd/2026-10-22-nonblocking/findings.md` (gitignored)

- [ ] **Step 1: Write the spike script.** In an isolated REAPER (`-newinst -new -nosplash "<spike.lua>"`, minimized, same as `run_ui_smoke.lua`):
  1. Time `reaper.ExecProcess(cmd, -2)` for a PowerShell command that sleeps 3 s then writes a file; record the call duration and whether the file appears later.
  2. Create two project tabs (`Main_OnCommand(40859)`), save tab 1 to a temp `.rpp`, switch to tab 2, `MarkProjectDirty(tab1)`, `SetProjExtState(tab1, ...)`, call `Main_SaveProject(tab1, false)`; record `IsProjectDirty(tab1)`, the file mtime change, and whether the ext state is in the saved file.
  3. Write the findings to a result file and quit with `Main_OnCommand(40004)`.
- [ ] **Step 2: Run it and observe** whether any console window flashes or steals focus during step 1 (manual observation; note it).
- [ ] **Step 3: Record findings** in `findings.md`: `ExecProcess -2 returns in <ms>`, `window visible: yes/no`, `background save works: yes/no`. If background save does not work, Task 7 Step 5 is required; otherwise skip it.

### Task 2: Background hash and copy in `filesystem.lua`

**Files:**
- Modify: `tools/ReaProjectLink/ReaProjectLink/lib/reaprojectlink/filesystem.lua`
- Test: `tools/ReaProjectLink/tests/filesystem_spec.lua` (REAPER-hosted)

**Interfaces:**
- Produces:
  - `M.BACKGROUND_TIMEOUT_SECONDS = 1800`
  - `fs.start_hash(path) -> handle` and `fs.start_copy(source, destination) -> handle`; `handle = { id = string, kind = "hash"|"copy", path = string, started_at = number }`
  - `fs.poll(handle) -> "running"` | `"done", value` (hash: lowercase 64-hex string; copy: `true`) | `"failed", message`
  - `fs.clear_background()` removes the job directory contents.
  - Job directory: `fs.join(reaper_api.GetResourcePath(), "ReaProjectLink", "jobs")`, created on first start.

- [ ] **Step 1: Write failing tests** in `filesystem_spec.lua` using the existing fixture root:
  - `background_hash_matches_sync`: for files named `plain.wav`, `it's here.wav`, `中文 音效.wav` under the fixture, start a hash, poll every 50 ms (use `reaper.time_precise` busy wait with a 30 s guard) until not `"running"`; assert `"done"` and value `== fs.hash_file(path)`.
  - `background_copy_is_identical`: start a copy of each file to `nested/<name>`; after `"done"`, assert `fs.read_file(dest) == fs.read_file(source)`.
  - `background_copy_missing_source_fails`: poll result is `"failed"` with a non-empty message.
  - `background_timeout`: start a hash, set `handle.started_at = reaper.time_precise() - M.BACKGROUND_TIMEOUT_SECONDS - 1` before any result exists for a handle whose result file was deleted; assert `"failed"` and the message contains the file path and `timed out`.
- [ ] **Step 2: Run validation, expect the new tests to fail** (`start_hash` is nil).
- [ ] **Step 3: Implement.** Each start launches one child with `ExecProcess(command, -2)` (POSIX: `-1`, command wrapped as `/bin/sh -c '( ... ) &'`). The child writes `<id>.tmp` then renames it to `<id>.result`; content is `0 <value>` or `1 <message>`. Windows hash uses .NET `SHA256` over a `FileStream` (not certutil), copy uses `[IO.File]::Copy(src, dst, $false)`; reuse `powershell_literal`, `windows_extended_path`, `native_path`, `posix_literal`. `poll` reads and deletes `<id>.result`; ids from `reaper_api.genGuid`.
- [ ] **Step 4: Run validation, expect PASS.**
- [ ] **Step 5: Commit** `feat(reaprojectlink): add background hash and copy`.

### Task 3: Bind the adapter to a project

**Files:**
- Modify: `tools/ReaProjectLink/ReaProjectLink/lib/reaprojectlink/reaper_adapter.lua:6-18`
- Test: `tools/ReaProjectLink/tests/reaper_adapter_spec.lua` (REAPER-hosted; it already opens tabs with 40859/40860)

**Interfaces:**
- Produces:
  - `M.current_project() -> ReaProject` (the active project pointer, `EnumProjects(-1)`)
  - `M.with_project(project, fn, ...) -> ...` runs `fn` with every adapter call bound to `project`, restores the previous binding even when `fn` errors, and returns `fn`'s results. `project == nil` means active.
  - `M.project_is_open(project) -> boolean` (`ValidatePtr(project, "ReaProject*")`)
  - `M.project_is_active(project) -> boolean`
  - `project()` returns the bound pointer (default `0`); `project_path()` and `project_token()` describe the bound project (find its path by iterating `EnumProjects(i, "")`).

- [ ] **Step 1: Write failing test** `with_project_targets_background_tab`: save tab A, open tab B, `with_project(A, function() adapter.set_project_value(<key>, "x") end)`; assert A's value is `"x"`, B's is empty, `project_path()` inside the call is A's path, and after the call `project_path()` is B's.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** with a module-level `bound` variable read by `project()`.
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(reaprojectlink): let adapter calls target a bound project`.

### Task 4: Job runner and job filesystem

**Files:**
- Create: `tools/ReaProjectLink/ReaProjectLink/lib/reaprojectlink/jobs.lua`
- Create: `tools/ReaProjectLink/tests/jobs_spec.lua`; add it to `tests/specs.lua` after `filesystem_spec.lua`
- Modify: `tools/ReaProjectLink/ReaProjectLink/ReaProjectLink.lua` header `@provides` already covers `lib/reaprojectlink/*.lua` (no change expected; verify)

**Interfaces:**
- Consumes: Task 2 `fs.start_hash/start_copy/poll`, Task 3 `with_project/project_is_open`.
- Produces:
  - `jobs.CANCELLED = "ReaProjectLink operation cancelled"`
  - `jobs.create({ fs = fs, adapter = adapter }) -> runner`
  - `runner:start(spec) -> job`; errors if a job is running. `spec = { kind = "check"|"publish", label = string, project = ReaProject|nil, project_name = string|nil, total_bytes = number|nil, run = function(job_fs) -> result, err, on_done = function(job) }`
  - `job = { kind, label, project, project_name, state = "running"|"succeeded"|"failed"|"cancelled", phase = "working"|"cancelling"|"finishing", done_bytes = 0, total_bytes = number|nil, result, error }`
  - `runner.current` (the latest job, kept after it ends until `dismiss`), `runner:busy() -> boolean`, `runner:step()`, `runner:cancel()`, `runner:discard()` (drops a job without calling `on_done`), `runner:dismiss()`
  - `jobs.progress(job) -> number|nil` (0-100, nil without `total_bytes > 0`)
  - `job_fs`: every sync `fs` function, plus `hash_file` and `copy_file` that start a background process and yield until it finishes (hash adds `fs.file_size(path)` to `done_bytes`), `atomic_replace` that sets `phase = "finishing"` before running, and `add_total(bytes)`.

- [ ] **Step 1: Write failing tests** with a fake `fs` whose `start_*` return handles completed after N `poll` calls, and a fake adapter recording `with_project` bindings:
  - `runs_service_across_frames`: `run` hashes two files (sizes 10 and 30) and returns `"ok"`; after enough `step()` calls `job.state == "succeeded"`, `result == "ok"`, `done_bytes == 40`, `jobs.progress` went 25 then 100 with `total_bytes = 40`, and `on_done` ran once.
  - `cancel_raises_at_next_file_operation`: `run` wraps its work in `xpcall` like `delivery_writer.publish` and records cleanup; cancel during the first hash; assert the second hash never starts, cleanup ran, `state == "cancelled"`, `phase` was `"cancelling"` while waiting.
  - `cancel_ignored_after_commit`: cancel after `atomic_replace` started; job ends `"succeeded"`.
  - `failed_background_process_fails_job`: poll returns `"failed", "disk full"`; `job_fs.hash_file` returns `nil, "disk full"` (mirrors `fs.hash_file` returning nil) and the service's own error surfaces as `job.error`.
  - `closed_project_cancels`: adapter `project_is_open` returns false after the first frame; job ends `"cancelled"` and `job.error` says the project was closed.
  - `resumes_inside_bound_project`: every resume happened inside `with_project(spec.project)`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** `jobs.lua`. Cancel and closed-project both raise `error(jobs.CANCELLED .. (reason or ""))` at the next `hash_file`/`copy_file`/`atomic_replace` before the commit; a returned or raised error containing `jobs.CANCELLED` yields `state = "cancelled"`. `step()` polls the pending handle, resumes when it is not `"running"`, and never resumes more than once per call.
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(reaprojectlink): add background job runner`.

### Task 5: Hash prefetch for checking phases

**Files:**
- Create: `tools/ReaProjectLink/ReaProjectLink/lib/reaprojectlink/hash_prefetch.lua`
- Create: `tools/ReaProjectLink/tests/hash_prefetch_spec.lua`; add after `jobs_spec.lua` in `tests/specs.lua`

**Interfaces:**
- Consumes: Task 4 `job_fs` (`hash_file`, `file_size`, `add_total`).
- Produces: `hash_prefetch.run(job_fs, build) -> result, err` where `build(fs) -> result, err` is a review builder (for example `function(fs) return service.review(adapter, fs, options) end`). Each pass gives `build` a view of `job_fs` whose `hash_file(path)` returns the prefetched hash, or records `path` as missing and returns nil. Missing paths are hashed through `job_fs.hash_file` (after `add_total` of their sizes) and the pass repeats; the result of the first pass with nothing missing is returned. Failed hashes are remembered as failures and returned as nil without being re-recorded.

- [ ] **Step 1: Write failing tests** with a fake `job_fs` counting yields:
  - `final_build_sees_all_hashes`: builder hashes `a`, `b`; result built on the second pass contains both hashes; `job_fs.hash_file` called once per path.
  - `final_pass_has_no_yields`: no `job_fs.hash_file` call happens during the returned pass.
  - `new_paths_trigger_another_round`: builder asks for `c` only after seeing `a`'s hash; three passes, `c` hashed once.
  - `failed_hash_is_not_retried`: `b` fails; builder receives nil for `b`; `b` hashed once.
  - `publish_review_goes_stale_on_mid_check_edit`: with the real `project_guard.bind`, a fake adapter whose change count moves between the collect pass and the final pass; the returned review's `project_change_count` equals the count at the final pass, and a later `project_guard.check` after one more edit fails (pins Review Focus 2).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(reaprojectlink): prefetch review hashes in the background`.

### Task 6: Remove leftover staging at publish start

**Files:**
- Modify: `tools/ReaProjectLink/ReaProjectLink/lib/reaprojectlink/delivery_writer.lua` (`M.publish`, after the lock is acquired)
- Modify: `tools/ReaProjectLink/ReaProjectLink/lib/reaprojectlink/reference_writer.lua` (`M.publish`, after the lock is acquired)
- Test: `tools/ReaProjectLink/tests/delivery_writer_spec.lua`, `tools/ReaProjectLink/tests/reference_writer_spec.lua`

Rule: once this publish holds the package lock, every directory under `<package_root>/.staging` other than this transaction is leftover and is removed with `fs.remove_tree`. A failed removal does not fail the publish.

- [ ] **Step 1: Write failing tests** `publish_removes_leftover_staging` in both specs: create `.staging/old-transaction/media/x.wav`, publish, assert `.staging/old-transaction` no longer exists and the publish succeeded.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `fix(reaprojectlink): clear leftover publish staging`.

### Task 7: App integration - runner, banner, tab switch, close

**Files:**
- Modify: `tools/ReaProjectLink/ReaProjectLink/lib/reaprojectlink/ui/app.lua`
- Modify: `tools/ReaProjectLink/ReaProjectLink/ReaProjectLink.lua` (call `fs.clear_background()` once at startup)
- Test: `tools/ReaProjectLink/tests/ui_app_spec.lua`

**Interfaces:**
- Consumes: Task 4 runner.
- Produces: `env.jobs` (runner created in `app.create` from `deps.fs` and `deps.adapter`; not part of `app_state`, so `app:reset()` keeps it).

Behavior:
- `shell.draw` calls `env.jobs:step()` once per frame before `Begin`.
- On project token change: if the current job is a running `"check"`, `env.jobs:discard()`; a publish job keeps running.
- When `env.jobs.current` exists and is not owned by the open review (`app.review == nil or app.review.job ~= env.jobs.current`), draw a banner with `external_operation_status` at the top of the body: running label `"Publishing <project_name>"`, message phase text, progress from `jobs.progress`, Cancel while running and not finishing; after the outcome, Dismiss (`env.jobs:dismiss()`). While that job runs, the body below the banner is drawn inside `ImGui.BeginDisabled`/`EndDisabled` with the banner detail "Wait for Publish to finish". (Plan decision: this also disables read-only actions on that screen, a simplification of spec 5.5 for the tab-switched case only.)
- Window close while a publish job runs: keep `shell.open = true`. If `phase == "finishing"`, set `shell.close_after_job = true`. Otherwise `env.c.request_confirmation({ id = "close-during-publish", title = "Cancel Publish and Close", message = "Publishing is still running. Closing cancels it and removes the partial upload.", confirm_label = "Cancel Publish and Close", danger = true }, function() env.jobs:cancel(); shell.close_after_job = true end)`. When `shell.close_after_job` and not `env.jobs:busy()`, set `shell.open = false`. A running `"check"` job is discarded and the window closes immediately.
- Step 5 (only if Task 1 found background save does not work): in `jobs.lua` `atomic_replace`, while `not adapter.project_is_active(job.project)`, set `phase = "waiting"` and yield without a handle; the banner message is `"Switch back to <project_name> to finish publishing"`; Cancel stays available.

- [ ] **Step 1: Write failing tests** in `ui_app_spec.lua` with the existing fakes plus a scripted runner:
  - `tab_switch_keeps_publish_job_and_shows_banner`: start a publish job, change the project token; job still running, banner drawn with `"Publishing <name>"`, body drawn disabled.
  - `tab_switch_discards_check_job`.
  - `close_during_publish_asks_then_cancels`: Begin reports closed; `shell.open` stays true, confirmation requested; confirming calls cancel; after the job ends `shell.open == false`.
  - `close_while_finishing_waits`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** (and Step 5 if required).
- [ ] **Step 4: Run validation, expect PASS.**
- [ ] **Step 5: Commit** `feat(reaprojectlink): run jobs from the app shell`.

### Task 8: Shared review job helpers

**Files:**
- Modify: `tools/ReaProjectLink/ReaProjectLink/lib/reaprojectlink/ui/workflow.lua`
- Test: `tools/ReaProjectLink/tests/ui_views_spec.lua` (extend `fake_view_env` with `design_system.patterns.external_operation_status` recorder and a scripted `env.jobs`)

**Interfaces:**
- Produces:
  - `workflow.start_check(env, kind, fields, build, on_result)`: if no review of `kind` is open, opens it with `fields` plus `checking = true`; starts a `"check"` job whose `run` is `hash_prefetch.run(job_fs, build)` and stores it in `review.job`. On success calls `on_result(review, result)` and clears `checking`/`job`; on failure notifies the error and, when the review has no data yet, calls `app:back()`; on cancel calls `app:back()`.
  - `workflow.start_publish(env, spec)`: `spec = { label, total_bytes, run = function(job_fs) end, on_success = function(result) end }`; binds `project = env.adapter.current_project()` and `project_name` from the project file name, stores the job in `app.review.job`, clears `app.review.outcome`. On success calls `on_success` if the review is still the job's review, otherwise notifies through the toast. On failure or cancel sets `review.outcome = { state = "failed"|"cancelled", message = job.error }` and calls `workflow.inspect_lock` on failure as today.
  - `workflow.draw_job_status(env, id, review) -> action|nil`: draws nothing without `review.job` or `review.outcome`; otherwise `external_operation_status` with state `running` (Cancel unless finishing) or the outcome (Retry). Returns `"cancel"` or `"retry"`.
  - `workflow.job_header(review, header) -> header`: sets `back_disabled = true` while a publish job runs.
  - Status copy (exact): checking label `"Checking media"`, message `"Hashing media files"`, with progress from `jobs.progress`; publishing label `"Publishing"`, message by phase: working `"Copying and verifying media"`, cancelling `"Cancelling after the current file"`, finishing `"Finishing"`, waiting `"Switch back to <project_name> to finish publishing"`; publishing detail `"Edits made now will be in the next revision."`; Back-disabled reason (detail while running) `"Cancel or wait for Publish to finish."`.

- [ ] **Step 1: Write failing tests**:
  - `check_opens_review_in_checking_state`: after `start_check`, `app.review.checking == true`, footer drawn disabled, status block label `"Checking media"` with Cancel.
  - `check_cancel_returns`: status action `"cancel"` leads to `app:back()`.
  - `publish_status_shows_progress_and_disables_back`.
  - `failed_publish_shows_retry`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(reaprojectlink): add review job helpers`.

### Task 9: Delivery Publish Review on jobs

**Files:**
- Modify: `tools/ReaProjectLink/ReaProjectLink/lib/reaprojectlink/ui/views/delivery_publish_review.lua`
- Modify: `tools/ReaProjectLink/tests/ui_smoke_scenarios.lua`, `tools/ReaProjectLink/tests/ui_views_spec.lua`
- Test (core, real services and filesystem): `tools/ReaProjectLink/tests/delivery_publish_spec.lua`

Behavior:
- `M.open` and `refresh` use `workflow.start_check(env, "delivery_publish", { options = options }, function(fs) return env.services.delivery_publish.review(env.adapter, fs, options) end, function(review, data) review.data = data; review.options = options end)`.
- Draw: while `review.checking`, render the shell with header `"Publish Delivery"`, the status block, and a disabled footer; no body sections.
- Publish: replaces the `publish_ready`/`publishing` two-frame logic with `workflow.start_publish(env, { label = "Publishing", total_bytes = <sum of clip.media_size over data.current.lanes>, run = function(job_fs) return env.services.delivery_publish.publish(data, env.adapter, job_fs, workflow.metadata()) end, on_success = <today's back + notify> })`.
- Status action `"cancel"` → `env.jobs:cancel()` (publish) or back (checking); `"retry"` → `refresh(env, review.options)`.
- The footer is disabled and reads `"Publishing..."` while the job runs.

- [ ] **Step 1: Write failing tests**:
  - `ui_views_spec`: `delivery_publish_open_starts_check`, `delivery_publish_complete_starts_publish_job` (asserts `total_bytes` and that `back_disabled` is set), `delivery_publish_retry_refreshes`.
  - `delivery_publish_spec`: `cancelled_publish_can_publish_again` - run `service.publish` through a real `jobs` runner and real filesystem fixture, cancel after the first media copy, assert `.staging` is empty and no lock remains, then publish again and assert `delivery.json` has the next revision (pins Review Focus 1).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Add smoke scenarios `delivery_publish_checking`, `delivery_publish_running` (progress 40, phase working), `delivery_publish_cancelling`, `delivery_publish_failed` by setting `fields` with `checking`/`job`/`outcome`; update the expected smoke scenario count in `run_validation.ps1` output expectations if it is asserted.
- [ ] **Step 4: Run validation, expect PASS.**
- [ ] **Step 5: Commit** `feat(reaprojectlink): publish deliveries without blocking REAPER`.

### Task 10: Reference Publish Review on jobs

**Files:**
- Modify: `tools/ReaProjectLink/ReaProjectLink/lib/reaprojectlink/ui/views/reference_publish_review.lua`
- Modify: `tools/ReaProjectLink/tests/ui_views_spec.lua`, `tools/ReaProjectLink/tests/ui_smoke_scenarios.lua`

Same shape as Task 9 with `env.services.reference_publish.review/publish`, header `"Publish Reference"` while checking, publish `total_bytes = nil` (indeterminate; label and phase text carry the state), and on success today's `app:back()`, notify, `app:request_check()`.

- [ ] **Step 1: Write failing tests** `reference_publish_open_starts_check`, `reference_publish_complete_starts_publish_job`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement**; add smoke scenarios `reference_publish_checking`, `reference_publish_running`.
- [ ] **Step 4: Run validation, expect PASS.**
- [ ] **Step 5: Commit** `feat(reaprojectlink): publish references without blocking REAPER`.

### Task 11: Reference Update, Delivery Import, and Delivery Update checks on jobs

**Files:**
- Modify: `tools/ReaProjectLink/ReaProjectLink/lib/reaprojectlink/ui/views/reference_update_review.lua` (`M.open`)
- Modify: `tools/ReaProjectLink/ReaProjectLink/lib/reaprojectlink/ui/views/delivery_sync_review.lua` (`M.open_import`, `M.open_update`, Load)
- Modify: `tools/ReaProjectLink/tests/ui_views_spec.lua`, `tools/ReaProjectLink/tests/ui_smoke_scenarios.lua`

Behavior: each open becomes `workflow.start_check` with the service call as `build` (`reference_subscription.check(adapter, fs)`, `delivery_import.review(adapter, fs, path)` after the file dialog, `delivery_update.review(adapter, fs, id, target)`). `on_result` performs what the open function does today after a successful build (for Reference Update: set `app.checks.reference` and `app.media_error`, then fill `review.status`). While checking, the header is `"Update Reference"`, `"Add Delivery"`, or `"Sync Delivery"`. Load in Delivery Update restarts the check on the open review and keeps the current data visible until the new result arrives. Apply buttons stay synchronous.

- [ ] **Step 1: Write failing tests** `reference_update_open_starts_check`, `delivery_import_open_starts_check`, `delivery_update_load_restarts_check`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement**; add smoke scenarios `reference_update_checking`, `delivery_import_checking`.
- [ ] **Step 4: Run validation, expect PASS.**
- [ ] **Step 5: Commit** `feat(reaprojectlink): check reference and delivery media in the background`.

### Task 12: Documentation and final validation

**Files:**
- Modify: `tools/ReaProjectLink/docs/decisions.md` (new `D094 - Long operations run in the background`: summary of spec sections 5.1-5.8 and the Task 7 banner simplification)
- Modify: `tools/ReaProjectLink/docs/ui-spec.md` (checking state, publishing status block, cancel, banner, close confirmation)
- Modify: `tools/ReaProjectLink/docs/validation.md` (manual checks: publish on the NAS while editing, cancel mid-copy, switch tabs mid-publish, close during publish)
- Modify: the spec's `Status:` line to `Implemented`

- [ ] **Step 1: Write the docs.**
- [ ] **Step 2: Run both validations**; expect Core PASS (count grows by the new tests), Product UI PASS with the new scenario count, Layout PASS, ReaToolUI unchanged PASS.
- [ ] **Step 3: Commit** `docs(reaprojectlink): record background operations`.
