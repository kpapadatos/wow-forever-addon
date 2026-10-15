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
-- Error capture. Every event handler runs through ns.Safe: errors never pop
-- up in the player's face, they are stored in SimulacrumDB.errors (with a
-- stack) for later inspection and announced once in chat.
-- ---------------------------------------------------------------------------
local pendingErrors, warned = {}, false

-- Forever (Midnight API) hides some values from addons during encounters
function ns.IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) or false
end

local function recordError(tag, err)
	local e = { t = date("%Y-%m-%d %H:%M:%S"), tag = tag, err = tostring(err), stack = debugstack and debugstack(3, 12, 0) or "" }
	local store = ns.db and ns.db.errors or pendingErrors
	table.insert(store, e)
	if #store > 60 then table.remove(store, 1) end
	if not warned then
		warned = true
		DEFAULT_CHAT_FRAME:AddMessage(("|cffe6c35cSimulacrum|r: |cffff6060an internal error was caught and logged (%s). Play on - it is saved for debugging.|r"):format(tag))
	end
end
ns.RecordError = recordError

function ns.Safe(tag, fn)
	return function(...)
		local n, args = select("#", ...), { ... }
		local ok, err = xpcall(function() return fn(unpack(args, 1, n)) end, function(e) return e end)
		if not ok then recordError(tag, err) end
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
	for _, fn in ipairs(listeners[event] or {}) do
		local ok, err = pcall(fn, ...)
		if not ok then recordError("Fire:" .. event, err) end
	end
end

function ns:Print(msg, ...)
	DEFAULT_CHAT_FRAME:AddMessage("|cffe6c35cSimulacrum|r: " .. string.format(msg, ...))
end

-- ---------------------------------------------------------------------------
-- Names. Forever characters have "First Surname" (surname optional); the
-- APIs return the surname where other clients return a realm, and only the
-- full name is unique. Everything in the addon is keyed by ns.NormName().
-- ---------------------------------------------------------------------------
local function realmVariants()
	local r = GetRealmName and GetRealmName() or ""
	return r, r:gsub("[%s%-]", ""), GetNormalizedRealmName and GetNormalizedRealmName() or ""
end

function ns.NormName(name)
	if not name or name == "" then return name end
	local head, tail = name:match("^([^%-]+)%-(.+)$")
	if not head then return name end
	if head:find(" ", 1, true) then return head end -- "First Surname-Realm"
	local r1, r2, r3 = realmVariants()
	if tail == r1 or tail == r2 or tail == r3 then return head end -- "First-Realm"
	return head .. " " .. tail -- "First-Surname": surname reported in the realm slot
end

-- full name of a unit ("First Surname" or just "First")
function ns.UnitFullName(unit)
	local first, second = UnitName(unit)
	if not first then return nil end
	if second and second ~= "" then
		local r1, r2, r3 = realmVariants()
		if second ~= r1 and second ~= r2 and second ~= r3 then return first .. " " .. second end
	end
	return first
end

function ns:PlayerName()
	if not self.playerName then self.playerName = ns.UnitFullName("player") end
	return self.playerName
end

-- first name only, for friendly display
function ns.FirstName(name)
	return name and (name:match("^(%S+)") or name)
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
	if ns.IsSecret(prefix) or ns.IsSecret(msg) or ns.IsSecret(sender) then return end
	if prefix ~= ns.COMM_PREFIX then return end
	sender = ns.NormName(sender)
	if sender == ns:PlayerName() then return end
	if msg:sub(2, 2) == "~" then
		-- claims protocol (Claims.lua / master extension): "X~field~field..."
		ns:Fire("COMM", msg:sub(1, 1), { strsplit("~", msg:sub(3)) }, channel, sender)
		return
	end
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
f:SetScript("OnEvent", ns.Safe("Core", function(_, event, ...)
	if event == "ADDON_LOADED" and ... == ADDON then
		SimulacrumDB = SimulacrumDB or {}
		applyDefaults(SimulacrumDB, DEFAULTS)
		ns.db = SimulacrumDB
		ns.db.errors = ns.db.errors or {}
		for _, e in ipairs(pendingErrors) do table.insert(ns.db.errors, e) end
		wipe(pendingErrors)
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
end))

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
