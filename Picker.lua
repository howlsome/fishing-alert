-- Fishing Alert: lure picker. A row of lures in your bags, best first.
-- Mouse: click a lure. Keyboard/gamepad: Left/Right or D-pad moves the
-- highlight, your fishing key/button applies it, Escape or B (PAD2) closes.
local ADDON, ns = ...
ns.Picker = {}

local SIZE, GAP, MAX = 44, 8, 10

local frame = CreateFrame("Frame", "FishingAlertPicker", UIParent)
frame:SetFrameStrata("DIALOG")
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
frame:Hide()
tinsert(UISpecialFrames, "FishingAlertPicker") -- Escape closes it

local bg = frame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.75)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -8)
title:SetText("Choose a lure")

local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetPoint("BOTTOM", 0, 6)

local empty = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
empty:SetPoint("CENTER", 0, -6)
empty:SetText("No lures in your bags")

local list, selected = {}, 1

-- Secure button that applies the highlighted lure (bound to the fishing
-- key/button while the picker is open).
local apply = CreateFrame("Button", "FishingAlertPickerApply", UIParent, "SecureActionButtonTemplate")
apply:SetAttribute("type", "macro")
apply:RegisterForClicks("AnyUp", "AnyDown")

local buttons = {}
local function onApplied(lure)
	if lure then ns.say("Applying " .. lure.name .. " (+" .. lure.bonus .. ").") end
	ns.Picker.Hide()
end

local function highlight()
	for i, b in ipairs(buttons) do
		b.sel:SetShown(i == selected and b:IsShown())
	end
	local l = list[selected]
	if l and not InCombatLockdown() then
		apply:SetAttribute("macrotext", ns.Lures.Macro(l.itemID))
		apply.lure = l
	end
end

-- the secure handler acts on only one of the down/up halves of a click
local function isActingHalf(down)
	return (down and true or false) == GetCVarBool("ActionButtonUseKeyDown")
end

apply:SetScript("PostClick", function(self, _, down)
	if isActingHalf(down) then onApplied(self.lure) end
end)

local function getButton(i)
	if buttons[i] then return buttons[i] end
	local b = CreateFrame("Button", "FishingAlertPickerButton" .. i, frame, "SecureActionButtonTemplate")
	b:SetSize(SIZE, SIZE)
	b:RegisterForClicks("AnyUp", "AnyDown")
	b:SetAttribute("type", "macro")
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.sel = b:CreateTexture(nil, "OVERLAY")
	b.sel:SetPoint("TOPLEFT", -4, 4)
	b.sel:SetPoint("BOTTOMRIGHT", 4, -4)
	b.sel:SetColorTexture(1, 0.82, 0, 0.35)
	b.sel:Hide()
	b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	b.count:SetPoint("BOTTOMRIGHT", -2, 2)
	b.bonus = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.bonus:SetPoint("TOP", b, "BOTTOM", 0, -2)
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	b:SetScript("OnEnter", function(self)
		if not self.lure then return end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetItemByID(self.lure.itemID)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("PostClick", function(self, _, down)
		if isActingHalf(down) then onApplied(self.lure) end
	end)
	buttons[i] = b
	return b
end

-- Plain buttons the D-pad / arrow keys click while the picker is open.
local function navButton(name, step)
	local b = CreateFrame("Button", name, UIParent)
	b:RegisterForClicks("AnyDown")
	b:SetScript("OnClick", function()
		if #list == 0 then return end
		selected = (selected - 1 + step) % math.min(#list, MAX) + 1
		highlight()
	end)
end
navButton("FishingAlertPickerPrev", -1)
navButton("FishingAlertPickerNext", 1)
local close = CreateFrame("Button", "FishingAlertPickerClose", UIParent)
close:RegisterForClicks("AnyDown")
close:SetScript("OnClick", function() ns.Picker.Hide() end)

frame:SetScript("OnHide", function()
	-- covers Escape too: give the fishing key its normal job back
	C_Timer.After(0, function() ns.Keys.Update() end)
end)

function ns.Picker.IsShown() return frame:IsShown() end

function ns.Picker.Show()
	if InCombatLockdown() then ns.say("Can't open the lure picker in combat.") return end
	list = ns.Lures.Scan()
	selected = 1
	local n = math.min(#list, MAX)
	for _, b in ipairs(buttons) do b:Hide(); b.lure = nil end
	for i = 1, n do
		local l, b = list[i], getButton(i)
		b.lure = l
		b:SetAttribute("macrotext", ns.Lures.Macro(l.itemID))
		b.icon:SetTexture(l.icon)
		b.count:SetText(l.count > 1 and l.count or "")
		b.bonus:SetText("+" .. l.bonus)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", frame, "TOPLEFT", GAP + (i - 1) * (SIZE + GAP), -28)
		b:Show()
	end
	empty:SetShown(n == 0)
	local keys = ns.Keys.FishKeys()
	hint:SetText(n > 0 and ("Left/Right to choose, " .. table.concat(keys, " or ") .. " to apply") or "")
	frame:SetSize(math.max(240, GAP + n * (SIZE + GAP)), SIZE + 66)
	frame:Show()
	highlight()
	ns.Keys.Update()
end

function ns.Picker.Hide()
	if not InCombatLockdown() then frame:Hide() end
end

function ns.Picker.Toggle()
	if frame:IsShown() then ns.Picker.Hide() else ns.Picker.Show() end
end
