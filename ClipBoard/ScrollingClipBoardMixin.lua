---@diagnostic disable

BisectorScrollingClipBoardBoxMixin = CreateFromMixins(CallbackRegistryMixin)
BisectorScrollingClipBoardBoxMixin:GenerateCallbackEvents(
	{
		"OnTabPressed",
		"OnTextChanged",
		"OnCursorChanged",
		"OnFocusGained",
		"OnFocusLost",
		"OnEnterPressed",
	}
)

function BisectorScrollingClipBoardBoxMixin:OnLoad()
	CallbackRegistryMixin.OnLoad(self)

	assert(self.fontName)

	local scrollBox = self:GetScrollBox()
	scrollBox:SetAlignmentOverlapIgnored(true)

	local clipBoard = self:GetClipBoard()


	clipBoard.fontName = self.fontName
	clipBoard.defaultFontName = self.defaultFontName
	clipBoard:SetFontObject(self.fontName)

	local fontHeight = clipBoard:GetFontHeight()
	local bottomPadding = fontHeight * .5
	local view = CreateScrollBoxLinearView(0, bottomPadding, 0, 0, 0)
	view:SetPanExtent(fontHeight)
	scrollBox:Init(view)

	clipBoard:RegisterCallback("OnTabPressed", self.OnEditBoxTabPressed, self)
	clipBoard:RegisterCallback("OnTextChanged", self.OnEditBoxTextChanged, self)
	clipBoard:RegisterCallback("OnEnterPressed", self.OnEditBoxEnterPressed, self)
	clipBoard:RegisterCallback("OnCursorChanged", self.OnEditBoxCursorChanged, self)
	clipBoard:RegisterCallback("OnEditFocusGained", self.OnEditBoxFocusGained, self)
	clipBoard:RegisterCallback("OnEditFocusLost", self.OnEditBoxFocusLost, self)
	clipBoard:RegisterCallback("OnMouseUp", self.OnEditBoxMouseUp, self)
end

function BisectorScrollingClipBoardBoxMixin:SetInterpolateScroll(canInterpolateScroll)
	local scrollBox = self:GetScrollBox()
	scrollBox:SetInterpolateScroll(canInterpolateScroll)
end
--[[
function BisectorScrollingClipBoardBoxMixin:OnShow()
	local clipBoard = self:GetClipBoard()
	clipBoard:TryApplyDefaultText()
end
 ]]

function BisectorScrollingClipBoardBoxMixin:OnMouseDown()
	local clipBoard = self:GetClipBoard()
	clipBoard:SetFocus()
end

function BisectorScrollingClipBoardBoxMixin:OnEditBoxMouseUp()
	local allowCursorClipping = false
	self:ScrollCursorIntoView(allowCursorClipping)
end

function BisectorScrollingClipBoardBoxMixin:GetScrollBox()
	return self.ScrollBox
end

function BisectorScrollingClipBoardBoxMixin:HasScrollableExtent()
	local scrollBox = self:GetScrollBox()
	return scrollBox:HasScrollableExtent()
end

function BisectorScrollingClipBoardBoxMixin:GetClipBoard()
	return self:GetScrollBox().ClipBoard
end

function BisectorScrollingClipBoardBoxMixin:SetFocus()
	self:GetClipBoard():SetFocus()
end

function BisectorScrollingClipBoardBoxMixin:SetFontObject(fontName)
	local clipBoard = self:GetClipBoard()
	clipBoard:SetFontObject(fontName)

	local scrollBox = self:GetScrollBox()
	local fontHeight = clipBoard:GetFontHeight()
	local padding = scrollBox:GetPadding()
	padding:SetBottom(fontHeight * .5)

	scrollBox:SetPanExtent(fontHeight)
	scrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
	scrollBox:ScrollToBegin(ScrollBoxConstants.NoScrollInterpolation)
end

function BisectorScrollingClipBoardBoxMixin:ClearText()
	self:SetText("")
end

