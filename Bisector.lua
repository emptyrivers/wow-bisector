-- Bisector is marked with CC0 1.0 Universal. To view a copy of this license, visit http://creativecommons.org/publicdomain/zero/1.0

---@type string, Bisector
local addon, bisect = ...

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

do --CLI COMMANDS

  ---@param cmd? string
  function bisect.help(cmd)
    if not cmd then
      bisect.priv.print{
        "",
        "  /bisect help <command> - Show this message, or help for a specific command",
        "  /bisect start - Start a new bisect session",
        "  /bisect good - Mark the current addon set as good",
        "  /bisect bad - Mark the current addon set as bad",
        "  /bisect hint <+|-><addon> - ",
        "  /bisect reset - Reset the current bisect session",
        "  /bisect status - Show the current bisect session status",
        "  /bisect status - Show the current bisect session status",
        "  /bisect print - Print the bisect results",
      }
    elseif cmd == "start" then
      bisect.priv.print{
        "Start a new bisect session. Your current addon set will be stored, and Bisector will begin to disable addons to find the cause of your issue."
      }
    elseif cmd == "good" then
      bisect.priv.print{
        "Mark the current addon set as good (i.e. the issue is not present). Bisector will select another addon set to test, and reload your UI.",
      }
    elseif cmd == "bad" then
      bisect.priv.print{
        "Mark the current addon set as bad (i.e. the issue is present). Bisector will select another addon set to test, and reload your UI.",
      }
    elseif cmd == "hint" then
      bisect.priv.print{
        "Provide a hint to Bisector. If you suspect that a specific addon is or isn't needed to reproduce the issue, you can tell Bisector to include or exclude it from the next set.",
        "  /bisect hint <+|-><addon> - if +, then the addon will be added to the next set. If -, then the addon will be removed from the next set.",
      }
    elseif cmd == "lock" then
      bisect.priv.print{
        "Like a hint, but stronger. If you know that a specific addon is or isn't needed to reproduce the issue, you can tell Bisector to include or exclude it from all future sets.",
        "Note: if you lock an addon as disabled, it is possible that Bisector will not be able to find a set of addons that reproduces the issue.",
        "  /bisect lock <+|-><addon> - if +, then the addon will be added to all future sets. If -, then the addon will be removed from all future sets.",
      }
    elseif cmd == "reset" then
      bisect.priv.print{
        "End the current bisect session. Your addons will be restored to their original state, and Bisector will stop attempting to control the enabled state of your addons.",
      }
    elseif cmd == "status" then
      bisect.priv.print{
        "Show the current bisect session status. This will show you the current state of the bisect session, including the current set of addons being tested, and approximately how many steps Bisector expects to take.",
      }
    elseif cmd == "print" then
      bisect.priv.print{
        "Print the bisect results. This will produce a window with the results of the bisection, showing the narrowest set of addons that reproduces the issue. You can copy this printout to use in a bug report.",
      }
    end
  end

  function bisect.start()
    if bisect.sv.bisecting then
      bisect.priv.print{"Already bisecting. Use /bisect reset to end this session & return to your normal addons, or /bisect good/bad to continue bisecting."}
      return
    end
    bisect.sv = {
      bisecting = true,
      steps = {},
      originalAddons = bisect.priv.currentAddons(),
      hints = {},
      locks = {},
    }
    bisect.priv.next("bad")
  end

  function bisect.good()
    if not bisect.sv.bisecting then
      bisect.priv.print{"Not bisecting. Use /bisect start to start a new bisect session."}
      return
    end
    table.insert(bisect.sv.steps, {addons = bisect.priv.currentAddons(), good = true})
    bisect.priv.next("good")
  end

  ---@param hints string[]
  function bisect.hint(hints)
    if not bisect.sv.bisecting then
      bisect.priv.print{"Not bisecting. Use /bisect start to start a new bisect session."}
      return
    end
    for i = 1, select("#", hints) do
      local hint = select(i, hints)
      local op = hint:sub(1, 1)
      local addon = hint:sub(2)
      if op == "+" then
        bisect.sv.hints[addon] = true
      elseif op == "-" then
        bisect.sv.hints[addon] = false
      else
        bisect.priv.print{string.format("Invalid hint %q", hint)}
      end
    end
  end

  ---@param locks string[]
  function bisect.lock(locks)
    if not bisect.sv.bisecting then
      bisect.priv.print{"Not bisecting. Use /bisect start to start a new bisect session."}
      return
    end
    for i = 1, select("#", locks) do
      local lock = select(i, locks)
      local op = lock:sub(1, 1)
      local addon = lock:sub(2)
      if op == "+" then
        bisect.sv.locks[addon] = true
      elseif op == "-" then
        bisect.sv.locks[addon] = false
      else
        bisect.priv.print{string.format("Invalid lock %q", lock)}
      end
    end
  end

  function bisect.bad()
    if not bisect.sv.bisecting then
      bisect.priv.print{"Not bisecting. Use /bisect start to start a new bisect session."}
      return
    end
    table.insert(bisect.sv.steps, {addons = bisect.priv.currentAddons(), good = false})
    bisect.priv.next("bad")
  end

  function bisect.reset()
    if not bisect.sv.bisecting then
      bisect.priv.print{"Not bisecting. Use /bisect start to start a new bisect session."}
      return
    end
    bisect.priv.loadAddons(bisect.sv.originalAddons)
    bisect.sv.bisecting = false
    bisect.sv.steps = nil
    bisect.sv.originalAddons = nil
    C_UI.Reload()
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

end

bisect.priv = {}

function bisect.priv.init()
  BisectorSaved = BisectorSaved or {}
  bisect.sv = BisectorSaved
end

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

EventUtil.ContinueOnAddOnLoaded(addon, bisect.priv.init)
