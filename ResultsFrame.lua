
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

  -- keep user from shooting themselves in the foot with their keyboard,
  -- by making it impossible to copy anything but the text I set in here, and the WHOLE text at that
  self.Content:RegisterCallback("OnTextChanged", self.OnTextChanged, self)
  self.Content:RegisterCallback("OnEditFocusGained", self.OnEditFocusGained, self)
  self.Content:RegisterCallback("OnCursorChanged", self.OnCursorChanged, self)
  -- for the CORNER corner case of, 'user presses left with cursor at start, or right with cursor at end'
  -- in which case the cursor doesn't move (so OnCursorChanged doesn't trigger), but the highlight is lost
  -- If I was slightly more pedantic, i'd go through the trouble of chaining the callback registries
  -- so this monkeypatch is indistinguishable from the blizzard templates, but ehhhh.
  -- Maybe if i ever port this code to another project, I'll bother
  self.Content:GetEditBox():SetScript("OnArrowPressed", function(self, ...) print(...) self:HighlightText() end)
  -- self.Content:GetEditBox():SetHistoryLines(0)
  self:SetText(self.results)
end

function BisectorResultsFrameMixin:Initialize(saved)
  self.saved = saved
  if self:IsMinimized() then
    self:SetHeight(60)
  end
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

function BisectorResultsFrameMixin:OnEditFocusGained(editBox)
  editBox:HighlightText()
end

function BisectorResultsFrameMixin:OnCursorChanged(editBox)
  editBox:HighlightText()
end

function BisectorResultsFrameMixin:OnArrowPressed()
  self.Content:GetEditBox():HighlightText()
end

function BisectorResultsFrameMixin:OnTextChanged(editBox, userChange)
  if userChange then
    editBox:SetText(self.results or "")
  end
  editBox:ClearHistory()
  editBox:SetFocus()
end

function BisectorResultsFrameMixin:SetText(text)
  if type(text) ~= "string" then
    error("Expected string, got " .. type(text))
  end
  self.results = text
  if text ~= "" then
    self.Content:GetEditBox():Enable()
  else
    self.Content:GetEditBox():Disable()
  end
  self.Content:SetText(text)
  self.Content:GetEditBox():ClearHistory()
end

function BisectorResultsFrameMixin:Clear()
  self:SetText("")
end


