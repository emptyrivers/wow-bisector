-- Bisector is marked with CC0 1.0 Universal. To view a copy of this license, visit http://creativecommons.org/publicdomain/zero/1.0

---@type addonName, Bisector
local bisectName, bisect = ...

local debug = false
--@debug@
debug = true
--@end-debug@


-- polyfills
---@diagnostic disable: deprecated
local C_AddOns = C_AddOns or {
  GetNumAddOns = GetNumAddOns,
  GetAddOnInfo = GetAddOnInfo,
  IsAddOnLoadOnDemand = IsAddOnLoadOnDemand,
  IsAddOnLoaded = IsAddOnLoaded,
  EnableAddOn = EnableAddOn,
  DisableAddOn = DisableAddOn,
  GetAddOnDependencies = GetAddOnDependencies,
  GetAddOnMetadata = GetAddOnMetadata,
}
local C_UI = C_UI or {
  Reload = ReloadUi,
}
-- not sure why but i was sure this wouldn't work to re-enable deprecations for the rest of the file
---@diagnostic enable: deprecated


do -- Register CLI
  SLASH_BISECT1, SLASH_BISECT2 = "/bisect", "/bsct"
  ---@param input string
  function SlashCmdList.BISECT(input)
    local args = {strsplit(" ", input)}
    if type(bisect.cli[args[1]]) == "function" then
      bisect.cli[args[1]](select(2, unpack(args)))
    else
      return bisect.cli.help()
    end
  end
end

