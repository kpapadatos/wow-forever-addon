local _, ns = ...

-- ===========================================================================
-- Dungeon run recorder. Keeps a structured log of every dungeon visit in
-- SimulacrumDB.runs: instance info, the encounter journal's boss list (to find
-- final bosses), encounter start/end, boss kills, loot, group composition and
-- what the guild roster reports as our zone while inside. Used to validate the
-- claims design and as raw data for future features (guild run history).
-- ===========================================================================
local R = {}
ns.Runs = R
local C = ns.Claims

local MAX_RUNS = 60
local function now() return GetServerTime() end

-- Encounter journal: ordered boss list for the current instance; last one = final boss
function R:JournalBosses()
	if not (EJ_GetInstanceForMap and EJ_SelectInstance and EJ_GetEncounterInfoByIndex) then return nil, "no EJ API" end
	local uiMap = C_Map.GetBestMapForUnit("player")
	local jid = uiMap and EJ_GetInstanceForMap(uiMap)
	if not jid or jid == 0 then return nil, "no journal instance for map " .. tostring(uiMap) end
	local ok, err = pcall(EJ_SelectInstance, jid)
	if not ok then return nil, err end
	local list = {}
	for i = 1, 30 do
		local name, _, journalEncID, _, _, _, dungeonEncID = EJ_GetEncounterInfoByIndex(i, jid)
		if not name then break end
		list[#list + 1] = { name = name, journal = journalEncID, encounter = dungeonEncID }
	end
	return list, jid
end

local function groupInfo()
	local out = {}
	for i, name in ipairs(C:PartyMembers()) do
		local unit = i == 1 and "player" or ("party" .. (i - 1))
		local _, class = UnitClass(unit)
		out[#out + 1] = { name = name, class = class, level = UnitLevel(unit), guild = GetGuildInfo(unit),
			inMyGuild = (i == 1) and IsInGuild() or (UnitIsInMyGuild and UnitIsInMyGuild(unit)) or false,
			addon = C.partyAddon[name] }
	end
	return out
end

function R:Start()
	local instName, kind, difficulty, diffName, maxPlayers, _, _, mapID = GetInstanceInfo()
	local run = { inst = instName, kind = kind, map = mapID, difficulty = difficulty, diffName = diffName, maxPlayers = maxPlayers,
		enter = now(), group = groupInfo(), events = {}, loot = {}, zones = {}, kills = {} }
	local bosses, jid = self:JournalBosses()
	run.journal = bosses
	run.journalInstance = jid
	if bosses and #bosses > 0 then
		local final = bosses[#bosses]
		run.finalBoss = final
		if final.encounter then C.FINAL_ENCOUNTERS[final.encounter] = true end
		ns.db.finalBosses[mapID] = final -- remember across sessions
	end
	table.insert(ns.db.runs, 1, run)
	if #ns.db.runs > MAX_RUNS then table.remove(ns.db.runs) end
	self.current = run
	self:Event("enter", instName, mapID, difficulty)
	ns:Print("Recording dungeon run: |cffffffff%s|r%s", instName, run.finalBoss and (" (final boss: " .. run.finalBoss.name .. ")") or "")
	self:SampleZone()
end

function R:Stop()
	if not self.current then return end
	self.current.leave = now()
	self:Event("leave")
	self.current = nil
	ns.db.dirty = true
end

local function clean(v)
	if ns.IsSecret(v) then return "<secret>" end
	return v
end

function R:Event(kind, ...)
	local run = self.current
	if not run then return end
	local e = { t = now(), kind = kind }
	for i = 1, select("#", ...) do e[i] = clean((select(i, ...))) end
	run.events[#run.events + 1] = e
	ns.db.dirty = true
	if ns.Probe then ns.Probe:Log("run." .. kind, ...) end
end

-- What does the guild roster say about where we (and guildy party members) are?
function R:SampleZone()
	local run = self.current
	if not run or not IsInGuild() then return end
	C:RequestRoster()
	C_Timer.After(3, function()
		if not self.current then return end
		C:RefreshRoster()
		local sample = { t = now(), real = GetRealZoneText() }
		for _, m in ipairs(run.group) do
			local ro = C.roster[m.name]
			if ro then sample[m.name] = ro.zone or "?" end
		end
		run.zones[#run.zones + 1] = sample
		if #run.zones > 40 then table.remove(run.zones, 1) end
	end)
end

local function inDungeon()
	local inInstance, kind = IsInInstance()
	return inInstance and (kind == "party" or kind == "raid" or kind == "scenario")
end

local f = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ENCOUNTER_START", "ENCOUNTER_END", "BOSS_KILL",
	"CHAT_MSG_LOOT", "GROUP_ROSTER_UPDATE", "PLAYER_DEAD", "LOOT_OPENED" }) do pcall(f.RegisterEvent, f, e) end

f:SetScript("OnEvent", ns.Safe("Runs", function(_, event, ...)
	if not ns.db then return end
	if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
		local mapID = select(8, GetInstanceInfo())
		if inDungeon() then
			if not R.current or R.current.map ~= mapID then
				R:Stop()
				C_Timer.After(2, function() if inDungeon() and not R.current then R:Start() end end)
			end
		elseif R.current then
			R:Stop()
		end
	elseif not R.current then
		return
	elseif event == "ENCOUNTER_START" then
		R:Event("encounterStart", ...)
	elseif event == "ENCOUNTER_END" then
		local encID, encName, difficulty, size, success = clean((...)), clean((select(2, ...))), clean((select(3, ...))), clean((select(4, ...))), clean((select(5, ...)))
		R:Event("encounterEnd", encID, encName, difficulty, size, success)
		if success == 1 and encName ~= "<secret>" then
			local ok, checks = C:Qualification(encID, encName)
			local failed = {}
			for _, ch in ipairs(checks) do if not ch.ok then failed[#failed + 1] = ch.label end end
			R.current.kills[#R.current.kills + 1] = { t = GetServerTime(), id = encID, name = encName,
				final = C:IsFinalBoss(encID, encName) and true or false, qualifies = ok, failed = failed,
				lockdown = C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() }
			R:SampleZone()
		end
	elseif event == "BOSS_KILL" then
		R:Event("bossKill", ...)
	elseif event == "CHAT_MSG_LOOT" then
		local text, _, _, _, playerName = ...
		if ns.IsSecret(text) or ns.IsSecret(playerName) then
			R:Event("lootSecret")
			return
		end
		local link = text and text:match("|H(item:[^|]+)|h")
		local id = link and tonumber(link:match("item:(%d+)"))
		R.current.loot[#R.current.loot + 1] = { t = GetServerTime(), who = ns.NormName(playerName ~= "" and playerName or nil) or "?", item = id, text = text }
	elseif event == "LOOT_OPENED" then
		local items = {}
		for i = 1, GetNumLootItems() do
			local link = GetLootSlotLink(i)
			if link then items[#items + 1] = link:match("item:(%d+)") end
		end
		if #items > 0 then R:Event("lootWindow", table.concat(items, ",")) end
	elseif event == "GROUP_ROSTER_UPDATE" then
		R.current.group = groupInfo()
	elseif event == "PLAYER_DEAD" then
		R:Event("death")
	end
end))

-- sample the roster zone every 60s while inside
C_Timer.NewTicker(60, function() if R.current then R:SampleZone() end end)

ns:On("DB_READY", function()
	ns.db.runs = ns.db.runs or {}
	ns.db.finalBosses = ns.db.finalBosses or {}
	for _, fb in pairs(ns.db.finalBosses) do
		if fb.encounter then C.FINAL_ENCOUNTERS[fb.encounter] = true end
	end
end)
