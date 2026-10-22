# Non-blocking long operations - design

Date: 2026-10-22
Status: Implemented. Where the implementation differs (`ExecProcess(..., -1)`,
.NET SHA-256 instead of `certutil`, the tab-switch banner disabling the whole
view), `docs/decisions.md` D094 is authoritative.

## 1. Why

ReaProjectLink runs on REAPER's main thread, the same thread that draws all of
REAPER's UI. Today every media copy and every media hash starts a child process
(`powershell.exe` or `certutil`) through `reaper.ExecProcess(command, 0)` and
waits for it to finish. While it waits, REAPER as a whole stops responding:
timeline, menus, and every window freeze until the operation ends. On a NAS
this takes seconds for a small Delivery and much longer for Reference video.

The user wants copy, update, sync, and publish operations to show progress
inside the tool without blocking normal REAPER use.

## 2. Goals, non-goals, anti-goals

Goals:

- No long freeze of REAPER during any operation listed in section 4. Media
  copies and media hashes run in background child processes; the tool polls
  them once per frame.
- Every long operation shows honest, measured progress and a visible state in
  the tool.
- Long operations can be cancelled up to a defined commit point.
- Normal REAPER use stays available during an operation. Where an edit cannot
  be honored safely, the tool says so explicitly instead of failing silently
  or producing inconsistent results.

Non-goals:

- Making `Main_SaveProject`, small manifest reads and writes, lock files, or
  the background status checks (`checks.lua` peeks) asynchronous. These are
  short, accepted pauses.
- Spreading the apply step of Reference Synchronize, Delivery Import, or
  Delivery Update across frames. Those edits stay in one frame so they remain
  one undo step. They are usually fast.
- Hash caching, parallel copies, or speeding up the work itself.
- Running more than one long operation at a time in one tool instance.
- Asynchronous Settings reset (`project_service.reset`).

Anti-goals (failure even if it technically works):

- A published revision that does not match what the review showed, or that
  mixes states from before and after a user edit.
- Writing project data or saving into a project other than the one the
  operation started in.
- An operation that keeps running invisibly after the tool window closes.
- Animated or invented progress (ReaToolUI DS motion decision: determinate
  progress must be measured).
- New runtime dependencies.

## 3. Constraints

- Lua 5.4 inside REAPER, ReaImGui (0.9 API), single main thread, `reaper.defer`
  loop in `ReaProjectLink.lua`.
- `reaper.ExecProcess(cmd, -1)` starts a process without waiting;
  `-2` additionally minimizes it. It returns no output and no handle, so a
  background job reports through files it writes. A running child process
  cannot be killed from Lua.
