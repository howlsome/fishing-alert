-- Fishing Alert: a big pulsing marker above the bobber.
-- The game gives the soft-interact target (the bobber) a nameplate when
-- SoftTargetNameplateInteract is on (set in Icon.lua). We pin our marker to
-- that nameplate so it follows the bobber on screen.
local ADDON, ns = ...
ns.Marker = {}

local marker = CreateFrame("Frame", "FishingAlertMarker", UIParent)
marker:SetSize(56, 56)
marker:SetFrameStrata("HIGH")
marker:Hide()

local icon = marker:CreateTexture(nil, "ARTWORK")
icon:SetAllPoints()
icon:SetTexture("Interface\\Cursor\\Fishing") -- the fishing hook mouse cursor

-- Solid border just outside the icon, in the marker colour. A dark backing
-- behind the icon keeps the hook readable against bright water.
local backing = marker:CreateTexture(nil, "BACKGROUND")
backing:SetAllPoints()
backing:SetColorTexture(0, 0, 0, 0.55)

local border = {}
for i = 1, 4 do border[i] = marker:CreateTexture(nil, "OVERLAY") end
local function layoutBorder(thick)
	local top, bottom, left, right = border[1], border[2], border[3], border[4]
	for _, t in ipairs(border) do t:ClearAllPoints() end
	top:SetPoint("BOTTOMLEFT", marker, "TOPLEFT", -thick, 0)
	top:SetPoint("BOTTOMRIGHT", marker, "TOPRIGHT", thick, 0)
	top:SetHeight(thick)
	bottom:SetPoint("TOPLEFT", marker, "BOTTOMLEFT", -thick, 0)
	bottom:SetPoint("TOPRIGHT", marker, "BOTTOMRIGHT", thick, 0)
	bottom:SetHeight(thick)
	left:SetPoint("TOPRIGHT", marker, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMRIGHT", marker, "BOTTOMLEFT", 0, 0)
	left:SetWidth(thick)
	right:SetPoint("TOPLEFT", marker, "TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMLEFT", marker, "BOTTOMRIGHT", 0, 0)
	right:SetWidth(thick)
end

local arrow = marker:CreateTexture(nil, "OVERLAY")
arrow:SetPoint("TOP", marker, "BOTTOM", 0, -2)
arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
arrow:SetRotation(math.pi) -- point down at the bobber

local pulse = marker:CreateAnimationGroup()
local fade = pulse:CreateAnimation("Alpha")
fade:SetFromAlpha(1); fade:SetToAlpha(0.45); fade:SetDuration(0.6)
pulse:SetLooping("BOUNCE")

local attachedTo

-- Size and colour come from settings.
function ns.Marker.Apply()
	if not ns.db then return end
	local size = ns.db.markerSize or 56
	marker:SetSize(size, size)
	arrow:SetSize(size * 0.55, size * 0.55)
	layoutBorder(math.max(2, math.floor(size * 0.07 + 0.5)))
	local c = ns.db.colours.marker
	for _, t in ipairs(border) do t:SetColorTexture(c.r, c.g, c.b, 1) end
	arrow:SetVertexColor(c.r, c.g, c.b)
end

-- Show the marker in the middle of the screen for a few seconds (settings preview).
local previewing
function ns.Marker.Preview()
	ns.Marker.Apply()
	previewing = true
	marker:ClearAllPoints()
	marker:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	marker:Show()
	pulse:Play()
	C_Timer.After(3, function()
		previewing = false
		marker:ClearAllPoints()
		attachedTo = nil
		if ns.state.fishing then ns.Marker.Refresh() else marker:Hide(); pulse:Stop() end
	end)
end

local function dbg(msg)
	if ns.db and ns.db.debug then ns.say("Debug marker: " .. msg) end
end

local function safeBool(v)
	if issecretvalue and issecretvalue(v) then return nil end
	return v
end

-- Find the nameplate frame for the soft-interact target, if the game lets us.
local function findPlate()
	if not C_NamePlate then return nil, "no nameplate API" end
	local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "softinteract")
	if ok and plate then
		if plate.IsForbidden and plate:IsForbidden() then return nil, "nameplate is protected" end
		return plate, "found via softinteract"
	end
	local ok2, plates = pcall(C_NamePlate.GetNamePlates)
	if ok2 and type(plates) == "table" then
		for _, p in ipairs(plates) do
			local token = p.namePlateUnitToken or (p.UnitFrame and p.UnitFrame.unit)
			if token then
				local ok3, same = pcall(UnitIsUnit, token, "softinteract")
				if ok3 and safeBool(same) then
					if p.IsForbidden and p:IsForbidden() then return nil, "nameplate is protected" end
					return p, "found via " .. token
				end
			end
		end
	end
	return nil, "no nameplate for the bobber"
