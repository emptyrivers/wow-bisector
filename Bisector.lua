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
        "  /bisect hint <+|-><addon> - provide 1 or more hints",
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
        "hint +|-<addon> ...",
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
      bisect.priv.print{"Already bisecting. Use /bisect reset to end this session & return to your normal addons, or /bisect good/bad to continue bisecting."}
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
    for i =  1, num do
      bisect.sv.queue[i] = i --[[@as addonName]]
    end
    bisect.priv.loadNextSet()
    bisect.priv.print{
      "Bisecting started. Use /bisect bad/continue to reload the ui with the next set to test.",
    }
  end

  function bisect.test_start()
    return bisect.start(8)
  end

  bisect.test_reload = C_UI.Reload

  ---@param hints string[]
  function bisect.hint(hints)
    if not bisect.sv.bisecting then
      bisect.priv.print{"Not bisecting. Use /bisect start to start a new bisect session."}
      return
    end
  end

  function bisect.good()
    if not bisect.sv.bisecting then
      bisect.priv.print{"Not bisecting. Use /bisect start to start a new bisect session."}
      return
    end
    bisect.priv.continue(true)
  end

  function bisect.bad()
    if not bisect.sv.bisecting then
      bisect.priv.print{"Not bisecting. Use /bisect start to start a new bisect session."}
      return
    end
    -- copy current to before, and then delete all false in current from queue
    for k, v in pairs(bisect.sv.current) do
      bisect.sv.before[k] = v
    end
    for i = #bisect.sv.queue, 1, -1 do
      local addon = bisect.sv.queue[i]
      if not bisect.sv.current[addon] then
        table.remove(bisect.sv.queue, i)
      end
    end
    bisect.priv.continue(true)
  end

  function bisect.continue()
  end

  bisect.reload = function() bisect.priv.print{"Reloading UI..."} --[[ C_UI.Reload() ]] end

  function bisect.reset()
    if not bisect.sv.bisecting then
      bisect.priv.print{"Not bisecting. Use /bisect start to start a new bisect session."}
      return
    end
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
  if decrement then
    bisect.sv.index = bisect.sv.index - bisect.sv.stepSize
  end
  if bisect.sv.index <= 0 then
    if bisect.sv.stepSize == 1 then
      bisect.priv.print{"Bisect complete. Use /bisect end to see the results."}
      return
    else
      bisect.sv.stepSize = math.ceil(bisect.sv.stepSize / 2)
      bisect.sv.index = #bisect.sv.queue
    end
  end
  bisect.priv.loadNextSet()
  bisect.reload()
end

function bisect.priv.bulkDisable(addons)
  for _, addon in ipairs(addons) do
    bisect.sv.current[addon] = false
  end
end

function bisect.priv.loadNextSet()
  local rope = {}
  for index, addon in ipairs(bisect.sv.queue) do
    bisect.sv.current[addon] = index > bisect.sv.index or index <= bisect.sv.index - bisect.sv.stepSize
    rope[index] = bisect.sv.current[addon] and "1" or "0"
  end
  bisect.priv.print{table.concat(rope, "")}
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

BISECT_DBG = bisect

