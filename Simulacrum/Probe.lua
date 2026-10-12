local _, ns = ...

-- ===========================================================================
-- TEMPORARY probe: logs what the game APIs actually return into
-- SimulacrumDB.probe so it can be inspected from the SavedVariables file.
-- /simprobe toggles it, /simprobe clear wipes the log.
-- ===========================================================================
local MAX = 1500
local P = {}
ns.Probe = P

local function ser(v, depth)
	depth = depth or 0
	local t = type(v)
	if t == "table" then
		if depth > 2 then return "{...}" end
		local parts, n = {}, 0
		for k, x in pairs(v) do
			n = n + 1
			if n > 25 then parts[#parts + 1] = "..."; break end
			parts[#parts + 1] = tostring(k) .. "=" .. ser(x, depth + 1)
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	elseif t == "string" then
		return ("%q"):format(v)
	end
	return tostring(v)
end

local function pack(...) return { n = select("#", ...), ... } end
local function serArgs(a)
	local out = {}
	for i = 1, a.n do out[i] = ser(a[i]) end
	return table.concat(out, ", ")
end

function P:Log(tag, ...)
	if not ns.db or not ns.db.probeOn then return end
	local log = ns.db.probe
	log[#log + 1] = ("%s %s %s"):format(date("%H:%M:%S"), tag, serArgs(pack(...)))
	if #log > MAX then table.remove(log, 1) end
end

local function try(tag, fn, ...)
	local r = pack(pcall(fn, ...))
	if r[1] then
		table.remove(r, 1); r.n = r.n - 1
		P:Log(tag, unpack(r, 1, r.n))
	else
		P:Log(tag .. "!ERR", r[2])
	end
end

local function exists(path)
	local cur = _G
	for part in path:gmatch("[^%.]+") do
		if type(cur) ~= "table" then return "nil" end
		cur = cur[part]
	end
	return type(cur)
end

local API = {
	"GetServerTime", "GetInstanceInfo", "IsInInstance", "IsInGuild", "GetGuildInfo", "GetNumGuildMembers",
	"GetGuildRosterInfo", "GuildRosterSetOfficerNote", "GuildRosterSetPublicNote", "CanEditOfficerNote",
	"CanViewOfficerNote", "IsGuildLeader", "UnitIsInMyGuild", "C_GuildInfo.GuildRoster", "C_GuildInfo.CanEditOfficerNote",
	"C_GuildInfo.CanViewOfficerNote", "C_GuildInfo.SetNote", "C_GuildInfo.GetGuildRankOrder",
	"C_ChatInfo.SendAddonMessage", "C_ChatInfo.InChatMessagingLockdown", "C_ChatInfo.IsAddonMessagePrefixRegistered",
	"EJ_GetInstanceForMap", "EJ_GetEncounterInfoByIndex", "EJ_SelectInstance", "C_EncounterJournal",
	"C_Map.GetBestMapForUnit", "GetRealZoneText", "GetSubZoneText", "C_PartyInfo.InviteUnit", "GetNumGroupMembers",
	"string.dump", "debug.getinfo", "debugstack", "issecretvalue", "C_Seasons.GetActiveSeason", "ReloadUI",
	"GetAddOnMetadata", "C_AddOns.GetAddOnMetadata", "C_AddOns.GetAddOnInfo", "C_DateAndTime.GetServerTimeLocal",
}

local function snapshotAPIs()
	local present, missing = {}, {}
	for _, name in ipairs(API) do
		local t = exists(name)
		if t == "nil" then missing[#missing + 1] = name else present[#present + 1] = name .. ":" .. t end
	end
	P:Log("API.present", table.concat(present, " "))
	P:Log("API.missing", table.concat(missing, " "))
	P:Log("build", GetBuildInfo())
	P:Log("time", "server", GetServerTime and GetServerTime(), "local", time())
end

local function instanceSnapshot(tag)
	try(tag .. ".GetInstanceInfo", GetInstanceInfo)
	try(tag .. ".IsInInstance", IsInInstance)
	P:Log(tag .. ".zone", GetRealZoneText(), GetSubZoneText(), GetZoneText())
	if C_Map and C_Map.GetBestMapForUnit then try(tag .. ".bestMap", C_Map.GetBestMapForUnit, "player") end
end

local function groupSnapshot(tag)
	local n = GetNumGroupMembers()
	local parts = {}
	for i = 1, 4 do
		local u = "party" .. i
		if UnitExists(u) then
			local name, realm = UnitName(u)
			parts[#parts + 1] = ("%s-%s guild=%s inMyGuild=%s"):format(name or "?", realm or "", tostring(GetGuildInfo(u)),
				tostring(UnitIsInMyGuild and UnitIsInMyGuild(u)))
		end
	end
	P:Log(tag .. ".group", n, IsInGroup(), IsInRaid(), table.concat(parts, " | "))
end

local lastZones = {}
local function rosterSnapshot(full)
	if not IsInGuild() then return end
	local n = GetNumGuildMembers()
	local changed = {}
	for i = 1, n do
		local r = pack(GetGuildRosterInfo(i))
		local name, zone, online = r[1], r[6], r[9]
		if name then
			if full and i <= 5 then P:Log("roster.raw[" .. i .. "]", unpack(r, 1, r.n)) end
			local key = tostring(zone) .. "/" .. tostring(online)
			if lastZones[name] ~= key then
				lastZones[name] = key
				changed[#changed + 1] = ("%s=%s(%s)"):format(name, tostring(zone), online and "on" or "off")
			end
		end
	end
	if #changed > 0 then P:Log("roster.zones", n, table.concat(changed, "; ")) end
end

local f = CreateFrame("Frame")
local EVENTS = {
	"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ENCOUNTER_START", "ENCOUNTER_END", "BOSS_KILL",
	"GROUP_ROSTER_UPDATE", "GUILD_ROSTER_UPDATE", "CHAT_MSG_ADDON", "PLAYER_GUILD_UPDATE", "INSTANCE_LOCK_START",
	"UPDATE_INSTANCE_INFO", "LFG_COMPLETION_REWARD", "CHAT_MSG_SYSTEM", "SCENARIO_COMPLETED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN",
}
f:SetScript("OnEvent", function(_, event, ...)
	if not ns.db or not ns.db.probeOn then return end
	if event == "GUILD_ROSTER_UPDATE" then
		rosterSnapshot(false)
	elseif event == "CHAT_MSG_ADDON" then
		local prefix = ...
		if prefix == ns.COMM_PREFIX or prefix == "SIMPROBE" then P:Log("ev.CHAT_MSG_ADDON", ...) end
	else
		P:Log("ev." .. event, ...)
		if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then instanceSnapshot(event) end
		if event == "GROUP_ROSTER_UPDATE" then groupSnapshot("ev") end
		if event == "ENCOUNTER_START" or event == "ENCOUNTER_END" then
			P:Log("lockdown@" .. event, C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown())
			instanceSnapshot(event)
			groupSnapshot(event)
			if event == "ENCOUNTER_END" then
				for _, d in ipairs({ 1, 3, 6, 15 }) do
					C_Timer.After(d, function()
						P:Log("lockdown+" .. d .. "s", C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown())
					end)
				end
			end
		end
	end
end)
for _, e in ipairs(EVENTS) do pcall(f.RegisterEvent, f, e) end

-- self-test of the addon-message path: whisper to myself, and to GUILD/PARTY when possible
local function commTest()
	C_ChatInfo.RegisterAddonMessagePrefix("SIMPROBE")
	-- name formats: what does the client give us for "Lerius Hillmont"?
	P:Log("names.UnitName", UnitName("player"))
	P:Log("names.UnitFullName", UnitFullName and UnitFullName("player"))
	P:Log("names.GetUnitName", GetUnitName("player", false), GetUnitName("player", true))
	P:Log("names.realm", GetRealmName(), GetNormalizedRealmName and GetNormalizedRealmName())
	P:Log("names.ns", ns:PlayerName())
	-- one self-whisper with the full name (a wrong format prints "No player named ..." in chat)
	local target = GetUnitName("player", true)
	try("send.WHISPER.self[" .. tostring(target) .. "]", C_ChatInfo.SendAddonMessage, "SIMPROBE", "ping~" .. GetServerTime(), "WHISPER", target)
	if IsInGuild() then try("send.GUILD", C_ChatInfo.SendAddonMessage, "SIMPROBE", "ping~guild", "GUILD") end
	if IsInGroup() then try("send.PARTY", C_ChatInfo.SendAddonMessage, "SIMPROBE", "ping~party", "PARTY") end
end

local function guildSnapshot()
	if not IsInGuild() then P:Log("guild", "not in a guild"); return end
	P:Log("guild.info", GetGuildInfo("player"))
	P:Log("guild.perm", "IsGuildLeader", IsGuildLeader and IsGuildLeader(),
		"CanEditOfficerNote", (C_GuildInfo and C_GuildInfo.CanEditOfficerNote and C_GuildInfo.CanEditOfficerNote()) or (CanEditOfficerNote and CanEditOfficerNote()),
		"CanViewOfficerNote", (C_GuildInfo and C_GuildInfo.CanViewOfficerNote and C_GuildInfo.CanViewOfficerNote()) or (CanViewOfficerNote and CanViewOfficerNote()))
	rosterSnapshot(true)
end

function P:RunAll()
	snapshotAPIs()
	instanceSnapshot("now")
	groupSnapshot("now")
	guildSnapshot()
	commTest()
	if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
end

ns:On("LOGIN", function()
	ns.db.probe = ns.db.probe or {}
	if ns.db.probeOn == nil then ns.db.probeOn = true end
	if ns.db.probeOn then
		P:Log("---- session start ----", ns.version)
		C_Timer.After(3, function() P:RunAll() end)
	end
end)

SLASH_SIMPROBE1 = "/simprobe"
SlashCmdList.SIMPROBE = function(msg)
	if msg == "clear" then
		wipe(ns.db.probe); ns:Print("probe log cleared")
	elseif msg == "run" then
		P:RunAll(); ns:Print("probe snapshot taken (%d lines)", #ns.db.probe)
	else
		ns.db.probeOn = not ns.db.probeOn
		ns:Print("probe %s", ns.db.probeOn and "ON" or "OFF")
	end
end
