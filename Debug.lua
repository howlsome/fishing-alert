-- Fishing Alert: debug logger (/fa debug). Records game events, and any
-- sound an addon can see, from casting until a few seconds after the line ends.
local ADDON, ns = ...
ns.Debug = {}

local function safe(v)
	if issecretvalue and issecretvalue(v) then return "<secret>" end
	local ok, s = pcall(tostring, v)
	return ok and s or "<?>"
end

local NOISE = {
	COMBAT_LOG_EVENT_UNFILTERED = true, CURSOR_CHANGED = true, MODIFIER_STATE_CHANGED = true,
	UPDATE_MOUSEOVER_UNIT = true, UNIT_POWER_FREQUENT = true, UNIT_POWER_UPDATE = true,
	ACTIONBAR_UPDATE_COOLDOWN = true, ACTIONBAR_UPDATE_USABLE = true, ACTIONBAR_UPDATE_STATE = true,
	SPELL_UPDATE_COOLDOWN = true, SPELL_UPDATE_USABLE = true, BAG_UPDATE_COOLDOWN = true,
	WORLD_CURSOR_TOOLTIP_UPDATE = true, GLOBAL_MOUSE_DOWN = true, GLOBAL_MOUSE_UP = true,
	UNIT_HEALTH = true, UNIT_MAXHEALTH = true, UNIT_THREAT_LIST_UPDATE = true,
	UNIT_FLAGS = true, UNIT_TARGET = true, UPDATE_UI_WIDGET = true,
	SPELL_ACTIVATION_OVERLAY_HIDE = true, BN_FRIEND_INFO_CHANGED = true,
}
local function isNoise(e)
	return NOISE[e] or e:find("^CHAT_MSG_") or e:find("^NAME_PLATE_") or e:find("^GUILD")
		or e:find("^CLUB_") or e:find("^DISCORD_")
end

local session
local listener = CreateFrame("Frame")

local function stopNow()
	if not session then return end
	listener:UnregisterAllEvents()
	session = nil
end
ns.Debug.Stop = stopNow

local function log(kind, text)
	if not session then return end
	if not (ns.db and ns.db.debug) then stopNow() return end -- debug switched off mid-cast
	local line = string.format("+%.2fs %s %s", GetTime() - session.start, kind, text)
	session.lines[#session.lines + 1] = line
	if kind == "SOUND" or kind:find("SOUND") then ns.say("|cffffff00" .. line .. "|r") end
end

listener:SetScript("OnEvent", function(_, event, ...)
	if not session then return end
	if not (ns.db and ns.db.debug) then stopNow() return end
	if isNoise(event) then
		session.noise[event] = (session.noise[event] or 0) + 1
		return
	end
	local a = {}
	for i = 1, math.min(select("#", ...), 4) do a[i] = safe((select(i, ...))) end
	log(event, table.concat(a, ", "))
end)

-- Sounds played by Lua code (UI sounds, other addons). The game engine's own
-- world sounds, like the bobber splash, may never pass through these.
local function soundHook(name)
	return function(...)
		if not session or not (ns.db and ns.db.debug) then return end
		local a = {}
		for i = 1, math.min(select("#", ...), 3) do a[i] = safe((select(i, ...))) end
		log("SOUND", name .. "(" .. table.concat(a, ", ") .. ")")
	end
end
for _, fn in ipairs({ "PlaySound", "PlaySoundFile", "PlayMusic", "PlayVocalErrorSoundID" }) do
	if _G[fn] then hooksecurefunc(fn, soundHook(fn)) end
end
if C_Sound and C_Sound.PlayItemSound then
	hooksecurefunc(C_Sound, "PlayItemSound", soundHook("C_Sound.PlayItemSound"))
end

local function finish(id)
	if not session or session.id ~= id then return end -- stale timer from an older cast
	if not (ns.db and ns.db.debug) then stopNow() return end
	listener:UnregisterAllEvents()
	local n = {}
	for e, c in pairs(session.noise) do n[#n + 1] = e .. "x" .. c end
	session.noiseSummary = table.concat(n, ", ")
	ns.db.sessions = ns.db.sessions or {}
	table.insert(ns.db.sessions, session)
	while #ns.db.sessions > 10 do table.remove(ns.db.sessions, 1) end
	ns.say("Debug: session saved (" .. #session.lines .. " lines).")
	session = nil
end

local nextID = 0
local ctl = CreateFrame("Frame")
ctl:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
ctl:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
ctl:SetScript("OnEvent", function(_, event, ...)
	if not (ns.db and ns.db.debug) then return end
	local _, _, spellID = ...
	if not ns.IsFishingSpell(spellID) then return end
	if event == "UNIT_SPELLCAST_CHANNEL_START" then
		if session then finish(session.id) end
		nextID = nextID + 1
		session = { id = nextID, start = GetTime(), spellID = spellID, zone = GetZoneText(),
			date = date("%Y-%m-%d %H:%M:%S"), version = ns.version, lines = {}, noise = {} }
		pcall(listener.RegisterAllEvents, listener)
		log("CTL", "channel started")
	else
		log("CTL", "channel stopped")
		local id = session and session.id
		C_Timer.After(3, function() finish(id) end)
	end
end)

function ns.Debug.PrintLast()
	local s = ns.db.sessions and ns.db.sessions[#ns.db.sessions]
	if not s then ns.say("No debug sessions yet. Turn on /fa debug and fish.") return end
	ns.say("Last session: " .. s.date .. " in " .. s.zone)
	for _, l in ipairs(s.lines) do print("  " .. l) end
end