function BisectorScrollingClipBoardBoxMixin:SetText(text)
	local clipBoard = self:GetClipBoard()
	clipBoard:SetClipBoardText(text)

	local scrollBox = self:GetScrollBox()
	scrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
	scrollBox:ScrollToBegin(ScrollBoxConstants.NoScrollInterpolation)
end

function BisectorScrollingClipBoardBoxMixin:GetClipBoardText()
	local clipBoard = self:GetClipBoard()
	return clipBoard:GetInputText()
end

function BisectorScrollingClipBoardBoxMixin:GetFontHeight()
	local clipBoard = self:GetClipBoard()
	return clipBoard:GetFontHeight()
end

function BisectorScrollingClipBoardBoxMixin:ClearFocus()
	local clipBoard = self:GetClipBoard()
	clipBoard:ClearFocus()
end

function BisectorScrollingClipBoardBoxMixin:SetEnabled(enabled)
	local clipBoard = self:GetClipBoard()
	clipBoard:SetEnabled(enabled)
end

function BisectorScrollingClipBoardBoxMixin:OnEditBoxTabPressed(clipBoard)
	self:TriggerEvent("OnTabPressed", clipBoard)
end

function BisectorScrollingClipBoardBoxMixin:OnEditBoxTextChanged(clipBoard, userChanged)
	local scrollBox = self:GetScrollBox()
	scrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)

	self:TriggerEvent("OnTextChanged", clipBoard, userChanged)
end

function BisectorScrollingClipBoardBoxMixin:OnEditBoxEnterPressed(clipBoard)
	self:TriggerEvent("OnEnterPressed", clipBoard)
end

function BisectorScrollingClipBoardBoxMixin:OnEditBoxCursorChanged(clipBoard, x, y, width, height, context)
	local scrollBox = self:GetScrollBox()
	scrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)

	local allowCursorClipping = context ~= Enum.InputContext.Keyboard
	self:ScrollCursorIntoView(allowCursorClipping)

	self:TriggerEvent("OnCursorChanged", clipBoard, x, y, width, height)
end

function BisectorScrollingClipBoardBoxMixin:OnEditBoxFocusGained(clipBoard)
	self:TriggerEvent("OnFocusGained", clipBoard)
end

function BisectorScrollingClipBoardBoxMixin:OnEditBoxFocusLost(clipBoard)
	self:TriggerEvent("OnFocusLost", clipBoard)
end

function BisectorScrollingClipBoardBoxMixin:ScrollCursorIntoView(allowCursorClipping)
	local clipBoard = self:GetClipBoard()
	local cursorOffset = -clipBoard:GetCursorOffset()
	local cursorHeight = clipBoard:GetCursorHeight()

	local scrollBox = self:GetScrollBox()
	local editBoxExtent = scrollBox:GetFrameExtent(clipBoard)
	if editBoxExtent <= 0 then
		return
	end

	local scrollOffset = Round(scrollBox:GetDerivedScrollOffset())
	if cursorOffset < scrollOffset then
		local visibleExtent = scrollBox:GetVisibleExtent()
		local deltaExtent = editBoxExtent - visibleExtent
		if deltaExtent > 0 then
			local percentage = cursorOffset / deltaExtent
			scrollBox:ScrollToFrame(clipBoard, percentage)
		end
	else
		local visibleExtent = scrollBox:GetVisibleExtent()
		local offset = allowCursorClipping and cursorOffset or (cursorOffset + cursorHeight)
		if offset >= (scrollOffset + visibleExtent) then
			local deltaExtent = editBoxExtent - visibleExtent
			if deltaExtent > 0 then
				local descenderPadding = math.floor(cursorHeight * .3)
				local cursorDeltaExtent = offset - visibleExtent
				if cursorDeltaExtent + descenderPadding > deltaExtent then
					scrollBox:ScrollToEnd()
				else
					local percentage = (cursorDeltaExtent + descenderPadding) / deltaExtent
					scrollBox:ScrollToFrame(clipBoard, percentage)
				end
			end
		end
	end
end
