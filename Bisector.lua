-- Bisector is marked with CC0 1.0 Universal. To view a copy of this license, visit http://creativecommons.org/publicdomain/zero/1.0

---@type string, Bisector
local addonName, bisect = ...


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
    local args = {strsplit(" ", input:lower())}
    if type(bisect[args[1]]) == "function" then
      bisect[args[1]](select(2, unpack(args)))
    else
      return bisect.help()
    end
  end
end

do -- development functions

  bisect.test = {}
  function bisect.test.start()
    return bisect.start(8)
  end

  bisect.test.reload = C_UI.Reload

  function bisect.test.hint()
    bisect.hint({"+1", "-2"})
    bisect.priv.printLoadedSet()
  end

  function bisect.test.load_superset()
    for _, addon in ipairs(bisect.sv.queue) do
      if not bisect.sv.current[addon].enabled and not bisect.sv.test_loaded[addon] then
        bisect.sv.test_loaded[addon] = true
        break
      end
    end
    bisect.priv.printLoadedSet()
  end

  function bisect.test.load_extra()
    bisect.sv.test_loaded[0] = true
    bisect.priv.printLoadedSet()
  end

  function bisect.test.load_subset()
    for _, addon in ipairs(bisect.sv.queue) do
      if bisect.sv.current[addon].enabled and bisect.sv.test_loaded[addon] then
        bisect.sv.test_loaded[addon] = false
        break
      end
    end
    bisect.priv.printLoadedSet()
  end

  function bisect.test.load_incomparable()
    bisect.sv.test_loaded[0] = true
    for _, addon in ipairs(bisect.sv.queue) do
      if bisect.sv.current[addon].enabled and bisect.sv.test_loaded[addon] then
        bisect.sv.test_loaded[addon] = false
        break
      end
    end
    bisect.priv.printLoadedSet()
  end

  function bisect.test.reset_and_reload()
    bisect.reset()
    bisect.test.reload()
  end
end