- REAPER undo blocks cannot span defer cycles.
- Media copy and hash commands stay the ones in `filesystem.lua`
  (`[IO.File]::Copy` through PowerShell, `certutil -hashfile` on Windows,
  `/bin/cp` and `shasum` elsewhere), including the `\\?\` extended path
  handling and the pure Lua SHA-256 fallback. The synchronous functions stay
  available for tests and for callers that are not migrated.
- Published package layout, manifests, staging, lock semantics, and the
  atomic pointer replacement are unchanged (no persisted data format change).
- UI uses the existing ReaToolUI External Operation Status pattern
  (`design_external_operation_status.lua`); no new design-system component.

## 4. Scope: operations that become non-blocking

| Operation | Side | Long work today |
|---|---|---|
| Open or refresh Delivery Publish Review | Source | hash every media file (`delivery_review.build`) |
| Delivery Publish | Source | per new file: existing-file hash check, copy to staging, hash staged copy |
| Open or refresh Reference Publish Review | Master | hash every Reference video (`reference_publish.review`) |
| Reference Publish | Master | lock, manifest writes, two saves; no media copy |
| Reference update check (open Reference Update Review) | Source | hash every Reference video on the NAS (`reference_subscription.check`) |
| Open Delivery Import Review / Delivery Update Review | Master | hash imported or changed media (`delivery_import.review`, `delivery_update` `checked_clip`) |

Reference Publish has no long step besides saves and small files. It still
moves onto the same job runner so that the publishing state, cancel window,
and project binding behave the same for both publishes.

## 5. Behavior

### 5.1 Background job runner

- A job is a sequence of steps. Long steps (copy, hash) start a child process
  with `ExecProcess(..., -2)` and finish when the process writes its result
  file. Short steps run synchronously within one frame.
- Each child process writes its exit status and output to a per-job result file
  under a temporary directory owned by the tool, written to a temporary name
  and renamed when complete so a partial write is never read as a result.
- The UI loop polls the running job once per frame, before drawing.
- Progress is completed bytes over total bytes of the files the job will
  process. It only advances when a file completes. When sizes are unknown,
  progress is the completed file count over the total file count.
- A child process that produces no result within a timeout fails the job with
  a message that names the file. The timeout is left to the builder; it must
  tolerate slow NAS copies of large files.

### 5.2 Reviews with a checking phase

- Opening or refreshing a review that needs hashes opens the review page
  immediately. The External Operation Status block at the top of the body
  shows a running state such as "Checking media 3/12" with Cancel.
- The Publish or Apply action is unavailable until the check completes. When it
  completes, the status block disappears and the review shows issues and its
  normal enabled state, as today.
- Cancel during checking returns to the previous view with no side effects.
  Back during checking is the same as Cancel.
- A checking phase has no side effects, so it is simply discarded when the
  review is left, the active project tab changes, or the window closes. No
  confirmation is shown for it.
- Project change tracking stays as today. The two Publish Reviews track the
  project change count; if it moves while checking, the review is shown as
  Out of Date when the check finishes and the user refreshes it. Delivery
  Import and Delivery Update Reviews do not track it today and keep not
  tracking it.

### 5.3 Publish

- Pressing Publish runs the existing pre-copy steps synchronously in one frame:
  project guard check, identity assignment in one undo block, first project
  save, lock acquisition. Then the job continues in the background.
- What is published is the state captured in the review at the moment Publish
  is pressed. Edits made while the job runs do not enter this revision; they
  are saved into the project by the final save and appear in the next review.
  The status block states this while running ("Edits made now will be in the
  next revision").
- Running state: the footer Publish button is disabled and reads
  "Publishing..."; the status block shows the phase and progress, for example
  "Copying media 5/12" with a percentage, and Cancel.
- Commit point: replacing `delivery.json` / `reference.json` makes the new
  revision live. From the start of that step, Cancel disappears and the status
  reads "Finishing...". The pointer replacement, the revision write into the
  project, and the second save complete without cancellation.
- Success: return to the main view and show today's success toast.
- Failure or cancellation: stay on the review; the status block shows the
  outcome and reason with Retry. Retry only refreshes the review (including
  its checking phase); the user presses Publish again after seeing the
  refreshed review. Retry never publishes by itself.
- While a publish job runs, its review cannot be left: Back is disabled with
  the reason "Cancel or wait for Publish to finish".

### 5.4 Cancel

- Cancel is requested, not immediate. The current child process cannot be
  stopped, so the job finishes the current file, then removes this job's
  staging directory and releases the publish lock. The status shows
  "Cancelling..." until cleanup is done.
- Cancelling after identity assignment leaves Clip identities saved in the
  project without a matching published revision. The builder must verify this
  is harmless: Delivery Clip identities are revision-local
  (`delivery_review.lua` comment), and Reference identities must be checked
  the same way. If it is not harmless, the design is revisited before
  implementation.

### 5.5 Other tool actions while a job runs

- Actions that would modify the same project or start another long operation
  (opening another review, Synchronize, Import, Update, Register or Unregister,
  Settings reset) are disabled with a visible reason ("Wait for Publish to
  finish").
- Read-only actions (navigation between views, Settings viewing, Copy) stay
  available.

### 5.6 Closing the tool window

- Closing the window while a publish job runs does not close it immediately. A
  confirmation explains that closing cancels the operation. Confirming runs
  the cancel flow of 5.4 and closes the window after cleanup.
- After the commit point, the window closes when the job finishes.
- The job never continues after the window closes.

### 5.7 Switching REAPER project tabs

- A job is bound to the project it started in (the `ReaProject` pointer and its
  path), not to the active tab.
- Switching tabs does not cancel the job. Copies and hashes continue.
- The job lives in an app-level slot, not in `app.review`, so the existing
  `app:reset()` on project change clears the review and transient state but
  keeps the job. The window then shows the new tab's normal views as usual,
  with a persistent banner at the top using the same External Operation Status
  block: "Publishing <project name> - Copying media 5/12" and Cancel. The
  original review is not restored when the user switches back; the banner
  stays until the job ends, and its outcome is reported in the banner and the
  toast.
- The 5.5 rule applies across tabs: while any publish job runs, actions that
  modify a project or start a long operation are disabled in every project
  the tool shows.
- Every project read or write the job performs after starting (project
  values, item identities, undo, save) targets the bound project explicitly.
  Today `reaper_adapter.lua` always uses the active project
  (`EnumProjects(-1)`); a mid-publish tab switch would write the revision into
  the wrong project. This must be fixed for job steps.
- If the bound project is closed while the job runs, the job cancels and cleans
  up as in 5.4, and the tool reports it.
- To verify first: whether `Main_SaveProject(project, false)` saves a project
  that is not the active tab. If it does not, the job pauses before the commit
  point while its project is in the background, shows "Switch back to <name>
  to finish publishing", and continues when the user returns. Cancel stays
  available while paused.

### 5.8 REAPER quits during a job

- Not preventable. The lock and staging directory remain. The existing lock
  inspection and unlock flow covers the lock.
- New: a publish removes leftover staging directories of the same package
  before it starts. A staging directory is leftover when no live lock owns
  it; the exact rule is left to the builder.

## 6. Decided by the user

- Long operations must not block REAPER; progress is shown in the tool.
- When an edit cannot be honored during an operation, say so explicitly.
- Cancel is wanted if not complex.
- Window close, tab switching, and quit handling: the user accepted the
  behavior proposed in 5.6 to 5.8.
- Progress presentation as in 5.2 to 5.5 was accepted.

## 7. Decided by the assistant (reviewable)

- Background processes plus result files, no new dependencies.
- Bytes-based progress that advances per completed file.
- Apply steps stay single-frame for undo integrity.
- Reference Publish moves to the job runner for consistency even without a
  long copy step.
- Leftover staging cleanup at publish start.
- Back during checking equals Cancel; checking phases are discarded without
  confirmation on leaving, tab switch, or window close.
- Retry refreshes the review and never publishes by itself.
- A running publish keeps its review open (Back disabled); after a tab switch
  it continues as an app-level job shown in a banner, and the review is not
  restored.
- Delivery Import and Update Reviews keep not tracking the project change
  count.
- The new behavior is recorded as a ReaProjectLink decision (next free number
  in `tools/ReaProjectLink/docs/decisions.md`) and `docs/ui-spec.md` is updated
  when implemented.

## 8. Left to the builder

- Module layout of the job runner and how review builders are split into a
  "collect files to hash" phase and a "build from hashes" phase.
- Temporary directory location and result file format.
- Child process timeout values.
- Exact status copy beyond the phrases above, within the ReaToolUI copy rules.
- Test strategy: core specs with a fake job runner and fake filesystem,
  UI smoke scenarios for checking, publishing, cancelling, finishing,
  failed, and project-switched states, plus a REAPER-hosted check that
  background copy and hash produce the same results as the synchronous
  functions.
- First implementation step: a spike in an isolated REAPER instance that
  confirms `ExecProcess(..., -2)` starts PowerShell and certutil without a
  visible window or focus steal, and answers the background-tab save question
  in 5.7.
