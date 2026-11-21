# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

**Bisector** is a World of Warcraft addon that diagnoses addon conflicts using binary search. It progressively enables/disables subsets of addons until the culprit is identified. There is no build step for local development — testing requires loading the addon in WoW itself.

## Release / Packaging

Releases are built by the BigWigsMods packager via GitHub Actions (`.github/workflows/ci.yml`). The workflow:

1. Runs on pushes to `main` and on git tags
2. Applies `wow-xml-namespacer` to namespace-prefix the vendored ClipBoard template
3. Packages and uploads to Curseforge and Wago using API secrets

The `ClipBoard/` directory is a vendored external (pulled from GitHub at package time via `.pkgmeta`). `types.lua` is excluded from releases — it's LuaDoc annotations only.

## Architecture

All core logic lives in a single file: **`Bisector.lua`** (~1343 lines), structured in `do...end` blocks.

### Two namespaces

- `Bisector` (global) — the public API and slash command handler (`/bisect`, `/bsct`)
- `bisect.priv` (local) — all internal implementation, never exposed directly

### Core data model (`SavedState` in `types.lua`)

State is persisted across sessions via `BisectorSaved` (WoW SavedVariables):

- `mode`: `"test"` | `"done"` | `"autoPrint"` | `nil`
- `expectedSet`: map of addon name → `AddOnData` with a `reason` field
- `queue`: ordered list of addons still under test
- `stepSize`, `index`: binary search parameters
- `lastTest`: `"good"` | `"bad"` | `"init"`
- `lastHintSet`: tracks +hint combinations for early termination

### Addon reason taxonomy

Every addon in `expectedSet` carries a `reason`:

- `"init"` — in the initial set when bisection started
- `"test"` — actively being tested this iteration
- `"proven"` — bisection proved it necessary or unnecessary
- `"+hint"` / `"-hint"` — user forced enabled/disabled via `/bisect hint +addon`
- `"auto"` — auto-hinted (Bisector itself, DevTool, BugSack, !BugGrabber)
- `"dependency"` — has unmet dependencies, excluded from testing
- `"extra"` — appeared after bisection started
- `"?hint"` — reverted back to testable

### Algorithm flow (all in `bisect.priv`)

1. `startBisecting()` — captures current addon state, builds initial queue
2. `loadNextSet(reload)` — enables/disables the next binary search subset
3. `continue(decrement)` — handles "good" response, adjusts `index`/`stepSize`
4. `verifyCurrentIsLoaded()` — validates actual vs expected addon states after reload
5. `finish()` — completes the session, classifies remaining addons

Step size halves when `index ≤ stepSize` and `index == queueLength`.

### Hint system (`applyHints`)

- `+addon` — force enable, remove from queue
- `-addon` — force disable, remove from queue
- `!addon` — ignore (fixes meddlers like WeakAuras calling `EnableAddOn`)
- `?addon` — revert to testable

### UI components

Both UI components are defined as XML templates with Lua mixins:

- `ControlPanel.xml` / `ControlPanel.lua` — real-time status panel with action buttons
- `ResultsFrame.xml` / `ResultsFrame.lua` — final report with dependency tree
- `ClipBoard/` — vendored read-only scrolling text widget, namespace-prefixed to `Bisector*` at package time

### Report output (`resultsToString`)

Flags in the output: `P`=proven, `D`=dependent, `T`=test, `H`=hint, `E`=excluded, `A`=auto. Uppercase = loaded at last `/bisect bad`; lowercase = not loaded. Disproven addons are omitted; duplicates say "(see above)".

## Lua environment

`.luarc.json` configures Lua 5.1 with WoW globals (`C_UI`, `C_AddOns`, `ScrollUtil`, `EventUtil`, etc.). The language server will have full WoW API awareness.
