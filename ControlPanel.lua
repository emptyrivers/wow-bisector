
---@type addonName, Bisector
local _, bisect = ...

BisectorControlPanelMixin = {}

function BisectorControlPanelMixin:OnLoad()
  self.TitleContainer.TitleText:SetText('Bisector')
end

function BisectorControlPanelMixin:Initialize(saved)
  self.saved = saved
  self:ApplyCoords()
  self:Refresh()
end

function BisectorControlPanelMixin:OnShow()
  self:Refresh()
end

function BisectorControlPanelMixin:Refresh()
  local mode = bisect.sv and bisect.sv.mode
  if mode == nil then
    self.StatusText:SetText("Not bisecting")
    self.StepText:SetText("")
  elseif mode == "test" then
    self.StatusText:SetText(string.format("Step %i of (%i-%i)",
      bisect.sv.stepsTaken,
      bisect.sv.stepsTaken + math.ceil(math.log(math.max(#bisect.sv.queue, 1)) / math.log(2)),
      #bisect.sv.queue * 2 + bisect.sv.stepsTaken
    ))
    self.StepText:SetText(string.format("Queue: %i addons remaining", #bisect.sv.queue))
  elseif mode == "autoPrint" or mode == "done" then
    self.StatusText:SetText("Bisect complete")
    self.StepText:SetText("")
  else
    self.StatusText:SetText("Not bisecting")
    self.StepText:SetText("")
  end

  self.StartButton:SetEnabled(mode == nil)
  self.ResetButton:SetEnabled(mode ~= nil)
  self.GoodButton:SetEnabled(mode == "test")
  self.BadButton:SetEnabled(mode == "test")
  self.ContinueButton:SetEnabled(mode == "test" or mode == "autoPrint")
  self.PrintButton:SetEnabled(mode ~= nil)
  self.HintButton:SetEnabled(mode == "test")
  self.HintInput:SetEnabled(mode == "test")
end

function BisectorControlPanelMixin:OnStartClicked()
  bisect.cli.start()
  self:Refresh()
end

function BisectorControlPanelMixin:OnGoodClicked()
  bisect.cli.good()
  self:Refresh()
end

function BisectorControlPanelMixin:OnBadClicked()
  bisect.cli.bad()
  self:Refresh()
end

function BisectorControlPanelMixin:OnContinueClicked()
  bisect.cli["continue"]()
  self:Refresh()
end

function BisectorControlPanelMixin:OnResetClicked()
  bisect.cli.reset()
  -- no Refresh — causes reload
end

function BisectorControlPanelMixin:OnPrintClicked()
  bisect.cli.print()
  self:Refresh()
end

function BisectorControlPanelMixin:OnHintClicked()
  local text = self.HintInput:GetText()
  local tokens = {strsplit(" ", text)}
  local filtered = {}
  for _, t in ipairs(tokens) do
    if t ~= "" then
      table.insert(filtered, t)
    end
  end
  if #filtered > 0 then
    bisect.cli.hint(unpack(filtered))
  end
  self.HintInput:SetText("")
  self:Refresh()
end

function BisectorControlPanelMixin:OnMouseDown(button)
  if button == "LeftButton" then
    self.is_moving = true
    self:StartMoving()
  end
end

function BisectorControlPanelMixin:OnMouseUp(button)
  if button == "LeftButton" and self.is_moving then
    self:StopMovingOrSizing()
    self:StashCoords()
    self:ApplyCoords()
    self.is_moving = false
    self:SetUserPlaced(false)
  end
end

function BisectorControlPanelMixin:StashCoords()
  self.saved.top = self:GetTop() - GetScreenHeight()
  self.saved.left = self:GetLeft()
end

function BisectorControlPanelMixin:ApplyCoords()
  self:ClearAllPoints()
  self:SetPoint("TOPLEFT", self.saved.left or 300, self.saved.top or -200)
end
