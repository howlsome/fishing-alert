-- Fishing Alert: full-screen edge flash (BigWigs-style)
local ADDON, ns = ...

-- Default colour: blue, pending confirmation against BigWigs' own default.
ns.flashColour = { r = 0, g = 0.4, b = 1 }

local frame = CreateFrame("Frame", "FishingAlertFlashFrame", UIParent)
frame:SetFrameStrata("FULLSCREEN_DIALOG")
frame:SetAllPoints(UIParent)
frame:EnableMouse(false)
frame:Hide()

local edges = {}
local function edge(point1, point2, horizontal, opaqueAtMin)
	local t = frame:CreateTexture(nil, "BACKGROUND")
	t:SetPoint(point1)
	t:SetPoint(point2)
	t:SetColorTexture(1, 1, 1, 1)
	t.horizontal = horizontal
	t.opaqueAtMin = opaqueAtMin
	edges[#edges + 1] = t
	return t
end

-- left, right, top, bottom
local left   = edge("TOPLEFT", "BOTTOMLEFT", true, true)
local right  = edge("TOPRIGHT", "BOTTOMRIGHT", true, false)
local top    = edge("TOPLEFT", "TOPRIGHT", false, false)
local bottom = edge("BOTTOMLEFT", "BOTTOMRIGHT", false, true)

local function layout()
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	local thick = math.floor(math.min(w, h) * 0.15)
	left:SetWidth(thick); right:SetWidth(thick)
	top:SetHeight(thick); bottom:SetHeight(thick)
end

local function paint(c)
	local solid = CreateColor(c.r, c.g, c.b, 0.85)
	local clear = CreateColor(c.r, c.g, c.b, 0)
	for _, t in ipairs(edges) do
		local orient = t.horizontal and "HORIZONTAL" or "VERTICAL"
		if t.opaqueAtMin then
			t:SetGradient(orient, solid, clear)
		else
			t:SetGradient(orient, clear, solid)
		end
	end
end

local ag = frame:CreateAnimationGroup()
local fadeIn = ag:CreateAnimation("Alpha")
fadeIn:SetFromAlpha(0); fadeIn:SetToAlpha(1); fadeIn:SetDuration(0.15); fadeIn:SetOrder(1)
local fadeOut = ag:CreateAnimation("Alpha")
fadeOut:SetFromAlpha(1); fadeOut:SetToAlpha(0); fadeOut:SetDuration(0.35); fadeOut:SetOrder(2)
ag:SetLooping("REPEAT")

local loopsWanted, loopsDone = 1, 0
ag:SetScript("OnLoop", function(self)
	loopsDone = loopsDone + 1
	if loopsDone >= loopsWanted then
		self:Stop()
		frame:Hide()
	end
end)

function ns.Flash(times, colour)
	loopsWanted, loopsDone = times or 3, 0
	layout()
	paint(colour or ns.flashColour)
	ag:Stop()
	frame:Show()
	ag:Play()
end
