---@diagnostic disable

local function inject(tbl, method, func)
  local oldMethod = tbl[method]
  tbl[method] = function(self, ...)
    func(self, oldMethod, ...)
  end
end

BisectorClipBoardMixin = CreateFromMixins(CallbackRegistryMixin)

BisectorClipBoardMixin:GenerateCallbackEvents{
  "OnMouseDown",
  "OnMouseUp",
  "OnTabPressed",
  "OnTextChanged",
  "OnCursorChanged",
  "OnEscapePressed",
  "OnEditFocusGained",
  "OnEditFocusLost",
  "OnClipBoardChanged",
  "OnClipBoardCopied"
}

function BisectorClipBoardMixin:OnLoad_Intrinsic()
  CallbackRegistryMixin.OnLoad(self)
  inject(self, "SetMultiLine", BisectorClipBoardMixin.PreSetMultiline)
  inject(self, "SetFont", BisectorClipBoardMixin.OnSetFont)
  inject(self, "SetSpacing", BisectorClipBoardMixin.OnSetSpacing)
  inject(self, "SetFontObject", BisectorClipBoardMixin.OnSetFontObject)
  self:UpdateTextInsets()
end

function BisectorClipBoardMixin:UpdateTextInsets()
  if self:IsMultiLine() then
    local height, spacing = self:GetFontHeight(), self:GetSpacing()
    local overscan = height + spacing
    self:SetTextInsets(0, 0, -overscan, 0)
  else
    self:SetTextInsets(0, 0, 0, 0)
  end
end

function BisectorClipBoardMixin:OnSetMultiline(callback, multiLine)
  callback(self, multiLine)
  self:UpdateTextInsets()
end

function BisectorClipBoardMixin:OnSetFontObject(callback, ...)
  callback(self, ...)
  self:UpdateTextInsets()
end

function BisectorClipBoardMixin:OnSetFont(callback, ...)
  callback(self, ...)
  self:UpdateTextInsets()
end

function BisectorClipBoardMixin:OnSetSpacing(callback, ...)
  callback(self, ...)
  self:UpdateTextInsets()
end

function BisectorClipBoardMixin:OnMouseDown_Intrinsic()
	self:SetFocus();
	self:TriggerEvent("OnMouseDown", self);
end

function BisectorClipBoardMixin:OnMouseUp_Intrinsic()
	self:TriggerEvent("OnMouseUp", self);
end

function BisectorClipBoardMixin:OnTabPressed_Intrinsic()
	self:TriggerEvent("OnTabPressed", self);
end

function BisectorClipBoardMixin:OnEditFocusGained_Intrinsic()
  self:HighlightClipBoardText()
  self:TriggerEvent("OnEditFocusGained", self);
end

function BisectorClipBoardMixin:OnEditFocusLost_Intrinsic()
	self:ClearHighlightText();

	self:TriggerEvent("OnEditFocusLost", self);
end

function BisectorClipBoardMixin:OnCursorChanged_Intrinsic(x, y, width, height, context)
  if self:IsMultiLine() then
    local cursor = self:GetCursorPosition()
    if cursor == 0 then
      self:SetCursorPosition(1)
    elseif cursor == #self:GetText() then
      self:SetCursorPosition(cursor - 1)
    end
  end
  self:HighlightClipBoardText()
  -- we shouldn't change the cursorOffset & height, even if we bumped the cursor
  -- because those are used in ScrollingClipBoardMixin:ScrollCursorIntoView,
  -- which might scroll to the wrong point and put the cursor in the overscan if we 'fixed' this
	self.cursorOffset = y
	self.cursorHeight = height
  self:TriggerEvent("OnCursorChanged", self, x, y, width, height, context)
end

function BisectorClipBoardMixin:OnEscapePressed_Intrinsic()
	self:ClearFocus();

	self:TriggerEvent("OnEscapePressed", self);
end

function BisectorClipBoardMixin:OnArrowPressed_Intrinsic(key)
  -- singleline editboxes don't clear Highlight on up/down, so long as history is always clear,
  -- but they do clear it on left/right if the cursor is at the respective bookend
  if self:IsMultiLine() then return end
  self:HighlightClipBoardText()
end

function BisectorClipBoardMixin:OnTextChanged_Intrinsic()
  if not self:TextIsClipBoardText() then
    self:SetText(("\n%s\n"):format(self.clipBoardText))
    if not self:IsMultiLine() then
      self:ClearHistory()
    else
      self:SetCursorPosition(1)
    end
    self:HighlightClipBoardText()
  else
    self:TriggerEvent("OnTextChanged", self)
  end

end

function BisectorClipBoardMixin:OnKeyDown(key)
  if key == "c" and IsControlKeyDown() then
    self:TriggerEvent("OnClipBoardCopied", self)
  end
end

function BisectorClipBoardMixin:HighlightClipBoardText()
  if not self:IsMultiLine() then
    self:HighlightText()
  else
    self:HighlightText(1, #self.clipBoardText - 1)
  end
end

function BisectorClipBoardMixin:TextIsClipBoardText()
  if not self:IsMultiLine() then
    return self:GetText() == self.clipBoardText
  else
    return self:GetText() == ("\n%s\n"):format(self.clipBoardText)
  end
end

function BisectorClipBoardMixin:SetClipBoardText(text)
  assert(type(text) == "string", "text must be a string")
  local changed = self.clipBoardText ~= text
  if #text > 0 then
    self:Enable()
    self.clipBoardText = text
  else
    self.clipBoardText = ""
    self:Disable()
  end
  self:SetText((self:IsMultiLine() and #text > 0) and ("\n%s\n"):format(text) or text)
  self:ClearHistory()
  if self:IsMultiLine() then
    self:SetCursorPosition(1)
  end
  if changed then
    self:TriggerEvent("OnClipBoardChanged", self)
  end
end

function BisectorClipBoardMixin:GetCursorOffset()
	return self.cursorOffset or 0;
end

function BisectorClipBoardMixin:GetCursorHeight()
	return self.cursorHeight or 0;
end

function BisectorClipBoardMixin:GetFontHeight()
	return select(2, self:GetFont());
end

function BisectorClipBoardMixin:GetClipBoardText()
	return self.clipBoardText
end

