# ReaTools user manual design

## Intent

The team is about to use ReaProjectLink on real cinematic work for the first
time. Existing documentation targets developers (architecture, schemas,
decision logs) and uses internal vocabulary. Colleagues need a manual that
walks them through their first use and leaves them understanding *why* the
tool works the way it does, not only which buttons to press. Success means a
colleague who has never seen ReaProjectLink can follow the manual alone and
reach a first successful Delivery synchronization, and can explain the
Source/Master split in their own words.

The first audience is internal (dialogue, music, and sound-design colleagues
plus whoever owns the Master Project). The manual is published to Feishu
documents in Chinese. It should be written so that a later external edition
needs little rewriting.

## Scope

Two parts, in this order:

1. **Installing and updating ReaTools** — shared across tools so ReaAssetFlow
   can reuse it later.
2. **ReaProjectLink complete user manual.**

### Non-goals

- ReaAssetFlow usage.
- Developer documentation, architecture, or manifest schema details.
- An English edition (only kept possible, not written).
- Changing ReaProjectLink behavior. If writing reveals UX problems, record
  them separately for the user; do not fix them as part of this work.

### Anti-goals

- A button-by-button reference that never explains the model.
- Team-specific details (NAS paths, people, project names) woven into the main
  text so the manual cannot be reused externally.
- Emphasizing NAS paths. Shared storage is described generically ("a directory
  on the team's shared storage"); paths visible in screenshots are incidental.

## Decisions made with the user

- Source of truth lives in the repository as Chinese Markdown, then is moved
  into Feishu. This requires a documented exception to the AGENTS.md rule that
  repository documentation is English; the exception covers user manuals only.
- Tone and depth: a first-use tutorial, fairly detailed, with screenshots.
- The agent produces screenshots by operating REAPER on this machine.
- Demo projects are created under
  `\\audionas.int.hypergryph.com\AudioNas\DI21 Project\Misc\Xichen`.
- Media needed for the demo (reference video, WAV files) is requested from the
  user as a list before the screenshot session; the user prepares it.
- Baseline is the current `main` UI (the card-section and list changes made
  after 0.2.0), not 0.2.0. A new ReaProjectLink version is released before
  colleagues start; the manual names that version once it exists.
- Colleagues run REAPER with the English UI. Menu paths are written in English
  exactly as shown, with Chinese explanation where useful.

## Calls made by the agent (for the user to check)

- Part 1 screenshots come from the user's installed REAPER (user's choice;
  ReaPack is already installed there, so the ReaPack installation step is
  described from the official instructions rather than captured from a clean
  state).
- Lock and interrupted-Publish states are reproduced only inside the demo
  directory. If a state cannot be reproduced faithfully, that section is text
  only and the gap is reported.
- Rollback is documented as the generic ReaPack operation plus a plain warning
  that ReaProjectLink should not be rolled back after a project has been
  published with a newer version; this warning is verified in the portable
  instance before it is written.
- Moving content into Feishu is a manual import by the user. Markdown uses
  relative image paths in an `images/` folder beside each file.
- Team appendix content (where shared projects live, who owns the Master) is
  requested from the user; the agent leaves marked placeholders rather than
  inventing it.

## Structure

### Part 1 — Installing and updating ReaTools

- Requirements: REAPER 7.74+, ReaImGui 0.9-compatible or newer, ReaPack.
- Installing ReaPack and ReaImGui.
- Importing the ReaTools repository URL
  (`https://raw.githubusercontent.com/SounDoer/ReaTools/reapack/index.xml`).
- Installing a tool from the ReaTools category.
- Launching from the Action List (`Script: ReaProjectLink.lua`), optionally
  binding a shortcut or toolbar button.
- Updating (sync packages) and checking the installed version.
- Rolling back to an earlier version through ReaPack.
- FAQ: "I updated but still see the old behavior", "the script is missing from
  the Action List", "ReaImGui missing" error.

### Part 2 — ReaProjectLink manual

1. **What problem it solves.** One page: why not copy Tracks or manually
   re-import bounces. One diagram showing both directions: Source publishes
   audio as a Delivery to Master; Master publishes picture and markers as a
   Reference back to Sources.
2. **Core concepts.** Source Project, Master Project, Delivery, Reference,
   Publish, Synchronize, Delivery Track, managed Items vs. local Master
   content. Plain-language explanation of one or two sentences each. UI terms
   stay in English exactly as shown in the UI, with a Chinese explanation.
3. **First walkthrough.** One Master plus one dialogue Source, from
   initialization to the first successful Delivery synchronization, with
   screenshots at every step. Covers Reference publish and Source-side
   Reference sync along the way. Finishing this section means the reader is
   onboarded.
4. **Daily tasks by role.**
   - Master owner: publish a Reference update, add a Delivery subscription,
     synchronize an updated Delivery, move an Item to local Master content,
     restore the Source snapshot.
   - Source colleague: synchronize a Reference update, adjust Delivery Tracks,
     publish again.
5. **Common situations and problems.** Outdated-Reference warning, Publish
   locked by someone else and Unlock Publishing, interrupted Publish recovery,
   "why were my Items replaced".
6. **Team appendix (removable).** Team-specific notes such as where shared
   projects live and who owns the Master. Kept in a separate file so an
   external edition can drop it.

## Constraints

- Content must match the behavior of the version being released from `main`.
  Screenshots use the development entry (`ReaProjectLink_Dev.lua`) until that
  release exists. Verify each step in REAPER while capturing screenshots; where the product
  differs from the developer docs, the product wins and the discrepancy is
  reported to the user.
- Scope limits from the product must be stated plainly: projects must be
  initialized through ReaProjectLink; existing unregistered Items are not
  adopted.
- Feishu is the final destination: keep Markdown simple (headings, numbered
  steps, tables, callouts as blockquotes, images). No Mermaid or HTML; diagrams
  are image files.
- No product code changes and no new runtime dependencies.

## Left to the builder

- Exact file layout. Suggested: `docs/manual/zh-CN/install.md` for Part 1 and
  `tools/ReaProjectLink/docs/manual/zh-CN/` for Part 2 with an `images/`
  folder beside the Markdown files.
- Demo project names and content, and the exact media list to request.
- Screenshot framing, cropping, and naming.
- How to draw the concept diagram, as long as the output is an image.
- Chapter file splitting within Part 2.
- Wording of the AGENTS.md exception, presented to the user for approval.
