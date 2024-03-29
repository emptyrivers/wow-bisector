
---@type addonName, Bisector
local _, bisect = ...


BisectorResultsFrameMixin = {}

function BisectorResultsFrameMixin:OnLoad()
  self.TitleContainer.TitleText:SetText('Bisector Results')
  self.MaxMinButtonFrame:SetOnMaximizedCallback(function() self:Maximize() end)
  self.MaxMinButtonFrame:SetOnMinimizedCallback(function() self:Minimize() end)

  ScrollUtil.RegisterScrollBoxWithScrollBar(self.Content:GetScrollBox(), self.ScrollBar)
  local withBar = {
    CreateAnchor("TOPLEFT", self, "TOPLEFT", 10, -22),
    CreateAnchor("BOTTOMRIGHT", self, "BOTTOMRIGHT", -22, 1)
  }
  local withoutBar = {
    CreateAnchor("TOPLEFT", self, "TOPLEFT", 10, -22),
    CreateAnchor("BOTTOMRIGHT", self, "BOTTOMRIGHT", -2, 1)
  }
  ScrollUtil.AddManagedScrollBarVisibilityBehavior(self.Content:GetScrollBox(), self.ScrollBar, withBar, withoutBar)
end

function BisectorResultsFrameMixin:Initialize(saved)
  self.saved = saved
  self:ApplyCoords()
  if self:IsMinimized() then
    self.MaxMinButtonFrame:Minimize()
  else
    self.MaxMinButtonFrame:Maximize()
  end
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
    self:ApplyCoords()
    self.is_moving = false
    self:SetUserPlaced(false)
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

function BisectorResultsFrameMixin:IsMinimized()
  return self.saved.minimized
end

function BisectorResultsFrameMixin:Minimize()
  self.saved.minimized = true
  self:StashCoords()
  self:SetHeight(60)
  self:ApplyCoords()
end

function BisectorResultsFrameMixin:Maximize()
  self:SetHeight(300)
  self.saved.minimized = false
end

function BisectorResultsFrameMixin:SetText(text)
  self.Content:SetText(text)
end

