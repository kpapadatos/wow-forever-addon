local ADDON, ns = ...

ns.name = ADDON
ns.version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version") or "dev"
ns.media = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
ns.COMM_PREFIX = "SIMULACRUM"

_G.Simulacrum = ns -- handy for /dump and debugging

local DEFAULTS = {
	minimap = { hide = false, minimapPos = 200 },
	scale = 1,
	sounds = true,
	broadcast = true,
	lastTab = 1,
	interests = {},     -- [itemID] = { [player] = "need" | "greed" | "offspec" }
	goalProgress = {},  -- [goalID] = number
	dkpLog = {},        -- { {time, player, amount, reason, by} }
	dkpAdjust = {},     -- [player] = delta on top of seed data
	applications = {},  -- recruitment form submissions
	motd = nil,
}

local function applyDefaults(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then
			dst[k] = type(v) == "table" and CopyTable(v) or v
		elseif type(v) == "table" and type(dst[k]) == "table" then
			applyDefaults(dst[k], v)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Tiny callback bus so UI tabs can react to data changes
-- ---------------------------------------------------------------------------
local listeners = {}
function ns:On(event, fn)
	listeners[event] = listeners[event] or {}
	table.insert(listeners[event], fn)
end
function ns:Fire(event, ...)
	for _, fn in ipairs(listeners[event] or {}) do fn(...) end
end

function ns:Print(msg, ...)
	DEFAULT_CHAT_FRAME:AddMessage("|cffe6c35cSimulacrum|r: " .. string.format(msg, ...))
end

function ns:PlayerName()
	return (UnitName("player"))
end

function ns:Sound(kit)
	if self.db and self.db.sounds and kit then PlaySound(kit) end
end

-- ---------------------------------------------------------------------------
-- Loot interest (local + guild-synced via addon messages)
-- ---------------------------------------------------------------------------
local SendAddonMessage = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage

local function send(msg, channel, target)
	if not ns.db.broadcast or not IsInGuild() then return end
	SendAddonMessage(ns.COMM_PREFIX, msg, channel or "GUILD", target)
end

function ns:GetInterest(itemID)
	return self.db.interests[itemID]
end

function ns:SetInterest(itemID, player, kind, silent)
	local t = self.db.interests[itemID]
	if not t then
		t = {}
		self.db.interests[itemID] = t
	end
	t[player] = kind
	if not next(t) then self.db.interests[itemID] = nil end
	if not silent and player == self:PlayerName() then
		send(("I:%d:%s"):format(itemID, kind or "-"))
	end
	self:Fire("INTEREST_CHANGED", itemID)
end

function ns:MyInterest(itemID)
	local t = self.db.interests[itemID]
	return t and t[self:PlayerName()]
end

local function onAddonMessage(prefix, msg, channel, sender)
	if prefix ~= ns.COMM_PREFIX then return end
	sender = Ambiguate(sender, "none")
	if sender == ns:PlayerName() then return end
	local cmd, a, b = strsplit(":", msg)
	if cmd == "I" then
		local itemID = tonumber(a)
		if itemID then ns:SetInterest(itemID, sender, b ~= "-" and b or nil, true) end
	elseif cmd == "SYNC" then
		-- someone just logged in: whisper back everything we're interested in
		for itemID, who in pairs(ns.db.interests) do
			local mine = who[ns:PlayerName()]
			if mine then send(("I:%d:%s"):format(itemID, mine), "WHISPER", sender) end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
f:RegisterEvent("GUILD_ROSTER_UPDATE")
f:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" and ... == ADDON then
		SimulacrumDB = SimulacrumDB or {}
		applyDefaults(SimulacrumDB, DEFAULTS)
		ns.db = SimulacrumDB
		if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
			C_ChatInfo.RegisterAddonMessagePrefix(ns.COMM_PREFIX)
		end
		ns:Fire("DB_READY")
	elseif event == "PLAYER_LOGIN" then
		ns:Fire("LOGIN")
		C_Timer.After(5, function() send("SYNC") end)
		ns:Print("v%s loaded. Click the minimap crest or type |cffffffff/sim|r.", ns.version)
	elseif event == "CHAT_MSG_ADDON" then
		onAddonMessage(...)
	elseif event == "GET_ITEM_INFO_RECEIVED" then
		ns:Fire("ITEM_INFO", ...)
	elseif event == "GUILD_ROSTER_UPDATE" then
		ns:Fire("GUILD_ROSTER")
	end
end)

-- dev helpers (no spaces so they're easy to type from automation)
SLASH_SIMSHOT1 = "/simshot"
SlashCmdList.SIMSHOT = function() Screenshot() end
SLASH_SIMERR1 = "/simerr"
SlashCmdList.SIMERR = function() SetCVar("scriptErrors", "1"); ns:Print("Lua errors will now be shown.") end

SLASH_SIMULACRUM1 = "/sim"
SLASH_SIMULACRUM2 = "/simulacrum"
SlashCmdList.SIMULACRUM = function(msg)
	msg = strtrim(msg or ""):lower()
	if msg == "reset" then
		SimulacrumDB = nil
		ReloadUI()
	elseif msg == "minimap" then
		ns.db.minimap.hide = not ns.db.minimap.hide
		ns:Fire("MINIMAP_TOGGLED")
	else
		ns:Toggle()
	end
end