do --cli command functions

  ---@class BisectCommands
  bisect.cli = {}

  ---@param cmd? string
  function bisect.cli.help(cmd)
    if not cmd then
      bisect.priv.print{
        "",
        "  /bisect help <command> - Show this message, or help for a specific command",
        "  /bisect start - Start a new bisect session",
        "  /bisect hint <+|-|?><addon> - provide 1 or more hints",
        "  /bisect good - Mark the current addon set as good",
        "  /bisect bad - Mark the current addon set as bad",
        "  /bisect continue - Continue the current bisect session",
        "  /bisect reload - Alias for /reloadui",
        "  /bisect reset - Stop bisecting and restore your addons to their original state",
        "  /bisect restore init|bad|next - Restore your addons to their original state, or to the last bad set, or the next set to test.",
        "  /bisect status - Show the current bisect session status",
        "  /bisect print - Print the bisect results",
      }
    elseif cmd == "start" then
      bisect.priv.print{
        "start",
        "Start a new bisect session. Your current addon set will be stored, and Bisector will begin to disable addons to find the cause of your issue."
      }
    elseif cmd == "hint" then
      bisect.priv.print{
        "hint +|-|?<addon> ...",
        "Provide a hint to Bisector. If you suspect that a specific addon is or isn't needed to reproduce the issue, you can tell Bisector to include or exclude it from the next set.",
        "More than one hint can be provided at once by separating them with spaces (e.g. /bisect hint +addon1 -addon2).",
      }
    elseif cmd == "good" then
      bisect.priv.print{
        "good",
        "Mark the current addon set as good (i.e. the issue is not present). Bisector will select another addon set to test, and reload your UI.",
      }
    elseif cmd == "bad" then
      bisect.priv.print{
        "bad",
        "Mark the current addon set as bad (i.e. the issue is present). Bisector will select another addon set to test, and reload your UI.",
      }
    elseif cmd == "continue" then
      bisect.priv.print{
        "continue",
        "Continue the current bisect session. Bisector will select another addon set to test, and reload your UI.",
        "Note: Bisector is modeled after git bisect, where the equivalent command would be 'git bisect skip', but in this application that operation reduces to 'good'."
      }
    elseif cmd == "reload" then
      bisect.priv.print{
        "reload",
        "Alias for /reloadui."
      }
    elseif cmd == "reset" then
      bisect.priv.print{
        "reset",
        "Stop bisecting and restore your addons to their original state. This will also end the current bisect session.",
      }
    elseif cmd == "restore" then
      bisect.priv.print{
        "restore init|bad|next",
        "Restore your addons to their original state, or to the last bad set, or to the next step.",
        "This will not end the current bisect session, but it will reload your UI."
      }
    elseif cmd == "status" then
      bisect.priv.print{
        "status",
        "Show the current bisect session status. This will show you the current state of the bisect session, including the current set of addons being tested, and approximately how many steps Bisector expects to take.",
      }
    elseif cmd == "print" then
      bisect.priv.print{
        "print",
        "Print the bisect results. This will produce a window with the results of the bisection, showing the narrowest set of addons that reproduces the issue. You can copy this printout to use in a bug report.",
        "Note: Bisector will automatically print the results when you end the bisect session, so most of the time this will not be necessary.",
      }
    end
  end

  function bisect.cli.start()
    if bisect.sv.mode ~= nil then
      bisect.priv.print{"Can't start, already bisecting. Use /bisect reset to end this session & return to your normal addons, or /bisect good/bad to continue bisecting."}
      return
    end
    bisect.priv.startBisecting()
    bisect.priv.print{
      "Bisecting started. Use /bisect bad/continue to reload the ui with the next set to test.",
    }
  end

  ---@param ... string[]
  function bisect.cli.hint(...)
    if bisect.sv.mode ~= "test" then
      bisect.priv.print{"Not bisecting. Use /bisect start to start a new bisect session."}
      return
    end
    for i = 1, select("#", ...) do
      local hint = select(i, ...)
      local sign, label = hint:match("([+-?!]?)(.*)")
      if not bisect.priv.hintMakesSense(sign, label) then
        bisect.priv.print{"Invalid hint", hint}
        return
      end
      if sign == "!" or sign == "?" then
        local inQueue = false
        for i = #bisect.sv.queue, 1, -1 do
          if bisect.sv.queue[i] == label then
            inQueue = true
            break
          end
        end
        if not inQueue then
          table.insert(bisect.sv.queue, label)
        end
        bisect.sv.expectedSet[label] = bisect.priv.addonData(label)
        bisect.sv.expectedSet[label].reason = sign == "?" and "test" or "extra"
        if sign == "?" then
          bisect.priv.print{
            string.format("Adding %q to test queue", label)
          }
        else
          bisect.priv.print{
            string.format("Ignoring %q", label)
          }
        end
      else
        for i = #bisect.sv.queue, 1, -1 do
          if bisect.sv.queue[i] == label then
            table.remove(bisect.sv.queue, i)
            break
          end
        end
        if sign == "+" then
          bisect.sv.expectedSet[label] = bisect.priv.addonData(label)
          bisect.sv.expectedSet[label].reason = "+hint"
          bisect.priv.print{
            string.format("Setting %q as enabled", label)
          }
          bisect.sv.lastHintSet = bisect.sv.lastHintSet or {checked = false, set = {
            [label] = true
          }}
          if not bisect.sv.lastHintSet.set[label] then
            bisect.sv.lastHintSet.set[label] = true
            bisect.sv.lastHintSet.checked = false
          end
        else
          bisect.sv.expectedSet[label] = bisect.priv.addonData(label)
          bisect.sv.expectedSet[label].reason = "-hint"
          bisect.priv.print{
            string.format("Setting %q as disabled", label)
          }
        end
      end
    end
  end

  function bisect.cli.good()
    if bisect.sv.mode ~= "test" then
      bisect.priv.print{"Not bisecting. Use /bisect start to start a new bisect session."}
      return
    end
    local ok, reason = bisect.priv.verifyCurrentIsLoaded()
    if ok and reason ~= "hintSet" then
      bisect.priv.continue(true)
    elseif reason == "hintSet" then
      bisect.sv.lastHintSet.checked = true
      bisect.priv.continue(false)
    else
      bisect.priv.continue(false)
    end
  end

  function bisect.cli.bad()
    if bisect.sv.mode ~= "test" then
      bisect.priv.print{"Not bisecting. Use /bisect start to start a new bisect session."}
      return
    end
    local ok, reason = bisect.priv.verifyCurrentIsLoaded()
    if ok or reason == "subset" or reason == "hintSet" then
      bisect.priv.dprint{"removing unloaded addons from queue"}
      if reason == "hintSet" then
        bisect.sv.lastHintSet.checked = true
      end
      bisect.priv.proveAddonState(function(state)
        if reason == "hintSet" and bisect.sv.lastHintSet then
          -- if this is a hintset and we get a bad, great news!
          -- the only enabled addons are the ones in the hintset,
          -- so every addon in test which isn't in there is immediately ruled out
          if state.reason == "test" then
            return false
          end
        elseif state.reason == "test" and not state.enabled then
          return false
        end
      end)
      bisect.priv.captureState()
      -- delete all currently not loaded from queue
      local removedCount = 0
      for i = #bisect.sv.queue, 1, -1 do
        local name = bisect.sv.queue[i]
        local state = bisect.sv.expectedSet[name]
        if not C_AddOns.IsAddOnLoaded(bisect.sv.queue[i]) or not state or state.reason ~= "test" then
          removedCount = removedCount + 1
          table.remove(bisect.sv.queue, i)
        end
      end
      bisect.priv.dprint{string.format("removed %i addons from queue", removedCount)}
      bisect.priv.continue(not (bisect.sv.init or reason == "hintSet"))
    else
      -- superfluous! we could perhaps do something with incomparable
      -- but i don't feel like writing a set intersect operation
      bisect.priv.continue(false)
    end
  end

  function bisect.cli.continue()
    if bisect.sv.mode ~= "test" then
      bisect.priv.print{"Not bisecting. Use /bisect start to start a new bisect session."}
      return
    end
    bisect.priv.continue()
  end

  function bisect.cli.reload()
    C_UI.Reload()
  end

  ---@param to? "init" | "bad"
  function bisect.cli.reset(to)
    if bisect.sv.mode == nil then
      bisect.priv.print{"Not bisecting. Use /bisect start to start a new bisect session."}
      return
    end
    bisect.priv.loadSet(to or "init", false)
    for k, v in pairs(bisect.sv) do
      bisect.sv[k] = nil
    end
    C_UI.Reload()
  end

  function bisect.cli.status()
    if bisect.sv.mode == nil then
      bisect.priv.print{"Not bisecting. Use /bisect start to start a new bisect session."}
      return
    elseif bisect.sv.mode == "test" then
      bisect.priv.print{
        string.format("Step %i of (%i-%i)", bisect.sv.stepsTaken,
          bisect.sv.stepsTaken + math.ceil(math.log(math.max(#bisect.sv.queue, 1), 2)), -- can be a bit of an overestimate but good enough
          #bisect.sv.queue * 2 + bisect.sv.stepsTaken
        ),
        string.format("Queue length: %i", #bisect.sv.queue),
        string.format("Addons disabled in current set: %i", math.min(bisect.sv.stepSize, bisect.sv.index)),
      }
    else
      bisect.priv.print{"Bisect complete. Use /bisect print to see the results."}
    end
  end

  ---@param to "init" | "bad" | "next"
  function bisect.cli.restore(to)
    if bisect.sv.mode == nil then
      bisect.priv.print{"Not bisecting. Use /bisect start to start a new bisect session."}
      return
    end
    bisect.priv.loadSet(to, true)
  end

  function bisect.cli.print()
    if bisect.sv.mode == nil then
      bisect.priv.print{"Not bisecting. Use /bisect start to start a new bisect session."}
      return
    end
    bisect.priv.printResults(bisect.sv.mode == "test")
  end

  function bisect.cli.debug()
    debug = not debug
    bisect.sv.debug = debug
    bisect.priv.print{"Debug mode", debug and "enabled" or "disabled"}
    if debug then
      bisect.priv.startWatching()
    else
      bisect.priv.stopWatching()
    end
  end

end

do -- meat & potatoes code

  ---@class Plumbing
  ---@field addons table<string, fun(): table<addonName, AddOnData>>
  bisect.priv = {
    addons = {}
  }

  ---@type table<addonName, boolean>
  local autoHints = {
    [bisectName] = true, -- it would be very silly to disable ourselves!
    ["!BugGrabber"] = true,
    ["BugSack"] = true,
    ["DevTool"] = true,
    ["BetterAddonList"] = true, -- TODO: drop this one, it's purely to make development of bisector easier
  }

  function bisect.priv.startBisecting()

    for k in pairs(bisect.sv) do
      bisect.sv[k] = nil
    end
    bisect.sv.mode = "test"
    bisect.sv.init = true
    bisect.sv.beforeBisect = bisect.priv.addons.all()
    local toTest = bisect.priv.addons.testable()
    bisect.sv.queue = bisect.priv.constructQueue(toTest)
    bisect.sv.expectedSet = bisect.priv.initialAddOnSet(toTest)
    bisect.sv.stepSize = math.ceil(#bisect.sv.queue / 2)
    bisect.sv.index = #bisect.sv.queue
    bisect.sv.stepsTaken = 0
    bisect.sv.maxSteps = 2 * #bisect.sv.queue
    bisect.sv.minSteps = math.ceil(math.log(#bisect.sv.queue, 2))
  end

  ---@param msgs string[]
  function bisect.priv.print(msgs)
    local prefix = "|cFFDE6CFFBisect|r: "
    local i = 1
    repeat
      print(prefix..msgs[i])
      prefix = ""
      i = i + 1
    until i > #msgs
  end

  ---@param msgs string[]
  function bisect.priv.dprint(msgs)
    if debug then
      local prefix = "|cFFFF2D94Bisect-Debug|r: "
      local i = 1
      repeat
        print(prefix..msgs[i])
        prefix = ""
        i = i + 1
      until i > #msgs
    end
  end

  ---@param decrement? boolean
  function bisect.priv.continue(decrement)
    if bisect.sv.mode ~= "test" then return end
    if decrement then
      bisect.sv.index = math.min(bisect.sv.index - bisect.sv.stepSize, #bisect.sv.queue)
      bisect.priv.dprint{string.format("Decremented index to %i", bisect.sv.index)}
    else
      bisect.sv.index = math.min(bisect.sv.index, #bisect.sv.queue)
      bisect.priv.dprint{string.format("Clamped index to %i", bisect.sv.index)}
    end
    bisect.priv.dprint{string.format("%i addons left in queue", #bisect.sv.queue)}
    if #bisect.sv.queue == 0 then
      bisect.priv.print{"Bisect complete. Use /bisect print to see the results."}
      return bisect.priv.finish()
    end
    if bisect.sv.index <= 0 then
      if bisect.sv.stepSize == 1 then
        bisect.priv.print{"Bisect complete. Use /bisect print to see the results."}
        return bisect.priv.finish()
      end
      bisect.sv.stepSize = math.ceil(bisect.sv.stepSize / 2)
      bisect.sv.index = #bisect.sv.queue
      while bisect.sv.index - bisect.sv.stepSize < 0 and bisect.sv.stepSize > 1 do
        bisect.sv.stepSize = math.ceil(bisect.sv.stepSize / 2)
      end
      bisect.priv.dprint{string.format("Reseting index & stepSize to %i, %i", #bisect.sv.queue, bisect.sv.stepSize)}
    end
    bisect.priv.dprint{
      string.format("Reloading UI with next set of %i addons to test", bisect.sv.stepSize),
    }
    bisect.sv.init = nil
    bisect.priv.loadNextSet(true)
  end

  function bisect.priv.finish()
    bisect.sv.mode = "done"
    bisect.priv.proveAddonState(function(state)
      return state.reason == "test"
    end)
    bisect.priv.captureState()
    bisect.priv.printResults(false)
  end

  local codes = {
    "subset",
    "superset",
    "incomparable",
  }
  local ignoredReasons = {
    ["auto"] = true,
    ["extra"] = true,
    ["dependency"] = true,
  }
  ---@return boolean, nil | "subset" | "superset" | "incomparable" | "hintSet"
  function bisect.priv.verifyCurrentIsLoaded()
    local lastHintSet = bisect.sv.lastHintSet
    local loadedAddons = bisect.priv.addons.loadedAndTestable()
    if lastHintSet and not lastHintSet.checked then
      bisect.priv.dprint{"checking if current is hint set"}
      local isHintSet = true
      for addonName in pairs(lastHintSet.set) do
        if not loadedAddons[addonName] then
          bisect.priv.dprint{string.format("addon %q is a +hint, but isn't loaded", addonName)}
          isHintSet = false
          break
        end
      end
      if isHintSet then
        for addonName in pairs(loadedAddons) do
          if not lastHintSet.set[addonName] then
            local state = bisect.sv.expectedSet[addonName]
            if state and state.reason == "test" then
              bisect.priv.dprint{string.format("addon %q is loaded, but is in test set", addonName)}
              isHintSet = false
              break
            end
          end
        end
      end
      if isHintSet then
        bisect.priv.dprint{"hint set"}
        return true, "hintSet"
      end
    end

    local code = 0
    for name, state in pairs(bisect.sv.expectedSet) do
      if not ignoredReasons[state.reason] and state.enabled and not loadedAddons[name] then
        code = bit.bor(code, 1)
        bisect.priv.dprint{string.format("addon %q is enabled but not loaded", name)}
        break
      end
    end
    -- also check for loaded addons which we aren't expecting
    for addon in pairs(loadedAddons) do
      if not bisect.sv.expectedSet[addon] or bisect.sv.expectedSet[addon].enabled == false and not (bisect.sv.expectedSet[addon].reason == "extra" or bisect.sv.expectedSet[addon].reason == "dependency") then
        code = bit.bor(code, 2)
        bisect.priv.dprint{string.format("addon %q is loaded but not expected", addon)}
        if not bisect.sv.expectedSet[addon] then
          bisect.priv.dprint{"addon not in expected set"}
        else
          bisect.priv.dprint{"addon reason", bisect.sv.expectedSet[addon].reason}
        end
        break
      end
    end
    bisect.priv.dprint{codes[code] or "ok"}
    return code == 0, codes[code]
  end

  ---@param pred fun(state: AddOnData): boolean?
  function bisect.priv.proveAddonState(pred)
    local provedCount = 0
    for name, state in pairs(bisect.sv.expectedSet) do
      if state.reason == "test" then
        local result = pred(state)
        if result ~= nil then
          state.reason = "proven"
          state.enabled = result
          provedCount = provedCount + 1
        end
      end
    end
    bisect.priv.dprint{string.format("proved %i addons", provedCount)}
  end

  function bisect.priv.captureLibraryState()
    local libs = {}
    if LibStub then
      for lib in LibStub:IterateLibraries() do
        libs[lib] = LibStub.minors[lib]
      end
    end
    return libs
  end

  function bisect.priv.captureState()
    bisect.sv.last = {
      addons = {},
      libraries = {},
    }
    for name, state in pairs(bisect.sv.expectedSet) do
      bisect.sv.last.addons[name] = CopyTable(state, true)
    end
    bisect.sv.last.libraries = bisect.priv.captureLibraryState()
    -- todo: add warnings for weird changes in addon data
  end

  function bisect.priv.printLoadedSet()
    local addons = {}
    local seen = {}
    for addon, state in pairs(bisect.sv.expectedSet) do
      if not seen[addon] then
        seen[addon] = {}
        table.insert(addons, seen[addon])
      end
      seen[addon].label = addon
      if state.enabled then
        if C_AddOns.IsAddOnLoaded(addon) then
          if state.reason ~= "test" then
            seen[addon].color = "FFFFFF"
          else
            seen[addon].color = "00FF00"
          end
        else
          seen[addon].color = "FF8800"
        end
      else
        if C_AddOns.IsAddOnLoaded(addon) then
          seen[addon].color = "00FFFF"
        elseif state.reason == "test" then
          seen[addon].color = "FF0000"
        else
          seen[addon].color = "A9A9A9"
        end
      end
    end
    for addon, loaded in pairs(bisect.priv.addons.loaded()) do
      if not seen[addon] then
        seen[addon] = {label = addon}
        table.insert(addons, seen[addon])
        if loaded then
          if bisect.sv.expectedSet[addon] and bisect.sv.expectedSet[addon].enabled and bisect.sv.expectedSet[addon].reason ~= "test" then
            seen[addon].color = "FFFFFF"
          else
            seen[addon].color = "0088FF"
          end
        else
          seen[addon].color = "FFFFFF"
        end
      end
    end
    table.sort(addons, function(a, b) return a.label < b.label end)
    local rope = {}
    for _, addon in ipairs(addons) do
      table.insert(rope, string.format("|cFF%s%s|r", addon.color, addon.label))
    end
    bisect.priv.print{table.concat(rope, "")}
  end

  ---@param incomplete boolean
  function bisect.priv.printResults(incomplete)

    local toPrint = {}
    local dependents = {}
    local statistics = {
      hintsTaken = 0,
      addonsProven = 0,
      addonsDisproven = 0,
      addonsUnproven = 0,
      stepsTaken = bisect.sv.stepsTaken,
      minSteps = bisect.sv.minSteps,
      maxSteps = bisect.sv.maxSteps,
    }

    ---@type results["libraries"]
    local libraries = incomplete and bisect.priv.captureLibraryState() or bisect.sv.last.libraries
    local addons = incomplete and bisect.sv.expectedSet or bisect.sv.last.addons
    for name, state in pairs(addons) do
      if state.reason == "test" or state.reason == "init" then
        bisect.priv.dprint{string.format("skipping %q because it's still under test - %s", name, state.reason)}
        statistics.addonsUnproven = statistics.addonsUnproven + 1
      elseif state.reason == "proven" then
        if state.enabled then
          statistics.addonsProven = statistics.addonsProven + 1
        else
          statistics.addonsDisproven = statistics.addonsDisproven + 1
        end
      elseif state.reason == "+hint" or state.reason == "-hint" then
        statistics.hintsTaken = statistics.hintsTaken + 1
      end

      if state.loaded or state.reason == "test" or state.reason == "init" or state.reason == "dependency" then
        dependents[name] = {
          name = name,
          title = state.title,
          version = state.version,
          reason = state.reason,
          loaded = state.loaded,
          dependents = {},
        }
        if #state.dependencies == 0 then
          toPrint[name] = dependents[name]
        end
      end
    end
    for name, depData in pairs(dependents) do
      for _, dep in ipairs(addons[name].dependencies) do
        if dependents[dep] then
          dependents[dep].dependents[name] = depData
        end
      end
    end

    local reasonToLetter = {
      ["init"]       = { letter = "I", sortOrder = 1 },
      ["test"]       = { letter = "T", sortOrder = 2 },
      ["proven"]     = { letter = "P", sortOrder = 3 },
      ["+hint"]      = { letter = "H", sortOrder = 4 },
      ["-hint"]      = { letter = "h", sortOrder = 5 },
      ["dependency"] = { letter = "D", sortOrder = 6 },
      ["extra"]      = { letter = "E", sortOrder = 7 },
      ["auto"]       = { letter = "A", sortOrder = 8 },
    }
    local arrays = {}
    local function tableToArray(tbl, sortFunc)
      local arr = {}
      for k, v in pairs(tbl) do
        if not arrays[k] then
          arrays[k] = CopyTable(v, true)
        end
        table.insert(arr, v)
      end
      table.sort(arr, sortFunc)
      return arr
    end
    local function sortFunc(a, b)
      if a.reason == b.reason then
        return a.title < b.title
      else
        return reasonToLetter[a.reason].sortOrder < reasonToLetter[b.reason].sortOrder
      end
    end
    local arrayToPrint = tableToArray(toPrint, sortFunc)
    local rope = {}
    table.insert(rope, "Bisect results:")
    table.insert(rope, "")
    table.insert(rope, "report version: 1.0.1")
    if incomplete or statistics.addonsUnproven > 0 then
      table.insert(rope, string.format("WARNING: Bisect algorithm is incomplete, %i addons still under test", statistics.addonsUnproven))
    end
    table.insert(rope, string.format("Bisect took %i out of (%i-%i) steps", statistics.stepsTaken, statistics.minSteps, statistics.maxSteps))
    if statistics.hintsTaken > 0 then
      table.insert(rope, string.format("Hints taken: %i", statistics.hintsTaken))
    end
    table.insert(rope, string.format("Addons ruled out: %i", statistics.addonsDisproven))
    table.insert(rope, string.format("Addons proved: %i", statistics.addonsProven))
    table.insert(rope, "")
    table.insert(rope, "Narrowest set of addons that reproduces the issue:")
    local function addLine(rope, level, title, version, reason, loaded)
      local letter = loaded and reasonToLetter[reason].letter:upper() or reasonToLetter[reason].letter:lower()
      table.insert(rope, string.format("%s|-- %s:%s @ %s", string.rep("|  ", level - 1), letter, title, version))
    end
    local function addDotLine(rope, level, title)
      table.insert(rope, string.format("%s|--%s...(see above)", string.rep("|  ", level - 1), title))
    end
    local addonAlreadyPrinted = {}
    local function printAddOnData(rope, level, data)
      addLine(rope, level, data.title, data.version, data.reason, data.loaded)
      addonAlreadyPrinted[data.name] = true
      for i, dep in ipairs(tableToArray(data.dependents, sortFunc)) do
        if not addonAlreadyPrinted[dep.title] then
          printAddOnData(rope, level + 1, dep)
        else
          addDotLine(rope, level + 1, dep.title)
        end
      end
    end
    for _, addon in ipairs(arrayToPrint) do
      printAddOnData(rope, 1, addon)
    end
    table.insert(rope, "")
    table.insert(rope, "Libraries:")
    for lib, version in pairs(libraries) do
      table.insert(rope, string.format("%s @ %s", lib, version))
    end
    bisect.priv.ensureResultsFrame()
    bisect.frame:Show()
    bisect.frame:SetText(table.concat(rope, "\n"))
  end

  ---@param to "init" | "bad" | "next"
  ---@param reload? boolean
  function bisect.priv.loadSet(to, reload)
    bisect.priv.stopWatching()
    if to == "init" then
      for name, state in pairs(bisect.sv.beforeBisect) do
        if state.enabled then
          C_AddOns.EnableAddOn(name)
        else
          C_AddOns.DisableAddOn(name)
        end
      end
      if reload then C_UI.Reload() end
    elseif to == "bad" then
      for name, state in pairs(bisect.sv.last.addons) do
        if state.enabled then
          C_AddOns.EnableAddOn(name)
        else
          C_AddOns.DisableAddOn(name)
        end
      end
      if reload then C_UI.Reload() end
    elseif to == "next" then
      bisect.priv.loadNextSet(reload)
    end
    -- note that execution diverges from this line if reload is true, but who cares
    bisect.priv.startWatching()
  end

  ---@param reload? boolean
  function bisect.priv.loadNextSet(reload)
    -- Since we call C_UI.Reload() in here,
    -- it's the perfect opportunity to capture the state of addons
    -- without worrying about user shenanigans
    local mode = bisect.sv.lastHintSet and not bisect.sv.lastHintSet.checked and "hintSet" or "test"

    local expected = bisect.sv.expectedSet
    ---@type table<addonName, AddOnData>
    local nextExpect = {}
    for name, state in pairs(bisect.priv.addons.all()) do
      if autoHints[name] then
        -- either this is me, or a 'dev' addon which hasn't changed since the Devonian period
        -- we'll trust that this is not the cause of the issue the user is experiencing
        nextExpect[name] = state
        nextExpect[name].reason = "auto"
        nextExpect[name].enabled = autoHints[name]
        nextExpect[name].loaded = autoHints[name]
        C_AddOns.EnableAddOn(name)
      elseif not expected[name] or expected[name].reason == "extra" then
        -- addon was added after bisect started,
        -- so we just hope the user knows what they're doing...
        nextExpect[name] = state
        nextExpect[name].reason = "extra"
      elseif (#state.dependencies > 0) ~= (expected[name].reason == "dependency") then
        -- addon changed its dependencies between reloads...
        -- move it to the proper section and hope for the best...
        nextExpect[name] = state
        nextExpect[name].reason = #state.dependencies == 0 and "dependency" or "test"
        local inQueue = false
        for i = #bisect.sv.queue, 1, -1 do
          if bisect.sv.queue[i] == name then
            if nextExpect[name].reason ~= "test" then
              bisect.priv.dprint{string.format("removing %q from queue because dependency bullshit", name)}
              table.remove(bisect.sv.queue, i)
            else
              inQueue = true
            end
            break
          end
        end
        if nextExpect[name].reason == "test" then
          nextExpect[name].enabled = false
          nextExpect[name].loaded = false
          C_AddOns.DisableAddOn(name)
          if not inQueue then
            bisect.priv.dprint{string.format("adding %q to queue because dependency bullshit", name)}
            table.insert(bisect.sv.queue, name)
          end
        end
      elseif #state.dependencies ~= 0 then
        nextExpect[name] = state
        nextExpect[name].reason = "dependency"
      elseif expected[name].reason == "proven" then
        nextExpect[name] = state
        nextExpect[name].reason = "proven"
        nextExpect[name].enabled = expected[name].enabled
        nextExpect[name].loaded = expected[name].enabled
        if expected[name].enabled then
          C_AddOns.EnableAddOn(name)
        else
          C_AddOns.DisableAddOn(name)
        end
      elseif expected[name].reason == "+hint" then
        nextExpect[name] = state
        nextExpect[name].reason = "+hint"
        nextExpect[name].enabled = true
        nextExpect[name].loaded = true
        C_AddOns.EnableAddOn(name)
      elseif expected[name].reason == "-hint" then
        nextExpect[name] = state
        nextExpect[name].reason = "-hint"
        nextExpect[name].enabled = false
        nextExpect[name].loaded = false
        C_AddOns.DisableAddOn(name)
      else -- should only be "test" addons which don't have weird dependency bullshit
        nextExpect[name] = state
        nextExpect[name].reason = "test"
        nextExpect[name].enabled = false
        nextExpect[name].loaded = false
        C_AddOns.DisableAddOn(name)
      end
    end
    bisect.sv.expectedSet = nextExpect
    if mode == "test" then
      bisect.priv.dprint{"Enabling test set"}
      for i = #bisect.sv.queue, 1, -1 do
        if not nextExpect[bisect.sv.queue[i]] or nextExpect[bisect.sv.queue[i]].reason ~= "test" then
          -- something in the queue that isn't under test, or was removed...
          -- we'll just ignore it and hope for the best...
          bisect.priv.dprint{string.format("removing %q from queue because unexpected", bisect.sv.queue[i])}
          table.remove(bisect.sv.queue, i)
        end
      end
      for i = 1, #bisect.sv.queue do
        if i > bisect.sv.index or i <= bisect.sv.index - bisect.sv.stepSize then
          nextExpect[bisect.sv.queue[i]].enabled = true
          nextExpect[bisect.sv.queue[i]].loaded = true
          C_AddOns.EnableAddOn(bisect.sv.queue[i])
        end
      end
    elseif mode == "hintSet" then
      bisect.priv.dprint{"Skipping test set because hints haven't been tested yet"}
    end
    bisect.sv.stepsTaken = bisect.sv.stepsTaken + 1
    if reload then C_UI.Reload() end
  end

  local signs = {
    ["+"] = true,
    ["-"] = true,
    ["?"] = true,
    ["!"] = true
  }

  local canWorkWith = {
    -- are there really all that many (insecure) addons with 0 dependencies which are load on demand?
    -- if so, how do they get loaded? are they packaged with another addon, but the author didn't set ##Dependencies ?
    -- in any case, it doesn't exactly block bisect from working; presumably the user would trigger some flow that calls LoadAddOn
    -- when they're following the repro steps
    DEMAND_LOADED = true,
    DISABLED = true,
  }

  ---@param sign "+" | "-" | "?" wtb `keyof` in lsp...
  ---@param addon addonName
  function bisect.priv.hintMakesSense(sign, addon)
    if not signs[sign] then
      bisect.priv.dprint{string.format("Invalid sign %q", sign)}
      return false
    end
    if not addon or addon == "" then
      bisect.priv.dprint{"No addon specified"}
      return false
    end
    local exists = C_AddOns.DoesAddOnExist(addon)
    if not exists then
      bisect.priv.dprint{string.format("Addon %q does not exist", addon)}
      return false
    end
    local dependencies = { C_AddOns.GetAddOnDependencies(addon) }
    local loadable, reason = C_AddOns.IsAddOnLoadable(addon)
    -- since we only control the enable state of addons with 0 dependencies, no need to check for DEP_DISABLED & friends
    if #dependencies > 0 then
      bisect.priv.dprint{string.format("Addon %q has dependencies", addon)}
      return false
    end
    if not loadable and not canWorkWith[reason] then
      bisect.priv.dprint{string.format("Addon %q is not loadable", addon)}
      return false
    end
    return true
  end

  function bisect.priv.ensureResultsFrame()
    if not bisect.frame then
      bisect.frame = CreateFrame("frame", "BisectorResults", UIParent, "BisectorResultsFrameTemplate")
      bisect.sv.frameData = bisect.sv.frameData or {}
      bisect.frame:Initialize(bisect.sv.frameData)
    end
  end

  ---@param nameber number | addonName get it? it's either a number or a name!
  ---@return AddOnData?
  function bisect.priv.addonData(nameber)
    ---@type AddOnData
    local addon
    if type(nameber) == "number" and (nameber <= 0 or nameber % 1 ~= 0 or nameber > C_AddOns.GetNumAddOns()) then
      return
    else
      local name, title, _, loadable, reason, security = C_AddOns.GetAddOnInfo(nameber)
      addon = {
        title = title,
        version = C_AddOns.GetAddOnMetadata(nameber, "Version") or "unknown",
        enabled = C_AddOns.GetAddOnEnableState(nameber, (UnitName("player"))) > 0,
        loadable = loadable or canWorkWith[reason] or false,
        loaded = C_AddOns.IsAddOnLoaded(name),
        name = name --[[@as addonName]],
        security = security,
        dependencies = {C_AddOns.GetAddOnDependencies(nameber)} --[[@as addonName[]],
      }
      end
    return addon
  end

  ---@param predicate? fun(addonData: AddOnData): boolean
  ---@return fun(): table<addonName, AddOnData>
  local function addonSet(predicate)
    return function()
      local addons = {}
      for i = 1, C_AddOns.GetNumAddOns() do
        local addon = bisect.priv.addonData(i)
        if addon and (not predicate or predicate(addon)) then
          addons[addon.name] = addon
        end
      end
      return addons
    end
  end

  bisect.priv.addons.all = addonSet()
  bisect.priv.addons.testable = addonSet(function(addon) return addon.loadable and #addon.dependencies == 0 and addon.security == "INSECURE" and autoHints[addon.name] == nil end)
  bisect.priv.addons.loaded = addonSet(function(addon) return addon.loaded end)
  bisect.priv.addons.loadedAndTestable = addonSet(function(addon) return (addon.loaded and #addon.dependencies == 0 and addon.security == "INSECURE" and autoHints[addon.name] == nil) end)

  ---@param toTest table<addonName, AddOnData>
  ---@return table<addonName, AddOnData>
  function bisect.priv.initialAddOnSet(toTest)
    local addons = bisect.priv.addons.all()
    local initialSet = {}
    for name, addon in pairs(addons) do
      initialSet[name] = CopyTable(addon)
      if autoHints[name] then
        initialSet[name].reason = "auto"
      elseif #addon.dependencies > 0 then
        initialSet[name].reason = "dependency"
      elseif not addon.enabled then
        initialSet[name].reason = "extra"
      elseif not toTest[name] then
        -- this branch should never be taken
        initialSet[name].reason = "extra"
        bisect.priv.dprint{"extra addon???", name}
      else
        initialSet[name].reason = "test"
      end
    end
    return initialSet
  end

  ---@param addons table<addonName, AddOnData>
  ---@return addonName[]
  function bisect.priv.constructQueue(addons)
    local queue = {}
    for addon, data in pairs(addons) do
      if data.enabled then
        table.insert(queue, addon)
      end
    end
    return queue
  end
end

do -- stick bisect into DevTool to debug
  if debug then
    if DevTool then
      DevTool:AddData(bisect, "bisect")
    else
      BISECT_DBG = bisect
    end
  end
end

do -- try to detect runtime changes to addon list
  local watching = debug

  ---@param tbl table
  ---@param func string
  ---@param callback function
  local function snoop(tbl, func, callback)
    hooksecurefunc(tbl, func, function(...)
      if watching then
        callback(...)
      end
    end)
  end
  ---@param func string
  ---@param callback function
  local function snoopGlobal(func, callback)
    hooksecurefunc(func, function(...)
      if watching then
        callback(...)
      end
    end)
  end

  local snooped = false

  function bisect.priv.startWatching()
    watching = true
    do return end
    if not snooped then
      snoop(C_AddOns, "EnableAddOn", function(name)
        bisect.priv.dprint{string.format("EnableAddOn %q", name)}
      end)
      -- Global access of EnableAddOn and friends is deprecated, but as of 25 Feb 2024 weakauras still does it :/
      snoopGlobal("EnableAddOn", function(name)
        bisect.priv.dprint{string.format("EnableAddOn %q", name)}
      end)
      snoop(C_AddOns, "DisableAddOn", function(name)
        bisect.priv.dprint{string.format("DisableAddOn %q", name)}
      end)
      snoopGlobal("DisableAddOn", function(name)
        bisect.priv.dprint{string.format("DisableAddOn %q", name)}
      end)
      snoop(C_AddOns, "LoadAddOn", function(name)
        bisect.priv.dprint{string.format("LoadAddOn %q", name)}
      end)
      snoopGlobal("LoadAddOn", function(name)
        bisect.priv.dprint{string.format("LoadAddOn %q", name)}
      end)
    end
  end

  function bisect.priv.stopWatching()
    watching = false
  end

  if debug then
    -- some (many?) calls to Muck with AddOns might happen in main chunks
    -- and obviously ADDON_LOADED is far too late for that
    -- if user is smart enough to read source code (hello! <3),
    -- then they can set the debug flag earlier than the cli is capable of
    -- and catch at least some of them
    -- I don't feel like trying to force Bisector to always be loaded first,
    -- there's always another !!!!!!!!PompousAddon that tries to win that game so whatever
    bisect.priv.startWatching()
  end
end

do -- initialize the addon
  function bisect.priv.init()
    BisectorSaved = BisectorSaved or {}
    bisect.sv = BisectorSaved
    if bisect.sv.debug ~= nil then
      debug = bisect.sv.debug
    end
    if debug then
      bisect.priv.startWatching()
    end
    if bisect.sv.mode ~= nil then
      bisect.priv.ensureResultsFrame()
    end
  end

  EventUtil.ContinueOnAddOnLoaded(bisectName, bisect.priv.init)
end
