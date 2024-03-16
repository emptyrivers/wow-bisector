---@meta

---@class Bisector
---@field sv SavedState
---@field cli BisectCommands
---@field priv Plumbing
---@field test table<string, function>
---@field frame any


---@class BisectCommands
---@field reload function

---@class addonName : string

---@class AddOnData
---@field name addonName
---@field title string
---@field version string
---@field enabled boolean
---@field loadable boolean
---@field loaded boolean
---@field dependencies addonName[]
---@field security "INSECURE" | "SECURE"
---@field reason? reason

---@alias reason
---| "init" # addon is part of initial set
---| "+hint" # user submitted a hint command about this addon
---| "-hint" # user submitted a hint command about this addon
---| "test" # addon is part of current set under test
---| "proven" # bisect algorithm discovered this addon
---| "dependency" # has > 0  dependencies
---| "extra" # addon appeared after start of bisect session
---| "auto" # implicitly trusted

---@class AddOnResultData : AddOnData
---@field reason reason

---@class results
---@field addons table<addonName, AddOnResultData>
---@field libraries table<addonName, string>

---@class SavedState
---@field mode? "test" | "done"
---@field init? true
---@field beforeBisect table<addonName, AddOnData>
---@field last results
---@field expectedSet table<addonName, AddOnData>
---@field queue addonName[]
---@field stepSize number
---@field index number
---@field debug? boolean
---@field frameData table
---@field stepsTaken number
---@field maxSteps number
---@field minSteps number
---@field lastHintSet? {checked: boolean, set: table<addonName, true>}
