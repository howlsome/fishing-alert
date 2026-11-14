-- Fishing Alert: show the game's own soft-target icon above the bobber.
-- While the pole is equipped we switch on soft targeting for objects and the
-- object icons; the player's original values are saved and put back afterwards
-- (also on the next login if the game closed while fishing).
local ADDON, ns = ...
ns.Icon = {}

local WANTED = {
	SoftTargetInteract = "3",         -- soft-target interactables always (keyboard + gamepad)
	SoftTargetIconGameObject = "1",   -- icon for objects you can't normally target, e.g. the bobber
	SoftTargetIconInteract = "1",     -- icon for the soft interact target
	SoftTargetLowPriorityIcons = "1", -- show the icon even when the object has its own effects
	SoftTargetNameplateInteract = "1",-- give the bobber a nameplate so our marker can follow it
}
ns.Icon.WANTED = WANTED

local function exists(name)
	return C_CVar and C_CVar.GetCVar(name) ~= nil
end

local function apply()
	local db = ns.db
	db.savedCVars = db.savedCVars or {}
	for name, value in pairs(WANTED) do
		if db.savedCVars[name] == nil then -- not yet applied (lets new settings join later)
			if exists(name) then
				db.savedCVars[name] = C_CVar.GetCVar(name)
				C_CVar.SetCVar(name, value)
				if db.debug then ns.say("Debug: " .. name .. " " .. db.savedCVars[name] .. " -> " .. value) end
			elseif db.debug then
				ns.say("Debug: setting " .. name .. " doesn't exist on this client")
			end
		end
	end
end

local function restore()
	local db = ns.db
	if not db.savedCVars then return end
	for name, value in pairs(db.savedCVars) do
		if exists(name) then C_CVar.SetCVar(name, value) end
	end
	db.savedCVars = nil
end

function ns.Icon.Update(poleEquipped)
	if not ns.db then return end
	if poleEquipped and ns.db.bobberIcon then apply() else restore() end
end

-- For /fa status: current values of the soft-target display settings.
function ns.Icon.Report()
	local names = { "SoftTargetInteract", "SoftTargetIconGameObject", "SoftTargetIconInteract",
		"SoftTargetLowPriorityIcons", "SoftTargetNameplateInteract", "SoftTargetNameplateSize" }
	local parts = {}
	for _, n in ipairs(names) do parts[#parts + 1] = n:gsub("^SoftTarget", "") .. "=" .. tostring(C_CVar.GetCVar(n)) end
	return table.concat(parts, ", ")
end
