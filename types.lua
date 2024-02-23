---@meta

---@class Bisector
---@field sv SavedState
---@field priv Private
---@field test table<string, function>
---@field [string] function(...: string[])

---@class Private

---@class addonName : number

---@alias reason
---| "hint" # user submitted a hint command about this addon
---| "dependency"
---| "test" # addon is part of current set under test
---| "proven" # bisect algorithm discovered this addon

---@class results
---@field addons table<addonName, addonState>
---@field libraries table<addonName, string>

---@class addonState
---@field version string
---@field enabled boolean
---@field reason reason
---@field loaded? boolean

---@class SavedState
---@field bisecting boolean
---@field before table<addonName, addonState>
---@field last results
---@field current table<addonName, addonState>
---@field stepSize number
---@field index number
---@field queue addonName[]
---@field test_loaded table<addonName, boolean>
