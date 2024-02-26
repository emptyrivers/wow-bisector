---@meta

---@class Bisector
---@field sv SavedState
---@field priv Private
---@field test table<string, function>
---@field [string] function(...: string[])

---@class Private

---@class addonName : number

---@class AddOnData
---@field name addonName
---@field title string
---@field version string
---@field enabled boolean
---@field loadable boolean
---@field dependencies addonName[]
---@field security "INSECURE" | "SECURE"

---@class TestableAddOnData : AddOnData
---@field reason reason

---@alias reason
---| "init" # addon is part of initial set
---| "+hint" # user submitted a hint command about this addon
---| "-hint" # user submitted a hint command about this addon
---| "test" # addon is part of current set under test
---| "proven" # bisect algorithm discovered this addon
---| "dependency" # has > 0  dependencies
---| "extra" # addon appeared after start of bisect session
---| "auto" # implicitly trusted

---@class results
---@field addons table<addonName, AddOnData>
---@field libraries table<addonName, string>

---@class SavedState
---@field mode? "test" | "done"
---@field init? true
---@field beforeBisect table<addonName, AddOnData>
---@field lastBadSet results
---@field expectedSet table<addonName, TestableAddOnData>
---@field queue addonName[]
---@field stepSize number
---@field index number
