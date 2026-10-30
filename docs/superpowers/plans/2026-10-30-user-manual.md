# ReaTools User Manual Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write the Chinese first-use manual for installing/updating ReaTools and for ReaProjectLink, with real screenshots, ready for manual import into Feishu.

**Architecture:** Chinese Markdown files in the repository are the source of truth. Screenshots are captured from REAPER on this machine while each step is performed for real against demo projects on the NAS. Part 1 uses an isolated portable REAPER; Part 2 uses the main REAPER with the `ReaProjectLink_Dev.lua` action on current `main`.

**Tech Stack:** Markdown, PNG screenshots captured with a scratch PowerShell window-capture script (outside the repo), Edge headless to render the concept diagram from an SVG source, Cursor computer-use tools to drive REAPER.

**Spec:** `docs/superpowers/specs/2026-10-30-user-manual-design.md`

## Global Constraints

- Manual text is Chinese; UI labels, menu paths, and error messages stay in English exactly as REAPER/ReaProjectLink shows them.
- Requirements stated in the manual: REAPER 7.74 or newer; ReaImGui 0.9-compatible or newer; ReaPack.
- Repository URL stated in the manual: `https://raw.githubusercontent.com/SounDoer/ReaTools/reapack/index.xml`.
- Action name stated in the manual: `Script: ReaProjectLink.lua`.
- Shared storage is described generically; no NAS path appears in the main text.
- Markdown limited to headings, numbered steps, tables, blockquote callouts, and images with relative paths into a sibling `images/` folder. No Mermaid, no HTML.
- Behavior described is current `main`; where it contradicts developer docs, the product wins and the discrepancy is listed for the user.
- No product code changes, no new runtime dependencies. UX problems found while writing are listed for the user, not fixed.
- Demo projects live only under `\\audionas.int.hypergryph.com\AudioNas\DI21 Project\Misc\Xichen\ReaProjectLink-Manual-Demo\`.
- Do not commit without the user's go-ahead; commit messages use `docs(manual): ...`.

## Review Focus

- A reader who skips the concept chapter and starts at the walkthrough: the walkthrough must still say, at each first use of a term, which concept it is and link back to the concept chapter.
- A reader in the Source role only: the README must route Source colleagues to the steps they own without reading Master sections.
- A screenshot that shows a different state than the text describes (e.g. captured before a check finished, still showing `Checking...`): every image is checked against its step text in Task 7.
- A reader whose project already contains Items before initialization: the walkthrough must state that existing unregistered Items are not adopted.
- Images that do not survive the Feishu import: Task 7 has the user import one file and confirm images render before the rest is considered done.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `AGENTS.md` (modify, Language section) | Exception: user manuals under `docs/manual/` and `tools/*/docs/manual/` are written in Chinese |
| `docs/manual/zh-CN/install.md` | Part 1: install, launch, update, rollback, FAQ |
| `docs/manual/zh-CN/images/` | Part 1 screenshots |
| `tools/ReaProjectLink/docs/manual/zh-CN/README.md` | Manual entry: who reads what, reading order by role |
| `tools/ReaProjectLink/docs/manual/zh-CN/01-what-it-solves.md` | Problem and the two-direction diagram |
| `tools/ReaProjectLink/docs/manual/zh-CN/02-concepts.md` | Core concepts with English UI term + Chinese explanation |
| `tools/ReaProjectLink/docs/manual/zh-CN/03-first-walkthrough.md` | Master + dialogue Source from zero to first Delivery sync |
| `tools/ReaProjectLink/docs/manual/zh-CN/04-master-tasks.md` | Master owner daily tasks |
| `tools/ReaProjectLink/docs/manual/zh-CN/05-source-tasks.md` | Source colleague daily tasks |
| `tools/ReaProjectLink/docs/manual/zh-CN/06-troubleshooting.md` | Warnings, locks, interrupted Publish, replaced Items |
| `tools/ReaProjectLink/docs/manual/zh-CN/team-appendix.md` | Removable team-specific notes, placeholders until the user fills them |
| `tools/ReaProjectLink/docs/manual/zh-CN/images/` | Part 2 screenshots and the rendered diagram |
| `tools/ReaProjectLink/docs/manual/zh-CN/images/src/overview-diagram.svg` | Editable diagram source |

Image naming: `<chapter-number>-<step-slug>.png`, e.g. `03-initialize-master.png`; Part 1 uses `install-<step-slug>.png`.

Image check command (used by every task; must print nothing):

```powershell
Get-ChildItem docs/manual, tools/ReaProjectLink/docs/manual -Recurse -Filter *.md | ForEach-Object { $d = $_.DirectoryName; Select-String -Path $_.FullName -Pattern '!\[[^\]]*\]\(([^)]+)\)' -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $p = Join-Path $d $_.Groups[1].Value; if (-not (Test-Path $p)) { "$($_.Value) missing in $d" } } }
```

---

### Task 1: Language exception and demo preparation

**Files:**
- Modify: `AGENTS.md` (Language section)
- Create: demo folders on the NAS (outside the repo)

- [ ] **Step 1:** Propose to the user one bullet for `AGENTS.md` Language section: "User manuals under `docs/manual/` and `tools/*/docs/manual/` are written in Chinese; UI labels and technical names stay in their original form." Apply only after the user approves the wording.
- [ ] **Step 2:** Send the user the media request: one reference video (MP4, 30–60 s, any picture with visible cuts), 3–5 short dialogue WAVs, 2 music WAVs (all 48 kHz). Wait for the files.
- [ ] **Step 3:** Create `ReaProjectLink-Manual-Demo\Master\`, `...\Dialogue\`, `...\Music\` under the demo root and copy the media into each project's folder. Verify: `Get-ChildItem -Recurse` on the demo root lists the media in the expected folders.
- [ ] **Step 4:** Write the scratch capture script `$env:TEMP\reatools-manual\capture-window.ps1 -Title <window title substring> -Out <png path> [-Region x,y,w,h]` using Win32 `PrintWindow` on the matching top-level window. Verify: capture the REAPER main window to a PNG and open it with the Read tool.

### Task 2: Part 1 — install and update

**Files:**
- Create: `docs/manual/zh-CN/install.md`, `docs/manual/zh-CN/images/install-*.png`

- [ ] **Step 1:** Use the installed REAPER (user's choice). ReaPack is already installed there, so describe ReaPack installation from the official instructions without a screenshot.
- [ ] **Step 2:** In the installed REAPER, perform and capture: import the ReaTools repository (or show it already imported in `Manage repositories`), ReaImGui in Browse packages, ReaProjectLink in the ReaTools category, find `Script: ReaProjectLink.lua` in the Action List, add a shortcut, launch the window.
- [ ] **Step 3:** Perform and capture update (`Extensions > ReaPack > Synchronize packages`) and checking the installed version (package's `About` / version history).
- [ ] **Step 4:** Verify the rollback warning: in the installed REAPER, publish a throwaway Source Project with the newest version, roll back ReaProjectLink to an older version through ReaPack's version menu, reopen the project, and record what happens. Capture the rollback menu. Roll forward again afterwards.
- [ ] **Step 5:** Write `install.md`: requirements, install, launch and shortcut, update, version check, rollback with the verified warning, FAQ ("updated but old behavior" → Synchronize + restart the script; "script missing from Action List"; "ReaImGui missing" error text as shown).
- [ ] **Step 6:** Run the image check command. Expected: no output.

### Task 3: Concepts and diagram

**Files:**
- Create: `01-what-it-solves.md`, `02-concepts.md`, `images/src/overview-diagram.svg`, `images/01-overview.png`

- [ ] **Step 1:** Draw `overview-diagram.svg`: Master Project in the middle, Dialogue/Music/SFX Source Projects around it; arrow Source→Master labeled `Publish Delivery` / `Synchronize`; arrow Master→Source labeled `Publish Reference` / `Synchronize`; Chinese captions under each English label.
- [ ] **Step 2:** Render to PNG: `msedge --headless --disable-gpu --screenshot=<out>\01-overview.png --window-size=1600,900 <svg path>`. Verify by opening the PNG with the Read tool.
- [ ] **Step 3:** Write `01-what-it-solves.md` from `product-concept.md` Problem section in plain Chinese: the four pains of copying Tracks, manual bounce/re-import, subprojects, and Reference drift; then "how ReaProjectLink works" with the diagram; then explicit non-goals (no simultaneous editing of one `.rpp`, no auto-conform to picture changes, existing unregistered Items are not adopted).
- [ ] **Step 4:** Write `02-concepts.md`: one table row and one short paragraph each for Source Project, Master Project, Delivery Track, Delivery (and Revision), Reference (and Revision), Publish, Synchronize, managed Items vs local Master content, `_ReaProjectLink` package folder. Term column uses the exact UI spelling.

### Task 4: First walkthrough

**Files:**
- Create: `03-first-walkthrough.md`, `images/03-*.png`

- [ ] **Step 1:** Register `ReaProjectLink_Dev.lua` in the main REAPER if not present. Close any installed ReaProjectLink window first.
- [ ] **Step 2:** Perform and capture on the demo Master: new project saved in `Master\`, import the video onto a Track, `Initialize Master Project`, register the video Track plus Markers/Regions in the Reference card, `Publish Reference` review and result.
- [ ] **Step 3:** Perform and capture on the demo Dialogue Source: new project saved in `Dialogue\`, `Initialize Source Project`, subscribe to the Master's `reference.json`, synchronize with Mirror Master Timeline, place WAV Items, register Delivery Tracks, `Publish Delivery` review (including `Checked Against Reference`) and result.
- [ ] **Step 4:** Perform and capture on the Master: Add Delivery, choose the Dialogue `delivery.json`, Lane Mapping dropdowns and `New tracks go under`, import, final timeline.
- [ ] **Step 5:** Write `03-first-walkthrough.md`: each step = what to do, screenshot, what you should see, one-line "why" linking to the concept. Include the callout that projects must be initialized through ReaProjectLink and existing Items are not adopted.
- [ ] **Step 6:** Run the image check command. Expected: no output.

### Task 5: Daily tasks by role

**Files:**
- Create: `04-master-tasks.md`, `05-source-tasks.md`, `images/04-*.png`, `images/05-*.png`

- [ ] **Step 1:** Master tasks, performed and captured: move a Marker and republish the Reference; add the Music Source as a second Delivery; synchronize an updated Dialogue Delivery (Delivery Update Review counts); move an Item off its mapped Track and accept the local-content prompt; restore the Source snapshot by synchronizing the current Revision; outdated-Reference warning on a Delivery.
- [ ] **Step 2:** Source tasks, performed and captured: synchronize a Reference update (including the offered timeline shift); add/unregister a Delivery Track and `Publish Without Them...`; publish again; cancel a running Publish and `Retry`.
- [ ] **Step 3:** Write both files in the walkthrough's step format; each task starts with one line on when you need it.
- [ ] **Step 4:** Run the image check command. Expected: no output.

### Task 6: Troubleshooting and team appendix

**Files:**
- Create: `06-troubleshooting.md`, `team-appendix.md`, `README.md`, `images/06-*.png`

- [ ] **Step 1:** Reproduce in the demo root only: `Publishing Is Locked` (leave a `.publish.lock` by closing REAPER mid-Publish or copying a lock from a cancelled run), then `Unlock Publishing...`; `Review Out of Date` → `Refresh Review`; `Package Missing` → `Review and Publish`. If a state cannot be reproduced faithfully, write that section text-only and record the gap.
- [ ] **Step 2:** Write `06-troubleshooting.md` as symptom → cause → what to do, including "why were my Items replaced" (managed Items are replaced by the full snapshot; move to local content to keep edits).
- [ ] **Step 3:** Write `team-appendix.md` with marked placeholders `【待补充：……】` for where shared projects live, who owns the Master, and whom to ask.
- [ ] **Step 4:** Write `README.md`: one paragraph on what the manual is, reading order for Master owners and for Source colleagues, link to `docs/manual/zh-CN/install.md` (relative path), and the version the manual matches (`【待发布版本】` until the release exists).
- [ ] **Step 5:** Run the image check command. Expected: no output.

### Task 7: Review and Feishu check

**Files:**
- Modify: any manual file with findings

- [ ] **Step 1:** Read every chapter against its images; fix any text/image mismatch and any UI term spelled differently from the UI.
- [ ] **Step 2:** Ask the user to import `03-first-walkthrough.md` with its `images/` folder into Feishu and confirm images and tables render. Adjust Markdown if not.
- [ ] **Step 3:** Report to the user: files written, discrepancies between product and developer docs, UX issues noticed, sections left text-only, placeholders to fill. Ask whether to commit (`docs(manual): add Chinese install guide and ReaProjectLink manual`).
- [ ] **Step 4:** After the new ReaProjectLink release exists, replace `【待发布版本】` and re-capture any screenshot whose UI changed.
