local _, ns = ...

-- ===========================================================================
-- Signed DKP ledger: an append-only list of entries, each signed by the guild
-- master's private key. Any member can relay entries to any other member;
-- everyone verifies signatures with ns.LEDGER_PUBKEY, so relays cannot forge
-- or alter entries, and gaps in the sequence show when something is missing.
--
-- Wire (prefix SIMULACRUM, "~"-separated):
--   V~head~keyId                    "my ledger goes up to #head"   GUILD / WHISPER
--   G~from~to                       "send me entries from..to"      WHISPER
--   L~seq~time~name~amount~reason~sig   one signed entry           WHISPER
-- ===========================================================================
local Ledger = {}
ns.Ledger = Ledger

local C = ns.Claims
local Crypto = ns.Crypto
local BATCH = 30
local REASON_MAX = 28

function Ledger.Canonical(e)
	return ("%d|%d|%s|%d|%s"):format(e.seq, e.time, e.name, e.amount, e.reason)
end

function Ledger.CleanReason(r)
	return ((r or ""):gsub("[~|]", " "):sub(1, REASON_MAX))
end

function Ledger:Store() return ns.db.ledger end

function Ledger:Head()
	return self:Store().head
end

-- lowest missing sequence number at or below head (nil if complete)
function Ledger:FirstGap()
	local s = self:Store()
	for i = 1, s.head do if not s.entries[i] then return i end end
end

function Ledger:Count()
	local n = 0
	for _ in pairs(self:Store().entries) do n = n + 1 end
	return n
end

function Ledger:Totals()
	if self.totals then return self.totals end
	local t = {}
	for _, e in pairs(self:Store().entries) do t[e.name] = (t[e.name] or 0) + e.amount end
	self.totals = t
	return t
end

function Ledger:Total(name) return self:Totals()[name] or 0 end

function Ledger:Entries()
	local list = {}
	for _, e in pairs(self:Store().entries) do list[#list + 1] = e end
	table.sort(list, function(a, b) return a.seq > b.seq end)
	return list
end

-- Adds a verified entry. Returns true if it was new.
function Ledger:Add(e, verified)
	local s = self:Store()
	if s.entries[e.seq] then return false end
	if not verified and not Crypto.Verify(Ledger.Canonical(e), e.sig) then
		if ns.Probe then ns.Probe:Log("ledger.badsig", e.seq, e.name, e.amount) end
		self.rejected = (self.rejected or 0) + 1
		return false
	end
	s.entries[e.seq] = e
	if e.seq > s.head then s.head = e.seq end
	self.totals = nil
	ns.db.dirty = true
	ns:Fire("LEDGER_CHANGED")
	return true
end

-- ---------------------------------------------------------------------------
-- Sync protocol
-- ---------------------------------------------------------------------------
local function join(...) return table.concat({ ... }, "~") end
local function now() return GetServerTime() end

function Ledger:Announce(channel, target)
	if not IsInGuild() then return end
	C:Send(join("V", self:Head(), ns.LEDGER_PUBKEY.id), channel or "GUILD", target)
end

function Ledger:EntryMsg(e)
	return join("L", e.seq, e.time, e.name, e.amount, e.reason, e.sig)
end

local fetching -- { from = name, until = time }

function Ledger:Want(source, theirHead)
	local s = self:Store()
	local need = self:FirstGap() or (theirHead > s.head and s.head + 1)
	if not need or need > theirHead then return end
	if fetching and fetching.from ~= source and fetching.untilT > now() then return end
	fetching = { from = source, untilT = now() + 20, head = theirHead }
	local target = C.roster[source] and C.roster[source].full or source
	C:Send(join("G", need, math.min(theirHead, need + BATCH - 1)), "WHISPER", target)
	self.lastSync = { from = source, at = now() }
end

local answered = {}

ns:On("COMM", function(cmd, f, channel, sender)
	if cmd == "V" then
		local theirHead, keyId = tonumber(f[1]) or 0, f[2]
		if keyId and keyId ~= ns.LEDGER_PUBKEY.id then
			Ledger.keyMismatch = sender
			return
		end
		local mine = Ledger:Head()
		if theirHead > mine or (theirHead > 0 and Ledger:FirstGap()) then
			Ledger:Want(sender, theirHead)
		elseif theirHead < mine and channel == "GUILD" then
			-- help a peer that is behind; the master always answers, others only while the master is away
			if (ns.isMaster or not C:MasterOnline()) and (answered[sender] or 0) < now() - 60 then
				answered[sender] = now()
				C_Timer.After(ns.isMaster and 1 or (2 + math.random() * 5), function()
					Ledger:Announce("WHISPER", C.roster[sender] and C.roster[sender].full or sender)
				end)
			end
		end
	elseif cmd == "G" then
		local from, to = tonumber(f[1]), tonumber(f[2])
		if not from or not to then return end
		local target = C.roster[sender] and C.roster[sender].full or sender
		local s = Ledger:Store()
		for seq = from, math.min(to, from + BATCH - 1) do
			local e = s.entries[seq]
			if e then C:Send(Ledger:EntryMsg(e), "WHISPER", target) end
		end
	elseif cmd == "L" then
		local e = { seq = tonumber(f[1]), time = tonumber(f[2]), name = f[3], amount = tonumber(f[4]), reason = f[5] or "", sig = f[6] }
		if not (e.seq and e.time and e.name and e.amount and e.sig) then return end
		if Ledger:Add(e) and fetching and fetching.from == sender then
			-- keep pulling until we are complete
			if Ledger.pullTimer then Ledger.pullTimer:Cancel() end
			Ledger.pullTimer = C_Timer.NewTimer(2, function() Ledger:Want(sender, fetching.head or e.seq) end)
		end
	end
end)

ns:On("DB_READY", function()
	ns.db.ledger = ns.db.ledger or { entries = {}, head = 0 }
	-- a new key invalidates everything signed with the old one
	if ns.db.ledger.keyId ~= ns.LEDGER_PUBKEY.id then
		ns.db.ledger = { entries = {}, head = 0, keyId = ns.LEDGER_PUBKEY.id }
	end
end)

ns:On("LOGIN", function()
	C_Timer.After(10, function() Ledger:Announce() end)
end)
