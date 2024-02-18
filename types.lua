---@meta

---@class Bisector
---@field sv SavedState
---@field priv Private
---@field [string] function(...: string[])

---@class Private

---@class SavedState
---@field bisecting boolean
---@field steps {addons: string[], good: boolean}[]
---@field originalAddons string[]
---@field hints table<string, boolean>
---@field locks table<string, boolean>
