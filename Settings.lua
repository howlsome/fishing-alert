-- Fishing Alert: settings window (/fa, or Options > AddOns > Fishing Alert)
local ADDON, ns = ...
ns.Settings = {}

-- The page that sits in Options > AddOns > Fishing Alert. The game parents
-- and sizes it; the scroll area and everything in it hang off this frame.
local win = CreateFrame("Frame", "FishingAlertOptions")
win:Hide()

local winTitle = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
winTitle:SetPoint("TOPLEFT", 16, -16)
winTitle:SetText("Fishing Alert")

local scroll = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 0, -44)
scroll:SetPoint("BOTTOMRIGHT", -28, 8)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(620, 1000)
scroll:SetScrollChild(content)
local category

local parent = content
local y = -16
local function heading(text)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	fs:SetPoint("TOPLEFT", 16, y)
	fs:SetText(text)
	y = y - 30
	return fs
end

local function note(text)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	fs:SetPoint("TOPLEFT", 20, y)
	fs:SetWidth(560)
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	y = y - 22
	return fs
end

local function checkbox(label, get, set)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetPoint("TOPLEFT", 16, y)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
	fs:SetText(label)
	cb:SetScript("OnClick", function(self) set(self:GetChecked()) end)
	cb.refresh = function() cb:SetChecked(get()) end
	y = y - 30
	return cb
end

