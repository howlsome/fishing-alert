-- Fishing Alert: core state, events and slash commands
local ADDON, ns = ...

ns.FISHING_SPELL = 7620
ns.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "dev"
ns.defaults = {
	key = "F",
	autoLure = true,
	bobberIcon = true,
	bobberMarker = true,
	markerSize = 56,
	hideBobberName = false,
	showBar = false, -- most players already have a cast bar
	debug = false,
	colours = {
		escaped = { r = 1, g = 0.1, b = 0.1 },  -- fish got away
		ranout  = { r = 1, g = 0.8, b = 0 },    -- line ran out, nothing caught
		missed  = { r = 1, g = 0.5, b = 0 },    -- cast missed fishable water
		marker  = { r = 1, g = 0.82, b = 0 },   -- bobber marker ring and arrow (gold)
		test    = { r = 0, g = 0, b = 1 },      -- BigWigs default blue
	},
}

local PREFIX = "|cff33ccffFishingAlert|r "
function ns.say(...) print(PREFIX .. string.join(" ", ...)) end

function ns.SetDebug(on)
	ns.db.debug = on and true or false
	if not ns.db.debug and ns.Debug and ns.Debug.Stop then ns.Debug.Stop() end
	ns.say("Debug logging " .. (ns.db.debug and "ON" or "OFF") .. ".")
end

-- Gamepad in use = the game's gamepad option is on AND a controller is
-- connected. (Forever has the option on by default, even with no pad.)
function ns.GamepadConnected()
	if not (C_GamePad and C_GamePad.GetAllDeviceIDs) then return nil end -- unknown
	local ok, ids = pcall(C_GamePad.GetAllDeviceIDs)
	return ok and type(ids) == "table" and #ids > 0
end

function ns.GamepadEnabled()
	local v = C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("GamePadEnable")
	if v == nil then v = GetCVar("GamePadEnable") end
	if v ~= "1" then return false end
	local connected = ns.GamepadConnected()
	if connected == nil then return true end -- can't tell; trust the option
	return connected
end

ns.state = { fishing = false, castStart = 0, token = 0, looted = false, escaped = false }

function ns.IsFishingSpell(spellID)
	if not spellID then return false end
	if spellID == ns.FISHING_SPELL then return true end
	local name = C_Spell.GetSpellName(spellID)
	return name ~= nil and name == C_Spell.GetSpellName(ns.FISHING_SPELL)
end

