-- Fishing Alert: big countdown bar for the 30-second cast
local ADDON, ns = ...
ns.Bar = {}

-- Bites in Howl's first test session landed 13-21s in; the bar turns gold
-- after this many seconds as a "watch closely now" hint.
local WATCH_AFTER = 10

local bar = CreateFrame("StatusBar", "FishingAlertBar", UIParent)
bar:SetSize(340, 28)
bar:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetMinMaxValues(0, 30)
bar:Hide()

local bg = bar:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.6)

local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
text:SetPoint("CENTER")

local startT, endT = 0, 0

bar:SetScript("OnUpdate", function(self)
	local now = GetTime()
	local remaining = endT - now
	if remaining <= 0 then self:Hide() return end
	self:SetValue(remaining)
	if now - startT >= WATCH_AFTER then
		self:SetStatusBarColor(1, 0.82, 0)
		text:SetFormattedText("Watch the bobber  %ds", math.ceil(remaining))
	else
		self:SetStatusBarColor(0.2, 0.55, 1)
		text:SetFormattedText("Fishing  %ds", math.ceil(remaining))
	end
end)

function ns.Bar.Start()
	if not (ns.db and ns.db.showBar) then return end
	local _, _, _, startMs, endMs = UnitChannelInfo("player")
	if startMs and endMs then
		startT, endT = startMs / 1000, endMs / 1000
	else
		startT, endT = GetTime(), GetTime() + 30
	end
	bar:SetMinMaxValues(0, endT - startT)
	bar:Show()
end

function ns.Bar.Stop()
	bar:Hide()
end
