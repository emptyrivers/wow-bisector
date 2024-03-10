
---@type addonName, Bisector
local _, bisect = ...


BisectorResultsFrameMixin = {}

local fill = string.rep("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis knostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\n\n", 10)

function BisectorResultsFrameMixin:OnLoad()
  ButtonFrameTemplate_HidePortrait(self)
  self.TitleContainer.TitleText:SetText('Bisector Results')
  self.MinimizeButton:SetOnMaximizedCallback(function() self:Maximize() end)
  self.MinimizeButton:SetOnMinimizedCallback(function() self:Minimize() end)
  ScrollUtil.RegisterScrollBoxWithScrollBar(self.Content:GetScrollBox(), self.ScrollBar)
  self.Content:SetText(fill)
end

function BisectorResultsFrameMixin:Initialize(saved)
  self.saved = saved
  self:ApplyCoords()
end

function BisectorResultsFrameMixin:OnMouseDown(button)
  if button == "LeftButton" then
    self.is_moving = true
    self:StartMoving()
  end
end

function BisectorResultsFrameMixin:OnMouseUp(button)
  if button == "LeftButton" and self.is_moving then
    self:StopMovingOrSizing()
    self:StashCoords()
    self.is_moving = false
  end
end

function BisectorResultsFrameMixin:StashCoords()
  self.saved.top = self:GetTop() - GetScreenHeight()
  self.saved.left = self:GetLeft()
end

function BisectorResultsFrameMixin:ApplyCoords()
  self:ClearAllPoints()
  self:SetPoint("TOPLEFT", self.saved.left or 200, self.saved.top or -200)
end


function BisectorResultsFrameMixin:Minimize()
  self.Content:Hide()
  self.ScrollBar:Hide()
  self:StashCoords()
  self:ApplyCoords()
  self.height = self:GetHeight()
  self:SetHeight(60)
end

function BisectorResultsFrameMixin:Maximize()
  self.Content:Show()
  self.ScrollBar:Show()
  self:SetHeight(300)
end

BisectorResultsEditBoxMixin = {}

function BisectorResultsEditBoxMixin:OnLoad()
  self:SetText(self.results)
end

function BisectorResultsEditBoxMixin:OnChar()
  self:SetText(self.results)
end