local function copyDefaults(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = type(dst[k]) == "table" and dst[k] or {}
			copyDefaults(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

local function matches(msg, global, fallback)
	if type(msg) ~= "string" then return false end
	if global and msg == global then return true end
	return msg:find(fallback, 1, true) ~= nil
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("LOOT_READY")
f:RegisterEvent("UI_INFO_MESSAGE")
f:RegisterEvent("UI_ERROR_MESSAGE")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("CVAR_UPDATE")
f:RegisterEvent("GAME_PAD_CONNECTED")
f:RegisterEvent("GAME_PAD_DISCONNECTED")
f:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")

f:SetScript("OnEvent", function(_, event, ...)
	local s = ns.state
	if event == "ADDON_LOADED" then
		if ... == ADDON then
			FishingAlertDB = FishingAlertDB or {}
			copyDefaults(FishingAlertDB, ns.defaults)
			ns.db = FishingAlertDB
			-- schema 1: drop debug logs saved by pre-release test builds
			if (ns.db.schema or 0) < 1 then
				ns.db.sessions = nil
				ns.db.schema = 1
			end
			-- only gamepad buttons belong in the pad slots (0.3.0 could save keyboard keys)
			for _, field in ipairs({ "padButton", "padPicker" }) do
				local v = ns.db[field]
				if v and not (type(v) == "string" and v:find("^PAD")) then ns.db[field] = nil end
			end
		end
	elseif event == "PLAYER_LOGIN" then
		ns.Keys.Update()
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		if ... == INVSLOT_MAINHAND or ... == 16 then ns.Keys.Update() end
	elseif event == "PLAYER_REGEN_ENABLED" or event == "BAG_UPDATE_DELAYED"
		or event == "UNIT_INVENTORY_CHANGED" then
		ns.Keys.Update()
	elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
		local _, _, spellID = ...
		if not ns.IsFishingSpell(spellID) then return end
		s.fishing, s.castStart, s.looted, s.escaped = true, GetTime(), false, false
		s.token = s.token + 1
		ns.Bar.Start()
		ns.Keys.Update()
		ns.Marker.Refresh()
	elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		local _, _, spellID = ...
		if not ns.IsFishingSpell(spellID) or not s.fishing then return end
		s.fishing = false
		s.lastStop = GetTime()
		local duration, token = GetTime() - s.castStart, s.token
		ns.Bar.Stop()
		ns.Keys.Update()
		ns.Marker.Refresh()
		-- Wait a moment so loot / escape messages can arrive first.
		C_Timer.After(1, function()
			if token ~= s.token or s.looted or s.escaped then return end
			if duration >= 28 then
				ns.Flash(3, ns.db.colours.ranout)
				ns.say("Your line ran out without a bite.")
			end
		end)
	elseif event == "GAME_PAD_CONNECTED" or event == "GAME_PAD_DISCONNECTED" then
		ns.Keys.Update()
		if ns.Settings.Refresh then ns.Settings.Refresh() end
	elseif event == "CVAR_UPDATE" then
		local name = ...
		if type(name) == "string" and name:lower() == "gamepadenable" then ns.Keys.Update() end
	elseif event == "LOOT_READY" then
		if s.fishing or (s.lastStop and GetTime() - s.lastStop < 2) then s.looted = true end
	elseif event == "UI_INFO_MESSAGE" then
		local _, msg = ...
		if matches(msg, ERR_FISH_ESCAPED, "fish got away") then
			s.escaped = true
			ns.Flash(3, ns.db.colours.escaped)
		end
	elseif event == "UI_ERROR_MESSAGE" then
		local _, msg = ...
		if matches(msg, SPELL_FAILED_NOT_FISHABLE, "fishable water") or matches(msg, nil, "too shallow") then
			ns.Flash(2, ns.db.colours.missed)
		end
	end
end)

SLASH_FISHINGALERT1 = "/fa"
SLASH_FISHINGALERT2 = "/fishingalert"
SlashCmdList.FISHINGALERT = function(msg)
	local cmd, arg = (msg or ""):lower():match("^(%S*)%s*(.-)$")
	if cmd == "key" then
		if arg == "f" or arg == "space" then
			ns.db.key = arg:upper()
			ns.Keys.Update()
			ns.say("Fishing key set to " .. ns.db.key .. ".")
		else
			ns.say("Usage: /fa key f  or  /fa key space")
		end
	elseif cmd == "" or cmd == "options" or cmd == "config" then
		ns.Settings.Open()
	elseif cmd == "lures" then
		local list = ns.Lures.Scan()
		if #list == 0 then ns.say("No lures found in your bags.") end
		for _, l in ipairs(list) do ns.say(l.name .. " x" .. l.count .. " (+" .. l.bonus .. ")") end
		local has = ns.Lures.Active()
		ns.say("Lure on your pole right now: " .. (has and "yes" or "no"))
	elseif cmd == "test" then
		local c = ns.db.colours
		local order = { { "test", "BigWigs blue" }, { "escaped", "fish got away" },
			{ "ranout", "line ran out" }, { "missed", "missed the water" } }
		for i, o in ipairs(order) do
			C_Timer.After((i - 1) * 2, function()
				ns.say("Test flash: " .. o[2])
				ns.Flash(3, c[o[1]])
			end)
		end
	elseif cmd == "flash" then
		ns.Flash(3, ns.db.colours.test)
	elseif cmd == "debug" then
		ns.SetDebug(not ns.db.debug)
	elseif cmd == "log" then
		ns.Debug.PrintLast()
	elseif cmd == "clear" then
		ns.db.sessions = {}
		ns.say("Debug log cleared.")
	elseif cmd == "status" then
		ns.say("Key: " .. ns.db.key .. ", pole equipped: " .. tostring(ns.Keys.PoleEquipped())
			.. ", debug: " .. tostring(ns.db.debug))
		local api = C_GamePad and C_GamePad.IsEnabled and select(2, pcall(C_GamePad.IsEnabled))
		ns.say("Gamepad: GamePadEnable=" .. tostring(C_CVar.GetCVar("GamePadEnable"))
			.. ", C_GamePad.IsEnabled=" .. tostring(api) .. ", controller connected="
			.. tostring(ns.GamepadConnected()) .. ", used: " .. tostring(ns.GamepadEnabled()))
		ns.say("Bobber icon settings: " .. ns.Icon.Report())
	else
		ns.say("/fa - open settings")
		ns.say("/fa lures - list lures found in your bags")
		ns.say("/fa key f|space - choose your fishing key")
		ns.say("/fa test - preview the alert flashes")
		ns.say("/fa status - show current settings")
		ns.say("/fa debug - toggle event and sound logging while fishing")
		ns.say("/fa log, /fa clear - show or clear the debug log")
	end
end
