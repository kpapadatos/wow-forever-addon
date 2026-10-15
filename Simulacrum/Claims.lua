local _, ns = ...

-- ===========================================================================
-- Dungeon DKP claims (member + witness side). See docs/DKP_SPEC.md.
--
-- Wire format (prefix SIMULACRUM, fields joined with "~"):
--   C~ver~map~enc~kill~inst~encName~members        claim      member  -> GUILD / master
--   P~ver~map~enc~kill~inst~encName~members~obs~mask proof    witness -> master
--   A~map~enc~kill~state~recvMask~verif~amount     ack        master  -> claimer
--   K~map~enc~kill                                 proof ack  master  -> witness
--   D~map~enc~kill~amount~total                    done       master  -> claimer
--   H~ver~role                                     hello      anyone  -> GUILD (role M = master)
--   Q~ / R~ver                                     addon presence ping/reply on PARTY
-- ===========================================================================
local C = {}
ns.Claims = C

C.PROTO = "1"
C.LOCKOUT = 15 * 60
C.MERGE_WINDOW = 120
C.GROUP_SIZE = 5

-- Final bosses. Encounter IDs get filled in from probe data; names are the English fallback.
C.FINAL_ENCOUNTERS = {}
C.FINAL_BOSS_NAMES = {
	["Edwin VanCleef"] = true, ["Archmage Arugal"] = true, ["Durgen Dirgehammer"] = true,
	["Rath'mael"] = true, ["Mutanus the Devourer"] = true, ["High Inquisitor Whitemane"] = true,
	["Taragaman the Hungerer"] = true, ["Bazzalan"] = true,
}

local SendAddonMessage = C_ChatInfo.SendAddonMessage

local function now() return GetServerTime() end
local short = ns.NormName

function C:IsFinalBoss(encID, encName)
	return self.FINAL_ENCOUNTERS[encID] or self.FINAL_BOSS_NAMES[encName] or false
end

-- Records from different players match on map + encounter + member set, kill times within a window
function C.SameRun(a, b)
	return a.map == b.map and a.enc == b.enc and a.members == b.members and math.abs(a.kill - b.kill) <= C.MERGE_WINDOW
end