do --cli command functions

  ---@param cmd? string
  function bisect.help(cmd)
    if not cmd then
      bisect.priv.print{
        "",
        "  /bisect help <command> - Show this message, or help for a specific command",
        "  /bisect start - Start a new bisect session",
        "  /bisect good - Mark the current addon set as good",
        "  /bisect bad - Mark the current addon set as bad",
        "  /bisect reload - Alias for /reloadui",
        "  /bisect hint <+|-|?><addon> - provide 1 or more hints",
        "  /bisect end - End the current bisect session",
        "  /bisect reset - Restore addons to original state",
        "  /bisect status - Show the current bisect session status",
        "  /bisect print - Print the bisect results",
      }
    elseif cmd == "start" then
      bisect.priv.print{
        "start",
        "Start a new bisect session. Your current addon set will be stored, and Bisector will begin to disable addons to find the cause of your issue."
      }
    elseif cmd == "good" then
      bisect.priv.print{
        "good",
        "Mark the current addon set as good (i.e. the issue is not present). Bisector will select another addon set to test, and reload your UI.",
      }
    elseif cmd == "continue" then
      bisect.priv.print{
        "continue",
        "Continue the current bisect session. Bisector will select another addon set to test, and reload your UI.",
        "Note: Bisector is modeled after git bisect, where the equivalent command would be 'git bisect skip', but in this application that operation reduces to 'good'."
      }
    elseif cmd == "bad" then
      bisect.priv.print{
        "bad",
        "Mark the current addon set as bad (i.e. the issue is present). Bisector will select another addon set to test, and reload your UI.",
      }
    elseif cmd == "hint" then
      bisect.priv.print{
        "hint +|-|?<addon> ...",
        "Provide a hint to Bisector. If you suspect that a specific addon is or isn't needed to reproduce the issue, you can tell Bisector to include or exclude it from the next set.",
        "More than one hint can be provided at once by separating them with spaces (e.g. /bisect hint +addon1 -addon2).",
      }
    elseif cmd == "end" then
      bisect.priv.print{
        "end",
        "End the current bisect session. A summary of the bisect results will be printed, and your addons will be restored to their original state.",
        "Once you are ready, /bisect reload to reload your UI and return to your normal addons.",
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

  ---@param foo string
  function bisect.start(foo)
    local num = tonumber(foo) or 0
    if bisect.sv.bisecting then
      bisect.priv.print{"Can't start, already bisecting. Use /bisect reset to end this session & return to your normal addons, or /bisect good/bad to continue bisecting."}
      return
    end
    for k, v in pairs(bisect.sv) do
      bisect.sv[k] = nil
    end
    bisect.sv.bisecting = true
    bisect.sv.before = {}
    bisect.sv.queue = {}
    bisect.sv.current = {}
    bisect.sv.stepSize = math.ceil(num / 2)
    bisect.sv.index = num
    bisect.sv.test_loaded = {}
    for i =  1, num do
      bisect.sv.queue[i] = i --[[@as addonName]]
    end
    bisect.priv.loadNextSet()
    bisect.priv.print{
      "Bisecting started. Use /bisect bad/continue to reload the ui with the next set to test.",
    }
  end

  ---@param hintString string
  function bisect.hint(hintString)
    if not bisect.sv.bisecting then
      bisect.priv.print{"Not bisecting. Use /bisect start to start a new bisect session."}
      return
    end
    local hints = {strsplit(" ", hintString)}
    for _, hint in ipairs(hints) do
      local sign, label = hint:match("([+-?]?)(.*)")
      local addon = tonumber(label) or label
      if not bisect.priv.hintMakesSense(sign, addon) then
        bisect.priv.print{"Invalid hint", hint}
        return
      end
      if sign == "?" then
        local inQueue = false
        for i = #bisect.sv.queue, 1, -1 do
          if bisect.sv.queue[i] == addon then
            inQueue = true
            break
          end
        end
        if not inQueue then
          table.insert(bisect.sv.queue, addon)
        end
        bisect.sv.current[addon] = bisect.sv.current[addon] or {
          enabled = false,
          version = "",
          reason = "test",
        }
      else
        for i = #bisect.sv.queue, 1, -1 do
          if bisect.sv.queue[i] == addon then
            table.remove(bisect.sv.queue, i)
            break
          end
        end
        if sign == "+" then
          bisect.sv.current[addon] = bisect.sv.current[addon] or {
            enabled = true,
            version = "",
            reason = "hint",
          }
          bisect.sv.test_loaded[addon] = true
        else
          bisect.sv.current[addon] = bisect.sv.current[addon] or {
            enabled = false,true
          }
          bisect.sv.test_loaded[addon] = false
        end
      end
    end
  end

  function bisect.good()
    if not bisect.sv.bisecting then
      bisect.priv.print{"Not bisecting. Use /bisect start to start a new bisect session."}
      return
    end

    bisect.priv.continue(bisect.priv.verifyCurrentIsLoaded())
  end

  function bisect.bad()
    if not bisect.sv.bisecting then
      bisect.priv.print{"Not bisecting. Use /bisect start to start a new bisect session."}
      return
    end
    local ok, reason = bisect.priv.verifyCurrentIsLoaded()
    if ok or reason == "subset" then
      bisect.priv.print{"removing unloaded addons from queue"}
      -- copy current to before, and then delete all currently not loaded from queue
      for k, v in pairs(bisect.sv.current) do
        bisect.sv.before[k] = {
          enabled = bisect.sv.test_loaded[k],
          version = v.version,
          reason = "proven",
        }
        v.reason = "proven"
        v.enabled = false
      end
      for i = #bisect.sv.queue, 1, -1 do
        local addon = bisect.sv.queue[i]
        if not bisect.sv.test_loaded[addon] then
          table.remove(bisect.sv.queue, i)
        end
      end
      bisect.priv.captureState()
      bisect.priv.continue(true)
    else
      -- superfluous! we could perhaps do something with incomparable
      -- but i don't feel like writing a set intersect operation
      bisect.priv.continue(false)
    end
  end

  function bisect.continue()
  end

  bisect.reload = function() bisect.priv.print{"Reloading UI..."} --[[ C_UI.Reload() ]] end

  function bisect.reset()
    for k, v in pairs(bisect.sv) do
      bisect.sv[k] = nil
    end
    bisect.priv.print{"reset"}
  end

  function bisect.status()
    if not bisect.sv.bisecting then
      bisect.priv.print{"Not bisecting. Use /bisect start to start a new bisect session."}
      return
    end
    bisect.priv.print{
      "Status",
      string.format("  Current set has %i addons enabled", #bisect.priv.currentAddons()),
      string.format("  Bisector expects to take %i steps", bisect.priv.expectedSteps()),
    }
  end

  function bisect.debug(field)
    if not bisect.sv[field] then
      bisect.priv.print{string.format("No such field %q", field or "")}
      return
    elseif field == "before" then
      local lines = {"Addons before bisecting"}
      for addon, enabled in pairs(bisect.sv.before) do
        table.insert(lines, string.format("  %s - %s", addon, enabled and "enabled" or "disabled"))
      end
      bisect.priv.print(lines)
    else
      bisect.priv.print{string.format("%s = %s", field, tostring(bisect.sv[field]))}
    end
  end
end

-- rest of file is meat & potatoes code

bisect.priv = {}

function bisect.priv.init()
  BisectorSaved = BisectorSaved or {}
  bisect.sv = BisectorSaved
end

EventUtil.ContinueOnAddOnLoaded(addonName, bisect.priv.init)

---@param msgs string[]
function bisect.priv.print(msgs)
  local prefix = "\124cFFDE6CFFBisect\124r: "
  local i = 1
  repeat
    print(prefix..msgs[i])
    prefix = ""
    i = i + 1
  until i > #msgs
end

function bisect.priv.continue(decrement)
  if not bisect.sv.bisecting then return end
  if decrement then
    bisect.sv.index = math.min(bisect.sv.index - bisect.sv.stepSize, #bisect.sv.queue)
    bisect.priv.print{string.format("Decrementing index to %i", bisect.sv.index)}
  end
  if #bisect.sv.queue == 0 then
    bisect.priv.print{"Bisect complete. Use /bisect end to see the results."}
    return bisect.priv.finish()
  end
  if bisect.sv.index <= 0 then
    if bisect.sv.stepSize == 1 then
      bisect.priv.print{"Bisect complete. Use /bisect end to see the results."}
      return bisect.priv.finish()
    end
    bisect.sv.stepSize = math.ceil(bisect.sv.stepSize / 2)
    bisect.sv.index = #bisect.sv.queue
    while bisect.sv.index - bisect.sv.stepSize < 0 and bisect.sv.stepSize > 1 do
      bisect.sv.stepSize = math.ceil(bisect.sv.stepSize / 2)
    end
    bisect.priv.print{string.format("Reseting index & stepSize to %i, %i", #bisect.sv.queue, bisect.sv.stepSize)}
  end
  bisect.priv.print{
    string.format("Reloading UI with next set of %i addons to test", bisect.sv.stepSize),
  }
  bisect.priv.loadNextSet()
  bisect.reload()
end

function bisect.priv.finish()
  bisect.sv.bisecting = false
  for addon, state in pairs(bisect.sv.last.addons) do
    if state.reason == "test" then
      state.reason = "proven"
    end
  end
  bisect.priv.printResults()
end

local codes = {
  "subset",
  "superset",
  "incomparable",
}
---@return boolean, nil | "subset" | "superset" | "incomparable"
function bisect.priv.verifyCurrentIsLoaded()
  local code = 0
  for addon, state in pairs(bisect.sv.current) do
    if state.enabled and not bisect.sv.test_loaded[addon] then
      code = code + 1
      bisect.priv.print{string.format("addon %q is enabled but not loaded", addon)}
      break
    end
  end
  -- also check for loaded addons which we aren't expecting
  for addon, loaded in pairs(bisect.sv.test_loaded) do
    if loaded and not (bisect.sv.current[addon] and bisect.sv.current[addon].enabled and bisect.sv.current[addon].reason == "test") then
      code = code + 2
      bisect.priv.print{string.format("addon %q is loaded but not expected", addon)}
      break
    end
  end
  bisect.priv.print{codes[code] or "ok"}
  return code == 0, codes[code]
end

function bisect.priv.captureState()
  bisect.sv.last = {
    addons = {},
    libraries = {},
  }
  for addon, addonState in pairs(bisect.sv.before) do
    bisect.sv.last.addons[addon] = addonState
  end
end

function bisect.priv.printLoadedSet()
  local addons = {}
  local seen = {}
  for addon, state in pairs(bisect.sv.current) do
    if not seen[addon] then
      seen[addon] = {}
      table.insert(addons, seen[addon])
    end
    seen[addon].label = addon
    if state.enabled then
      if bisect.sv.test_loaded[addon] then
        if state.reason ~= "test" then
          seen[addon].color = "FFFFFF"
        else
          seen[addon].color = "00FF00"
        end
      else
        seen[addon].color = "FF8800"
      end
    else
      if bisect.sv.test_loaded[addon] then
        seen[addon].color = "00FFFF"
      elseif bisect.sv.test_loaded[addon] == false then
        seen[addon].color = "FF0000"
      else
        seen[addon].color = "A9A9A9"
      end
    end
  end
  for addon, loaded in pairs(bisect.sv.test_loaded) do
    if not seen[addon] then
      seen[addon] = {label = addon}
      table.insert(addons, seen[addon])
      if loaded then
        if bisect.sv.current[addon] and bisect.sv.current[addon].enabled and bisect.sv.current[addon].reason ~= "test" then
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

function bisect.priv.printResults()
  local results = {
    "Bisect results",
    "The issue is reproducible with the following addon set:",
  }
  for addon, state in pairs(bisect.sv.last.addons) do
    table.insert(results, string.format("%s - %s", addon, state.enabled and "enabled" or "disabled"))
  end
  bisect.priv.print(results)
end

function bisect.priv.loadNextSet()
  bisect.sv.test_loaded = {}
  for addon, state in pairs(bisect.sv.current) do
    if state.reason == "test" then
      state.enabled = false
      bisect.sv.test_loaded[addon] = false
    end
  end
  for index, addon in ipairs(bisect.sv.queue) do
    bisect.sv.current[addon] = {
      enabled = index > bisect.sv.index or index <= bisect.sv.index - bisect.sv.stepSize,
      version = "1",
      reason = "test",
    }
    bisect.sv.test_loaded[addon] = bisect.sv.current[addon].enabled
  end
  bisect.priv.printLoadedSet()
end

local signs = {
  ["+"] = true,
  ["-"] = true,
  ["?"] = true,
}
function bisect.priv.hintMakesSense(sign, addon)
  if not signs[sign] then return false end
  if not addon or addon == "" then return false end
  if not bisect.sv.current[addon] then return false end
  return true
end

---@param num? number
function bisect.priv.currentAddons(num)
  num = num or 10
  ---@type {title: string, version: string, enabled: boolean, index: number}[]
  local addons = {}
  for i = 1, num do
    --[[ local name = C_AddOns.GetAddOnInfo(i)
    local version = C_AddOns.GetAddOnMetadata(i, "Version") or "unknown"
    local enabled = C_AddOns.GetAddOnEnableState(i, (UnitName("player"))) > 0
    table.insert(addons, {title = name, version = version, enabled = enabled}) ]]
    table.insert(addons, {title = "addon" .. i, version = "1", enabled = true, index = i})
  end
  return addons
end

if DevTool then
  DevTool:AddData(bisect, "bisect")
else
  BISECT_DBG = bisect
end

