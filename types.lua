---@meta

---@class Bisector
---@field sv SavedState
---@field priv Private
---@field [string] function(...: string[])

---@class Private

---@class addonName : number

---@alias reason
---| "hint" # user submitted a hint command about this addon
---| "dependency"
---| "test" # addon is part of current set under test
---| "proven" # bisect algorithm discovered this addon

---@class results
---@field addons table<addonName, {version: string, enabled: boolean, loaded: boolean}>
---@field libraries table<addonName, string>

---@class SavedState
---@field bisecting boolean
---@field before table<addonName, boolean>
---@field last results
---@field current table<addonName, boolean>
---@field stepSize number
---@field index number
---@field queue addonName[]