end

local lastReason

-- Hiding the "Fishing Bobber" name on the nameplate (we keep the plate itself,
-- because the marker is pinned to it).
local hidden = {} -- fontstrings we've hidden -> true

local function restoreName()
	for fs in pairs(hidden) do pcall(fs.SetAlpha, fs, 1) end
	wipe(hidden)
end

-- Every piece of text on the bobber's nameplate, including nested frames.
-- (The name can be hidden from addons in Forever, so we don't match on it;
-- this plate only ever shows the bobber's name.)
local function collectText(frame, out, depth)
	if depth > 5 or not frame then return end
	local okR, regions = pcall(function() return { frame:GetRegions() } end)
	if okR then
		for _, r in ipairs(regions) do
			if r.GetObjectType and r:GetObjectType() == "FontString" then out[#out + 1] = r end
		end
	end
	local okC, children = pcall(function() return { frame:GetChildren() } end)
	if okC then
		for _, c in ipairs(children) do
			if c ~= marker then collectText(c, out, depth + 1) end
		end
	end
end

local function nameStrings(plate)
	local found = {}
	collectText(plate, found, 0)
	return found
end

local reported
local function hideName(plate)
	if not (ns.db and ns.db.hideBobberName) then restoreName() return end
	local list = nameStrings(plate)
	for _, fs in ipairs(list) do
		if pcall(fs.SetAlpha, fs, 0) then hidden[fs] = true end -- re-apply every time
	end
	if not reported then dbg("hiding " .. #list .. " text item(s) on the bobber nameplate"); reported = true end
end

local function attach()
	if previewing then return true end
	if not (ns.db and ns.state.fishing) then
		marker:Hide(); pulse:Stop(); attachedTo = nil; restoreName()
		return true
	end
	local plate, reason = findPlate()
	if reason ~= lastReason then dbg(reason); lastReason = reason end
	if not plate then marker:Hide(); attachedTo = nil; restoreName(); return false end
	if attachedTo and attachedTo ~= plate then restoreName() end -- plates get reused
	hideName(plate)
	if not ns.db.bobberMarker then
		marker:Hide(); pulse:Stop(); attachedTo = plate
		return true
	end
	if attachedTo ~= plate then
		marker:ClearAllPoints()
		local ok = pcall(marker.SetPoint, marker, "BOTTOM", plate, "TOP", 0, 4)
		if not ok then dbg("couldn't attach to the nameplate"); marker:Hide(); return false end
		attachedTo = plate
	end
	marker:Show()
	if not pulse:IsPlaying() then pulse:Play() end
	return true
end

-- Keep trying for a few seconds after a cast: the bobber's nameplate
-- appears a moment after the bobber lands.
local poller = CreateFrame("Frame")
poller:Hide()
local elapsedTotal, tick = 0, 0
poller:SetScript("OnUpdate", function(self, e)
	elapsedTotal, tick = elapsedTotal + e, tick + e
	if tick < 0.1 then return end
	tick = 0
	if attach() and attachedTo then self:Hide() end
	if elapsedTotal > 4 then self:Hide() end
end)

local reHide
local function startReHide()
	if reHide then return end
	reHide = C_Timer.NewTicker(0.25, function()
		if not (ns.state.fishing and ns.db and ns.db.hideBobberName) then
			reHide:Cancel(); reHide = nil
			return
		end
		local plate = findPlate()
		if plate then hideName(plate) end
	end)
end

function ns.Marker.Refresh()
	ns.Marker.Apply()
	if not (ns.db and ns.db.hideBobberName) then restoreName() end
	if ns.state.fishing and ns.db and ns.db.hideBobberName then reported = nil; startReHide() end
	if ns.state.fishing and ns.db and (ns.db.bobberMarker or ns.db.hideBobberName) then
		lastReason = nil
		elapsedTotal, tick = 0, 0
		poller:Show()
	end
	attach()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED")
ev:RegisterEvent("NAME_PLATE_UNIT_ADDED")
ev:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
ev:SetScript("OnEvent", function() attach() end)
