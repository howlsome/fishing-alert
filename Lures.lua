-- Fishing Alert: find fishing lures in your bags by reading item tooltips,
-- so it works with Forever's own item IDs without a hard-coded list.
local ADDON, ns = ...
ns.Lures = {}

local cache = {} -- itemID -> bonus number, or false if not a lure

local function lureBonus(bag, slot, itemID)
	if cache[itemID] ~= nil then return cache[itemID] end
	local data = C_TooltipInfo and C_TooltipInfo.GetBagItem(bag, slot)
	if not data or not data.lines then return false end
	local bonus = false
	for _, line in ipairs(data.lines) do
		local text = line.leftText
		if type(text) == "string" then
			local lower = text:lower()
			if lower:find("^use:") and lower:find("fishing") then
				local n = lower:match("by (%d+)") or lower:match("%+(%d+)")
				if n then bonus = tonumber(n) break end
			end
		end
	end
	cache[itemID] = bonus
	return bonus
end

-- Returns lures sorted best first: { itemID, name, icon, count, bonus }
function ns.Lures.Scan()
	local found, byID = {}, {}
	for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4) do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID then
				local bonus = lureBonus(bag, slot, info.itemID)
				if bonus then
					local entry = byID[info.itemID]
					if entry then
						entry.count = entry.count + (info.stackCount or 1)
					else
						local name = info.hyperlink and info.hyperlink:match("%[(.-)%]") or ("item " .. info.itemID)
						entry = { itemID = info.itemID, name = name, icon = info.iconFileID,
							count = info.stackCount or 1, bonus = bonus }
						byID[info.itemID] = entry
						found[#found + 1] = entry
					end
				end
			end
		end
	end
	table.sort(found, function(a, b)
		if a.bonus ~= b.bonus then return a.bonus > b.bonus end
		return a.count > b.count
	end)
	return found
end

-- true/false, plus seconds remaining when a lure is on
function ns.Lures.Active()
	local has, expirationMs = GetWeaponEnchantInfo()
	return has and true or false, expirationMs and expirationMs / 1000 or 0
end

function ns.Lures.Macro(itemID)
	return "/use item:" .. itemID .. "\n/use 16"
end
