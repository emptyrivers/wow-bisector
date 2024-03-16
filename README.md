# Bisector

Bisector is a small commandline-only addon designed to help you narrow down which addon (or, which combination of addons) is causing problems for you.

## Quick Start

If you were directed here by an addon author in a ticket you opened, then follow these instructions:

### 0. Install Bisector

We're available for download at your favorite addon distributor, so long as that's [Curseforge](https://www.curseforge.com/wow/addons/bisector) or [Wago Addons](https://addons.wago.io/addons/wow-bisector).

### 1. Initialize the session

```text
/bisect start
```

### 2. Add any hints the author asked for, if any

For example, if a WeakAuras maintainer asked you to give the hint `+WeakAuras !WeakAurasCompanion` to Bisector, you would use this command:

```text
/bisect hint +WeakAuras !WeakAurasCompanion
```

### 3. Tell Bisector if you can reproduce the problem

If you can't reproduce the problem:

```text
/bisect good
```

If you can:

```text
/bisect bad
```

Bisector should reload your UI each time you use either command, each time loading a different set of addons for you to test.

### 3a. Repeat step 3 until Bisector says it's done

You'll know it's done when a message appears in your chat frame that looks like this:

```text
Bisect complete. Use /bisect print to see the results.
```

### 4. Copy the report and paste it into your ticket

A window with the title "Bisector Results" should be visible. If not, then use:

```text
/bisect print
```

### 5. Go back to playing the game :)

This command will restore your addons to the way they were before you started the bisect session:

```text
/bisect reset
```

## Usage

Nearly all of your interaction with Bisector is done through the `/bisect` slash command. The following commans are supported:

- /bisect help
  - prints a help message
- /bisect start
  - initializes a bisect session. This takes a snapshot of the enable stats of your addons, so that when you're done, you can return to normal gameplay with minimal hassle.
- /bisect good
  - signals to Bisector that the current addon set *does not* reproduce the problem you're trying to narrow down, and load the next set to test.
- /bisect bad
  - signals to Bisector that the current addon set *does* reproduce the problem, and load the next addon set to test.
- /bisect continue
  - loads the next untested addon set, and reloads the UI.
- /bisect hint
  - provides a hint to Bisector to try to speed up your progress, or to workaround certain behaviors by addons that can mess Bisector Up. See [below](#hints) for more information
- /bisect status
  - prints out a summary of how far into the current bisect session you have progressed, and an estimate of how many more steps are necessary.
- /bisect print
  - produces a printout you can copy into a bug report. See [below](#how-to-interpret-a-bisector-report) for more details.
- /bisect restore set
  - Loads an addon set without marking the current one as good|bad.
    - init - restores the original addon set
    - last - restores the last addon set you marked with /bisect bad
    - next - equivalent to /bisect continue
- /bisect reset
  - Stops the bisect session, and restores you to your original addon set.
- /bisect reload
  - alias for /reloadui

## Hints

If you suspect that a particular addon is not necessary to reproduce your issue, or if you're trying to find which addon is interfering with another known addon, you can provide a hint to Bisector to speed things up. The syntax is as follows:

/bisect hint hint1 hint2 hint3 ...

Where each hintX consists of a sign, followed by an addon name. For example, if you are sure that ElvUI is irrelevant to the issue you have, then `/bisect hint -ElvUI` will cause Bisector to disable ElvUI for the rest of your addon session.

The supported hint signs are as follows:

- \+
  - marks an addon as required. Bisector will keep it enabled for the remainder of the bisect session.
- \-
  - marks an addon as not required. Bisector will keep it disabled for the remainder of the bisect session.
- \!
  - marks an addon as extra. Bisector will ignore the enabled/disabled state of the addon. This is useful if an addon is calling EnableAddOn/DisableAddOn & thus meddling with the loaded addon set.
- ?
  - marks and addon as testable. Bisector will add it to the list of addons to test enable/disable states. This is useful to 'unset' a hint you previously gave to Bisector.

## How to Interpret a Bisector Report

Imagine for a moment that there was some obscure interaction between the WeakAuras, BigWigs, and Details! Damage Meter addons. Then, running Bisector to completion would produce a report similar to this:

```plaintext
Bisect results:

report version: 1.0.1
Bisect took 17 out of (5-112) steps
Addons ruled out: 52
Addons proved: 3

Narrowest set of addons that reproduces the issue:
|-- P:BigWigs @ v324.5
|  |-- d:BigWigs [Aberrus, the Shadowed Crucible] @ v324.5
|  |-- d:BigWigs [Amirdrassil, the Dream's Hope] @ v324.5
|  |-- d:BigWigs [Battle for Azeroth] @ v10.2.1
|  |-- d:BigWigs [Classic] @ v10.2.58
|  |-- D:BigWigs [Core] @ v324.5
|  |  |-- D:BigWigs [Options] @ v324.5
|  |  |-- D:BigWigs [Plugins] @ v324.5
|  |  |  |-- D:BigWigs [Options] @ v324.5
|  |-- d:BigWigs [Dragon Isles] @ v324.5
|  |-- D:BigWigs [Options] @ v324.5
|  |-- D:BigWigs [Plugins] @ v324.5
|  |  |-- D:BigWigs [Options] @ v324.5
|  |-- d:BigWigs [Vault of the Incarnates] @ v324.5
|  |-- d:LittleWigs @ v10.2.41
|  |-- d:LittleWigs [Battle for Azeroth] @ unknown
|  |-- d:LittleWigs [Burning Crusade] @ unknown
|  |-- d:LittleWigs [Cataclysm] @ unknown
|  |-- d:LittleWigs [Classic] @ unknown
|  |-- d:LittleWigs [Legion] @ unknown
|  |-- d:LittleWigs [Mists of Pandaria] @ unknown
|  |-- d:LittleWigs [Shadowlands] @ unknown
|  |-- d:LittleWigs [Warlords of Draenor] @ unknown
|  |-- d:LittleWigs [Wrath of the Lich King] @ unknown
|-- P:Details! Damage Meter @ #Details.20240314.12553.156
|  |-- D:Details!: Compare 2.0 @ unknown
|  |-- D:Details!: Encounter Breakdown (plugin) @ unknown
|  |-- D:Details!: Raid Check (plugin) @ unknown
|  |-- d:Details!: Storage @ unknown
|  |-- D:Details!: Streamer (plugin) @ unknown
|  |-- D:Details!: Tiny Threat (plugin) @ unknown
|  |-- D:Details!: Vanguard (plugin) @ unknown
|-- P:WeakAuras @ @project-version@
|  |-- D:WeakAuras Archive @ @project-version@
|  |-- d:WeakAuras Model Paths @ @project-version@
|  |-- D:WeakAuras Options @ @project-version@
|  |  |-- d:WeakAuras Model Paths @ @project-version@
|-- E:WeakAuras Companion @ 5.2.3
|-- A:BetterAddonList @ 1.1.7
|-- A:Bisector @ 1.0
|-- A:BugGrabber @ v10.2.3
|-- A:BugSack @ v10.2.3
|-- A:DevTool @ 1.0.9

Libraries:
AceDBOptions-3.0 @ 15
AceHook-3.0 @ 9
AceConfig-3.0 @ 3
AceAddon-3.0 @ 13
LibDataBroker-1.1 @ 4
LibSharedMedia-3.0 @ 8020003
LibDBIcon-1.0 @ 52
AceGUI-3.0 @ 41
AceConfigCmd-3.0 @ 14
AceConfigRegistry-3.0 @ 21
AceLocale-3.0 @ 6
AceTab-3.0 @ 9
LibOpenRaid-1.0 @ 126
AceConsole-3.0 @ 7
AceSerializer-3.0 @ 5
DetailsFramework-1.0 @ 525
LibDeflate @ 3
AceConfigDialog-3.0 @ 86
NickTag-1.0 @ 16
LibGraph-2.0 @ 90062
AceComm-3.0 @ 12
AceEvent-3.0 @ 4
AceBucket-3.0 @ 4
LibWindow-1.1 @ 8
CallbackHandler-1.0 @ 8
LibDialog-1.0 @ 8
AceTimer-3.0 @ 17
LibTranslit-1.0 @ 3
AceDB-3.0 @ 28
AceGUI-3.0-DropDown-ItemBase @ 20
```

As of report version 1.0.1, there are three parts to the report, in the following order:

### Report Summary

This part begins with the line `Bisector Report:`, and provides the following information:

- report version
  - the report version. Refer to this document for instructions on how to interpret a particular report version.
- step count
  - The total # of steps (UI reloads) Bisector took, relative to an estimate of the min & max # of steps Bisector could have taken. Provided mainly for debugging purposes & because it's mildly interesting.\
- hints taken
  - The # of addons which were included or excluded from the enabled set via hints.
- Unproven AddOns
  - The # of addons which remain in Bisector's queue of addons to test. This line is only shown if the report was produced before the end of the bisect session.
- Disproven Addons
  - The # of addons, not including hints, which were tested & found not to be necessary to reproduce the issue.
- Proven Addons
  - The # of addons, not including hints, which were tested & found to be necessary to reproduce the issue

### Addon Tree

This report part begins with the string `Narrowest set of addons that reproduces the issue:`, which is then followed with a dependency tree of all addons Bisector considers relevant to the bisect session. Each root node in the tree view is an addon with 0 dependencies, and the rest of the nodes are addons with at least one dependency (optional dependencies are not counted). The string @ each node of the tree view should be interpreted as follows:

`flag:Addon Title @ version`

`Addon Title` & `version` are strings from the addon's toc metadata (if `version` is not provided, it will be displayed as `unknown` in this report). The `flag` symbol should be interpreted as follows:

- I
  - currently unused
- T
  - The addon is in Bisector's queue of addons to test.
- P
  - The addon has been proven to Bisector's satisfaction as being necessary to reproduce the issue.
- H
  - The addon is excluded from Bisector's queue via a `+hint` or a `-hint`.
- D
  - The addon is a dependency of another addon. Bisector does not attempt to test the enable/disable state of dependencies directly.
- E
  - The addon is excluded from the addon test set. This either is because of a `!hint`, or because the addon was not part of the original addon set at `/bisect start`
- A
  - The addon is automatically enabled for the bisect session. This is reserved for debugging addons like !Bugsack or DevTool, and of course Bisector itself.

Furthermore, the flag will be displayed in upper case if the addon was loaded at the moment of the last `/bisect bad` command. Otherwise it will be lower case.

Addons which have more than one dependency will be displayed multiple times in the tree view (once for each dependency displayed), though for brevity any dependents of that addon will not be displayed. Supernumerary occurences of the same addon in the tree will be displayed as follows:

`...Addon Title (see above)`

For the sake of readability, Addons which are proven to not be necessary are not included in the tree view. Additionally, the tree view is sorted by flag (in the same order as the above list), and then ascending alphanumerically by Title.

### Libraries

This report part begins with the line `Libraries:`, and is only included if LibStub is installed. If LibStub is installed, then a snapshot of the currently registered libraries is displayed in this report part.Each line represents a different library registered with LibStub, and should be interpreted as follows:

`Library Major @ minor`

Where `Library Major` is the major version (what is normally considered the 'name' of the library), and `minor` the minor version.