function C.SortedMembers(list)
	local t = {}
	for _, n in ipairs(list) do t[#t + 1] = short(n) end
	table.sort(t)
	return table.concat(t, ",")
end

-- ---------------------------------------------------------------------------
-- Guild roster cache + master detection
-- ---------------------------------------------------------------------------
C.roster = {}
local masterWasOnline = false

function C:RefreshRoster()
	wipe(self.roster)
	if not IsInGuild() then self.master = nil return end
	for i = 1, GetNumGuildMembers() do
		local name, rankName, rankIndex, level, _, zone, _, officerNote, online, _, class = GetGuildRosterInfo(i)
		local guid = select(17, GetGuildRosterInfo(i))
		if name then
			local s = short(name)
			self.roster[s] = { index = i, full = name, rank = rankIndex, rankName = rankName, zone = zone, online = online,
				level = level, class = class, officerNote = officerNote, guid = guid }
			if rankIndex == 0 then self.master = s end
		end
	end
	if ns.db and ns.db.masterOverride then self.master = ns.db.masterOverride end
end

function C:MasterOnline()
	local m = self.master and self.roster[self.master]
	return m and m.online or false
end

function C:MasterTarget()
	local m = self.master and self.roster[self.master]
	return m and m.full or self.master
end

function C:RequestRoster()
	if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end
end

-- ---------------------------------------------------------------------------
-- Throttled sender that waits out encounter chat lockdown
-- ---------------------------------------------------------------------------
local queue, pumping = {}, false
local function pump()
	if #queue == 0 then pumping = false return end
	if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
		C_Timer.After(2, pump)
		return
	end
	local m = table.remove(queue, 1)
	local res = SendAddonMessage(ns.COMM_PREFIX, m.msg, m.channel, m.target)
	if ns.Probe then ns.Probe:Log("claims.send", m.channel, m.target, m.msg, res) end
	C_Timer.After(0.35, pump)
end

function C:Send(msg, channel, target)
	if #msg > 255 then
		ns:Print("|cffff4040message too long (%d), not sent|r", #msg)
		return
	end
	queue[#queue + 1] = { msg = msg, channel = channel, target = target }
	if not pumping then pumping = true; C_Timer.After(0.1, pump) end
end

local function join(...) return table.concat({ ... }, "~") end

-- ---------------------------------------------------------------------------
-- Addon presence in the party
-- ---------------------------------------------------------------------------
C.partyAddon = {}

function C:PingParty()
	wipe(self.partyAddon)
	self.partyAddon[ns:PlayerName()] = ns.version
	if IsInGroup() and not IsInRaid() then self:Send(join("Q", ns.version), "PARTY") end
end

-- ---------------------------------------------------------------------------
-- Qualification (live checklist + the gate for creating a claim)
-- ---------------------------------------------------------------------------
function C:PartyMembers()
	local list = { ns:PlayerName() }
	for i = 1, 4 do
		local u = "party" .. i
		if UnitExists(u) then list[#list + 1] = ns.UnitFullName(u) end
	end
	return list
end

function C:LastClaimKill()
	local last = 0
	for _, c in ipairs(ns.db.claims) do if c.kill > last then last = c.kill end end
	return last
end

-- returns ok, checks = { {label, ok, detail} }
function C:Qualification(encID, encName)
	local checks = {}
	local function add(label, ok, detail) checks[#checks + 1] = { label = label, ok = ok, detail = detail } end
	local inInstance, kind = IsInInstance()
	local instName = GetInstanceInfo()
	add("Inside a dungeon", inInstance and kind == "party", inInstance and kind == "party" and instName or "not in a 5-player dungeon")

	local members = self:PartyMembers()
	add("Group of " .. self.GROUP_SIZE, #members == self.GROUP_SIZE and not IsInRaid(), ("%d / %d players"):format(#members, self.GROUP_SIZE))

	local notGuild, noAddon = {}, {}
	for i, name in ipairs(members) do
		local unit = i == 1 and "player" or ("party" .. (i - 1))
		local inGuild = (UnitIsInMyGuild and UnitIsInMyGuild(unit)) or self.roster[name] ~= nil
		if i == 1 then inGuild = IsInGuild() end
		if not inGuild then notGuild[#notGuild + 1] = name end
		if not self.partyAddon[name] then noAddon[#noAddon + 1] = name end
	end
	add("Everyone in the guild", #notGuild == 0, #notGuild == 0 and "all guild members" or ("not in guild: " .. table.concat(notGuild, ", ")))
	add("Everyone has Simulacrum", #noAddon == 0, #noAddon == 0 and "all running the addon" or ("missing addon: " .. table.concat(noAddon, ", ")))

	if encID or encName then
		add("Final boss", self:IsFinalBoss(encID, encName), encName or tostring(encID))
	end

	local since = now() - self:LastClaimKill()
	local lock = since < self.LOCKOUT
	add("No lockout", not lock, lock and ("previous claim %d min ago - will need manual review"):format(math.floor(since / 60))
		or "no claim in the last 15 minutes", true)

	local ok = true
	for _, c in ipairs(checks) do
		if not c.ok and c.label ~= "No lockout" then ok = false end
	end
	return ok, checks, members
end

-- ---------------------------------------------------------------------------
-- Claims (mine)
-- ---------------------------------------------------------------------------
local function markDirty() ns.db.dirty = true; ns:Fire("CLAIMS_CHANGED") end

local function claimMsg(c)
	return join("C", C.PROTO, c.map, c.enc, c.kill, c.inst, c.encName, c.members)
end

function C:CreateClaim(encID, encName, members, fake)
	local instName, _, _, _, _, _, _, mapID = GetInstanceInfo()
	local c = {
		map = fake and fake.map or mapID, enc = encID, encName = encName, inst = fake and fake.inst or instName,
		kill = now(), members = C.SortedMembers(members), created = now(), state = "queued",
		lockout = (now() - self:LastClaimKill()) < self.LOCKOUT,
	}
	table.insert(ns.db.claims, 1, c)
	markDirty()
	ns:Fire("LOCAL_CLAIM", c) -- our own GUILD broadcast never echoes back to us
	ns:Print("Dungeon DKP claim created for |cffffffff%s|r (%s). Open the Claims tab to follow it.", c.encName, c.inst)
	ns:Sound(SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_COMPLETE or 878)
	-- broadcast to the guild: reaches the master if online, and every online guildy as a witness request
	if IsInGuild() then
		self:Send(claimMsg(c), "GUILD")
		c.broadcast = true
	end
	self:Flush()
	return c
end

function C:OnEncounterEnd(encID, encName, difficulty, groupSize, success)
	if success ~= 1 then return end
	local ok, checks, members = self:Qualification(encID, encName)
	ns.db.lastQual = { time = now(), encName = encName, encID = encID, ok = ok, checks = checks }
	if ok then
		-- give the encounter lockdown a moment to clear before we talk
		C_Timer.After(2, function() self:CreateClaim(encID, encName, members) end)
	elseif self:IsFinalBoss(encID, encName) then
		ns:Print("|cffff8040%s defeated, but this run does not qualify for dungeon DKP.|r See the Claims tab for why.", encName)
	end
	ns:Fire("CLAIMS_CHANGED")
end

-- Deliver anything the master has not acknowledged yet (claims and witness proofs)
function C:Flush()
	if not self:MasterOnline() then return end
	local target = self:MasterTarget()
	if not target or short(target) == ns:PlayerName() then return end
	for _, c in ipairs(ns.db.claims) do
		if not c.ack then self:Send(claimMsg(c), "WHISPER", target) end
	end
	for _, p in ipairs(ns.db.proofs) do
		if not p.acked then
			self:Send(join("P", C.PROTO, p.map, p.enc, p.kill, p.inst, p.encName, p.members, p.obs, p.mask), "WHISPER", target)
		end
	end
end

local function findClaim(map, enc, kill)
	for _, c in ipairs(ns.db.claims) do
		if c.map == map and c.enc == enc and math.abs(c.kill - kill) <= C.MERGE_WINDOW then return c end
	end
end

-- ---------------------------------------------------------------------------
-- Witnessing other parties' claims
-- ---------------------------------------------------------------------------
local pendingWitness = {}

local function witness(rec)
	local mask = {}
	for i, name in ipairs({ strsplit(",", rec.members) }) do
		local r = C.roster[name]
		mask[i] = (r and r.online and r.zone == rec.inst) and "1" or "0"
	end
	rec.obs = now()
	rec.mask = table.concat(mask)
	table.insert(ns.db.proofs, 1, rec)
	if #ns.db.proofs > 200 then table.remove(ns.db.proofs) end
	markDirty()
	C:Flush()
end

function C:OnClaimBroadcast(f, sender)
	local rec = { map = tonumber(f[2]), enc = tonumber(f[3]), kill = tonumber(f[4]), inst = f[5], encName = f[6], members = f[7], from = sender }
	if not rec.map or not rec.members then return end
	-- party members do not witness their own run
	for name in rec.members:gmatch("[^,]+") do if name == ns:PlayerName() then return end end
	for _, p in ipairs(ns.db.proofs) do if C.SameRun(p, rec) then return end end
	for _, p in ipairs(pendingWitness) do if C.SameRun(p, rec) then return end end
	pendingWitness[#pendingWitness + 1] = rec
	-- look at fresh roster data (server-side zones) before judging
	self:RequestRoster()
	C_Timer.After(4, function()
		for i, p in ipairs(pendingWitness) do
			if p == rec then table.remove(pendingWitness, i) break end
		end
		witness(rec)
	end)
end

-- ---------------------------------------------------------------------------
-- Messages from the master / party
-- ---------------------------------------------------------------------------
ns:On("COMM", function(cmd, f, channel, sender)
	if cmd == "C" and channel == "GUILD" then
		C:OnClaimBroadcast(f, sender)
	elseif cmd == "Q" or cmd == "R" then
		C.partyAddon[sender] = f[1] or "?"
		if cmd == "Q" then C:Send(join("R", ns.version), "PARTY") end
		ns:Fire("CLAIMS_CHANGED")
	elseif cmd == "H" then
		if f[2] == "M" then C:RefreshRoster(); C_Timer.After(2, function() C:Flush() end) end
	elseif sender == C.master or (ns.isMaster and sender == ns:PlayerName()) then
		local map, enc, kill = tonumber(f[1]), tonumber(f[2]), tonumber(f[3])
		if cmd == "A" then
			local c = findClaim(map, enc, kill)
			if c then
				c.ack = { state = f[4], recv = f[5], verif = tonumber(f[6]) or 0, amount = tonumber(f[7]), at = now() }
				if c.state ~= "complete" then c.state = f[4] end
				markDirty()
			end
		elseif cmd == "K" then
			for _, p in ipairs(ns.db.proofs) do
				if p.map == map and p.enc == enc and math.abs(p.kill - kill) <= C.MERGE_WINDOW then p.acked = true end
			end
			markDirty()
		elseif cmd == "D" then
			local c = findClaim(map, enc, kill)
			if c and c.state ~= "complete" then
				c.state, c.amount, c.total = "complete", tonumber(f[4]), tonumber(f[5])
				c.ack = c.ack or {}
				markDirty()
				ns:Print("|cff3cd23c+%d DKP|r for %s - your total is now %s.", c.amount or 0, c.encName, f[5] or "?")
				ns:Sound(SOUNDKIT and SOUNDKIT.LOOT_WINDOW_COIN_SOUND or 120)
			end
		end
	end
end)

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ENCOUNTER_END")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("GUILD_ROSTER_UPDATE")
ev:SetScript("OnEvent", ns.Safe("Claims", function(_, event, ...)
	if not ns.db then return end
	if event == "ENCOUNTER_END" then
		for i = 1, select("#", ...) do if ns.IsSecret((select(i, ...))) then return end end
		C:OnEncounterEnd(...)
	elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
		C_Timer.After(1, function() C:PingParty() end)
		ns:Fire("CLAIMS_CHANGED")
	elseif event == "GUILD_ROSTER_UPDATE" then
		C:RefreshRoster()
		local online = C:MasterOnline()
		if online and not masterWasOnline then C:Flush() end
		masterWasOnline = online
		ns:Fire("CLAIMS_CHANGED")
	end
end))

ns:On("DB_READY", function()
	ns.db.claims = ns.db.claims or {}
	ns.db.proofs = ns.db.proofs or {}
	ns.db.dirty = false -- whatever is in the file right now is saved
end)

ns:On("LOGIN", function()
	C:RequestRoster()
	C_Timer.After(6, function()
		C:RefreshRoster()
		if IsInGuild() then C:Send(join("H", ns.version, "m"), "GUILD") end
		masterWasOnline = C:MasterOnline()
		C:Flush()
	end)
end)

-- ---------------------------------------------------------------------------
-- Save (= /reload) with an explanation
-- ---------------------------------------------------------------------------
StaticPopupDialogs["SIMULACRUM_SAVE"] = {
	text = "|cffe6c35cSave pending requests|r\n\nWoW only writes addon data to disk on a UI reload or a normal logout. "
		.. "Saving now runs |cffffffff/reload|r: your screen flickers for a moment and the |cffff8040chat window is cleared|r.\n\n"
		.. "If you log out normally your requests are saved anyway - this protects them against crashes and disconnects.",
	button1 = "Save (/reload)",
	button2 = CANCEL,
	OnAccept = function() ReloadUI() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

-- ---------------------------------------------------------------------------
-- Dev: simulate a qualifying run so the flow can be exercised solo
-- ---------------------------------------------------------------------------
SLASH_SIMTEST1 = "/simtest"
SlashCmdList.SIMTEST = function()
	local me = ns:PlayerName()
	local members = { me, "Draven", "Morwenna", "Vex", "Kael'thos" }
	for _, n in ipairs(members) do C.partyAddon[n] = ns.version end
	C:CreateClaim(9999, "Edwin VanCleef", members, { map = 36, inst = "The Deadmines" })
	ns:Fire("SIMTEST", members)
end
