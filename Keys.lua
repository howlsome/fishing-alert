-- Fishing Alert: one key casts, the same key catches. Works with a keyboard
-- key (F or Space) and, if set, a gamepad button, both at once.
-- Out of the water: the key clicks a secure button that applies your best
-- lure (if none is on and auto-lure is enabled) or casts Fishing.
-- While the line is out: the key is rebound to the game's own
-- "Interact With Target" command, which reels in the soft-targeted bobber.
-- Shift + key (or the optional pad picker button) opens the lure picker.
local ADDON, ns = ...
ns.Keys = {}

local owner = CreateFrame("Frame", "FishingAlertBindingOwner")

local btn = CreateFrame("Button", "FishingAlertCastButton", UIParent, "SecureActionButtonTemplate")
btn:SetAttribute("type", "spell")
if GetCVarBool("ActionButtonUseKeyDown") then
	btn:RegisterForClicks("AnyDown")
else
	btn:RegisterForClicks("AnyUp")
end
btn:SetScript("PostClick", function(self)
	if self.lure then
		ns.say("Applying " .. self.lure.name .. " (+" .. self.lure.bonus .. "). Press again to cast once it's on.")
	end
end)

-- Plain (insecure) button for the picker combo.
local pickerToggle = CreateFrame("Button", "FishingAlertPickerToggle", UIParent)
pickerToggle:RegisterForClicks("AnyDown")
pickerToggle:SetScript("OnClick", function() ns.Picker.Toggle() end)

function ns.Keys.PoleEquipped()
	local id = GetInventoryItemID("player", 16)
	if not id then return false end
	local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(id)
	return classID == Enum.ItemClass.Weapon and subclassID == Enum.ItemWeaponSubclass.Fishingpole
end

-- The keys/buttons that fish: keyboard key plus the gamepad button if set.
function ns.Keys.FishKeys()
	local keys = { ns.db.key }
	if ns.GamepadEnabled() and ns.db.padButton and ns.db.padButton ~= "" then
		keys[#keys + 1] = ns.db.padButton
	end
	return keys
end

local active = false
local expiryTimer

local function setCastMode()
	local lure
	local hasLure, remaining = ns.Lures.Active()
	if ns.db.autoLure and not hasLure then
		lure = ns.Lures.Scan()[1]
	end
	if lure then
		btn:SetAttribute("type", "macro")
		btn:SetAttribute("macrotext", ns.Lures.Macro(lure.itemID))
	else
		btn:SetAttribute("type", "spell")
		btn:SetAttribute("spell", C_Spell.GetSpellName(ns.FISHING_SPELL) or ns.FISHING_SPELL)
	end
	btn.lure = lure
	-- re-check when the current lure wears off
	if expiryTimer then expiryTimer:Cancel(); expiryTimer = nil end
	if hasLure and remaining > 0 then
		expiryTimer = C_Timer.NewTimer(remaining + 0.5, function() ns.Keys.Update() end)
	end
end

local function bindClick(key, button)
	SetOverrideBindingClick(owner, true, key, button, "LeftButton")
end

function ns.Keys.Update()
	if not ns.db then return end
	if InCombatLockdown() then return end -- retried on PLAYER_REGEN_ENABLED
	ClearOverrideBindings(owner)
	local pole = ns.Keys.PoleEquipped()
	ns.Icon.Update(pole)
	if not pole then
		if active then ns.say("Pole unequipped: your keys are back to normal.") end
		active = false
		if ns.Picker.IsShown() then ns.Picker.Hide() end
		return
	end

	local keys = ns.Keys.FishKeys()
	for _, key in ipairs(keys) do
		if ns.Picker.IsShown() then
			bindClick(key, "FishingAlertPickerApply")
		elseif ns.state.fishing then
			SetOverrideBinding(owner, true, key, "INTERACTTARGET")
		else
			bindClick(key, "FishingAlertCastButton")
		end
		bindClick("SHIFT-" .. key, "FishingAlertPickerToggle")
	end
	if ns.GamepadEnabled() and ns.db.padPicker and ns.db.padPicker ~= "" then
		bindClick(ns.db.padPicker, "FishingAlertPickerToggle")
	end
	if ns.Picker.IsShown() then
		for _, k in ipairs({ "LEFT", "PADDLEFT" }) do bindClick(k, "FishingAlertPickerPrev") end
		for _, k in ipairs({ "RIGHT", "PADDRIGHT" }) do bindClick(k, "FishingAlertPickerNext") end
		bindClick("PAD2", "FishingAlertPickerClose")
	else
		setCastMode()
	end

	if not active then
		local shown = table.concat(keys, " / ")
		ns.say("Pole equipped: " .. shown .. " casts and reels in; Shift+" .. keys[1] .. " picks a lure.")
	end
	active = true
end