local function button(label, x, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(140, 24)
	b:SetPoint("TOPLEFT", x, y)
	b:SetText(label)
	b:SetScript("OnClick", onClick)
	return b
end

local function swatch(label, key, onPreview, onChange)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(22, 22)
	b:SetPoint("TOPLEFT", 22, y)
	local border = b:CreateTexture(nil, "BACKGROUND")
	border:SetAllPoints()
	border:SetColorTexture(1, 1, 1, 1)
	local fill = b:CreateTexture(nil, "ARTWORK")
	fill:SetPoint("TOPLEFT", 2, -2)
	fill:SetPoint("BOTTOMRIGHT", -2, 2)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	fs:SetPoint("LEFT", b, "RIGHT", 8, 0)
	fs:SetText(label)
	local preview = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	preview:SetSize(80, 22)
	preview:SetPoint("LEFT", b, "RIGHT", 240, 0)
	preview:SetText("Preview")
	preview:SetScript("OnClick", onPreview or function() ns.Flash(3, ns.db.colours[key]) end)

	b.refresh = function()
		local c = ns.db.colours[key]
		fill:SetColorTexture(c.r, c.g, c.b, 1)
	end
	b:SetScript("OnClick", function()
		local c = ns.db.colours[key]
		ColorPickerFrame:SetupColorPickerAndShow({
			r = c.r, g = c.g, b = c.b,
			swatchFunc = function()
				local r, g, bl = ColorPickerFrame:GetColorRGB()
				c.r, c.g, c.b = r, g, bl
				b.refresh()
				if onChange then onChange() end
			end,
			cancelFunc = function(prev)
				c.r, c.g, c.b = prev.r, prev.g, prev.b
				b.refresh()
				if onChange then onChange() end
			end,
		})
	end)
	y = y - 30
	return b
end

-- Horizontal slider with a label and value readout.
local function slider(label, minV, maxV, step, get, set)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	fs:SetPoint("TOPLEFT", 22, y - 2)
	fs:SetText(label)
	local s = CreateFrame("Slider", nil, parent)
	s:SetOrientation("HORIZONTAL")
	s:SetSize(220, 16)
	s:SetPoint("TOPLEFT", 200, y)
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	s:SetObeyStepOnDrag(true)
	local track = s:CreateTexture(nil, "BACKGROUND")
	track:SetPoint("LEFT"); track:SetPoint("RIGHT")
	track:SetHeight(6)
	track:SetColorTexture(0.25, 0.25, 0.25, 1)
	s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	local val = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	val:SetPoint("LEFT", s, "RIGHT", 10, 0)
	local updating
	s:SetScript("OnValueChanged", function(_, v)
		v = math.floor(v / step + 0.5) * step
		val:SetText(v)
		if not updating then set(v) end
	end)
	s.refresh = function()
		updating = true
		s:SetValue(get())
		val:SetText(get())
		updating = false
	end
	y = y - 32
	return s
end

local widgets = {}

-- "Press a button" capture box: listens for one gamepad button (or key).
-- Only gamepad buttons (PAD...) are accepted; Escape cancels.
local listening
local function capture(label, field)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	fs:SetPoint("TOPLEFT", 22, y - 4)
	fs:SetText(label)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(160, 24)
	b:SetPoint("TOPLEFT", 260, y)
	local clear = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	clear:SetSize(70, 24)
	clear:SetPoint("LEFT", b, "RIGHT", 6, 0)
	clear:SetText("Clear")

	local function stop()
		listening = nil
		b:EnableKeyboard(false)
		if b.EnableGamePadButton then b:EnableGamePadButton(false) end
		b.refresh()
	end
	local function take(key)
		if key == "ESCAPE" then stop() return end
		if type(key) ~= "string" or not key:find("^PAD") then return end
		ns.db[field] = key
		stop()
		ns.Keys.Update()
	end
	b.refresh = function()
		local v = ns.db[field]
		b:SetText(listening == b and "Press a pad button..." or ((v and v ~= "") and v or "Not set"))
	end
	b:SetScript("OnClick", function()
		if listening then return end
		listening = b
		b:EnableKeyboard(true)
		if b.SetPropagateKeyboardInput then b:SetPropagateKeyboardInput(false) end
		if b.EnableGamePadButton then b:EnableGamePadButton(true) end
		b.refresh()
	end)
	b:SetScript("OnKeyDown", function(_, key) take(key) end)
	b:SetScript("OnGamePadButtonDown", function(_, button) take(button) end)
	b:SetScript("OnHide", function() if listening == b then stop() end end)
	clear:SetScript("OnClick", function() ns.db[field] = nil; b.refresh(); ns.Keys.Update() end)
	y = y - 32
	return b
end

local baseHeight, padHeight, padGroup = 600, 0, nil

local function build()
	note("Visual cues and one-key fishing. Equip your fishing pole to activate the key.")
	y = y - 6

	heading("Fishing key")
	local f, space
	f = checkbox("F", function() return ns.db.key == "F" end, function()
		ns.db.key = "F"; ns.Keys.Update(); f.refresh(); space.refresh()
	end)
	space = checkbox("Space (you can't jump while your pole is equipped)",
		function() return ns.db.key == "SPACE" end, function()
		ns.db.key = "SPACE"; ns.Keys.Update(); f.refresh(); space.refresh()
	end)
	widgets[#widgets + 1] = f
	widgets[#widgets + 1] = space
	note("Shift + your fishing key opens the lure picker.")
	y = y - 6


	heading("Lures")
	widgets[#widgets + 1] = checkbox("Apply my best lure automatically when none is on",
		function() return ns.db.autoLure end, function(v) ns.db.autoLure = v; ns.Keys.Update() end)
	note("The fishing key applies the lure first; press it again to cast. Best bonus is used first.")
	y = y - 6

	heading("Bobber")
	widgets[#widgets + 1] = checkbox("Soft-target the bobber and show its name while my pole is equipped",
		function() return ns.db.bobberIcon end, function(v) ns.db.bobberIcon = v; ns.Keys.Update() end)
	note("Uses the game's own soft-target settings. Your originals come back when you unequip the pole.")
	widgets[#widgets + 1] = checkbox("Show a big pulsing marker above the bobber while my line is out",
		function() return ns.db.bobberMarker end, function(v) ns.db.bobberMarker = v; ns.Marker.Refresh() end)
	widgets[#widgets + 1] = checkbox("Hide the \"Fishing Bobber\" text above the bobber",
		function() return ns.db.hideBobberName end, function(v) ns.db.hideBobberName = v; ns.Marker.Refresh() end)
	widgets[#widgets + 1] = slider("Marker size", 24, 128, 4,
		function() return ns.db.markerSize end, function(v) ns.db.markerSize = v; ns.Marker.Apply() end)
	widgets[#widgets + 1] = swatch("Marker colour", "marker",
		function() ns.Marker.Preview() end, function() ns.Marker.Apply() end)
	widgets[#widgets + 1] = checkbox("Show Fishing Alert's own countdown bar (off if you already have a cast bar)",
		function() return ns.db.showBar end, function(v) ns.db.showBar = v; if not v then ns.Bar.Stop() end end)
	y = y - 6

	heading("Flash colours")
	widgets[#widgets + 1] = swatch("Fish got away", "escaped")
	widgets[#widgets + 1] = swatch("Line ran out", "ranout")
	widgets[#widgets + 1] = swatch("Missed the water", "missed")
	y = y - 6
	button("Preview all", 16, function() SlashCmdList.FISHINGALERT("test") end)
	y = y - 40

	heading("Troubleshooting")
	widgets[#widgets + 1] = checkbox("Debug logging while fishing",
		function() return ns.db.debug end, function(v) ns.SetDebug(v) end)
	y = y - 6
	baseHeight = -y + 20

	-- Gamepad section: last on the page, shown only when gamepad support is on.
	padGroup = CreateFrame("Frame", nil, content)
	padGroup:SetPoint("TOPLEFT", 0, y)
	padGroup:SetSize(620, 10)
	parent, y = padGroup, 0
	heading("Gamepad")
	widgets[#widgets + 1] = capture("Fishing button (cast and reel in)", "padButton")
	widgets[#widgets + 1] = capture("Lure picker button (optional)", "padPicker")
	note("In the picker: D-pad left/right to choose, your fishing button to apply, B to close.")
	note("Shift + fishing button also opens it if a pad button is set to act as Shift in Gamepad options.")
	padHeight = -y + 10
	padGroup:SetHeight(padHeight)
	parent = content
end

local function refreshAll()
	for _, w in ipairs(widgets) do w.refresh() end
	local pad = ns.GamepadEnabled()
	if padGroup then padGroup:SetShown(pad) end
	content:SetHeight(baseHeight + (pad and padHeight or 0))
end
win:SetScript("OnShow", refreshAll)
function ns.Settings.Refresh() if win:IsShown() then refreshAll() end end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(_, event)
	if event ~= "PLAYER_LOGIN" or category then return end
	build()
	category = Settings.RegisterCanvasLayoutCategory(win, "Fishing Alert")
	Settings.RegisterAddOnCategory(category)
end)

function ns.Settings.Open()
	if not category then return end
	local ok, err = pcall(Settings.OpenToCategory, category:GetID())
	if not ok then ns.say("Couldn't open settings: " .. tostring(err)) return end
	refreshAll()
end
