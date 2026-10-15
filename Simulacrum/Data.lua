local _, ns = ...

-- ---------------------------------------------------------------------------
-- Guild ranks
-- ---------------------------------------------------------------------------
ns.RANKS = {
	{ name = "Guild Master", icon = "Interface\\Icons\\INV_Crown_01" },
	{ name = "Officer",      icon = "Interface\\Icons\\INV_Sword_27" },
	{ name = "Raider",       icon = "Interface\\Icons\\INV_Shield_06" },
	{ name = "Veteran",      icon = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01" },
	{ name = "Member",       icon = "Interface\\Icons\\INV_Misc_Head_Human_01" },
	{ name = "Initiate",     icon = "Interface\\Icons\\INV_Misc_Note_01" },
}

-- ---------------------------------------------------------------------------
-- Demo roster (name, class token, level, rank index, base DKP, zone, note)
-- ---------------------------------------------------------------------------
local M = {
	{ "Aethelric",  "PALADIN", 60, 1, 412, "Stormwind City",   "Founder. Main tank on Ony." },
	{ "Morwenna",   "PRIEST",  60, 2, 388, "Ironforge",         "Healing lead" },
	{ "Draven",     "WARRIOR", 60, 2, 365, "Blackrock Mountain","Raid leader, MT" },
	{ "Sylvara",    "DRUID",   60, 2, 341, "Moonglade",         "Officer of the treasury" },
	{ "Kael'thos",  "MAGE",    60, 3, 322, "Ironforge",         "" },
	{ "Grimnar",    "HUNTER",  60, 3, 298, "Felwood",           "Tranq rotation #1" },
	{ "Vex",        "ROGUE",   60, 3, 284, "Booty Bay",         "" },
	{ "Ilyana",     "WARLOCK", 60, 3, 277, "Searing Gorge",     "Soulstone duty" },
	{ "Thornbeard", "WARRIOR", 60, 3, 263, "Ironforge",         "OT" },
	{ "Celestine",  "PRIEST",  60, 3, 251, "Stormwind City",    "" },
	{ "Brannoc",    "PALADIN", 60, 3, 240, "Western Plaguelands","" },
	{ "Nyxara",     "MAGE",    60, 3, 232, "Winterspring",      "AoE farm queen" },
	{ "Fenwick",    "HUNTER",  60, 4, 205, "Stranglethorn Vale","" },
	{ "Ravenna",    "ROGUE",   60, 4, 198, "Orgrimmar?",        "Spy on probation :)" },
	{ "Oswin",      "DRUID",   58, 4, 176, "Un'Goro Crater",    "" },
	{ "Halvard",    "WARRIOR", 59, 4, 160, "Burning Steppes",   "" },
	{ "Liora",      "PRIEST",  57, 4, 142, "Tanaris",           "" },
	{ "Quillon",    "WARLOCK", 56, 5, 120, "Azshara",           "" },
	{ "Maelis",     "MAGE",    54, 5, 98,  "Feralas",           "" },
	{ "Torvald",    "PALADIN", 52, 5, 86,  "The Hinterlands",   "" },
	{ "Zephyra",    "HUNTER",  49, 5, 64,  "Tanaris",           "" },
	{ "Corwin",     "ROGUE",   45, 5, 51,  "Stranglethorn Vale","" },
	{ "Elowen",     "DRUID",   41, 5, 40,  "Desolace",          "" },
	{ "Brom",       "WARRIOR", 37, 6, 22,  "Arathi Highlands",  "" },
	{ "Pippa",      "MAGE",    33, 6, 15,  "Hillsbrad Foothills","Alt of Nyxara" },
	{ "Seraphine",  "PRIEST",  28, 6, 10,  "Duskwood",          "" },
	{ "Gorrik",     "WARLOCK", 24, 6, 5,   "Redridge Mountains","" },
	{ "Wren",       "HUNTER",  19, 6, 0,   "Westfall",          "" },
}

ns.MEMBERS = {}
for i, m in ipairs(M) do
	ns.MEMBERS[i] = {
		name = m[1], class = m[2], level = m[3], rank = m[4], dkp = m[5], zone = m[6], note = m[7],
		online = (i % 3 ~= 0), lastSeen = (i % 3 == 0) and ((i * 7) % 30 + 1) or 0,
	}
end

function ns:GetMember(name)
	for _, m in ipairs(self.MEMBERS) do
		if m.name == name then return m end
	end
end

-- Live mode: in a real guild, DKP comes from the signed ledger and members from the roster
function ns:IsLive()
	return IsInGuild() and self.Ledger ~= nil
end

function ns:DKPMembers()
	local out = {}
	if self:IsLive() then
		for name, ro in pairs(self.Claims.roster) do
			out[#out + 1] = { name = name, class = ro.class, dkp = self.Ledger:Total(name), online = ro.online, rank = ro.rank }
		end
	else
		for _, m in ipairs(self.MEMBERS) do
			out[#out + 1] = { name = m.name, class = m.class, dkp = self:GetDKP(m.name), online = m.online, rank = m.rank }
		end
	end
	return out
end

function ns:MemberClass(name)
	local ro = self.Claims and self.Claims.roster[name]
	if ro then return ro.class end
	local m = self:GetMember(name)
	return m and m.class
end

function ns:GetDKP(name)
	if self:IsLive() then return self.Ledger:Total(name) end
	local m = self:GetMember(name)
	return ((m and m.dkp) or 0) + ((self.db and self.db.dkpAdjust[name]) or 0)
end

function ns:AwardDKP(name, amount, reason)
	if self:IsLive() then
		if self.Master then return self.Master:QueueManual(name, amount, reason) end
		return self:Print("Only the guild master can award DKP.")
	end
	self.db.dkpAdjust[name] = (self.db.dkpAdjust[name] or 0) + amount
	table.insert(self.db.dkpLog, 1, { time = time(), player = name, amount = amount, reason = reason, by = self:PlayerName() })
	self:Fire("DKP_CHANGED")
end

-- Seed DKP history so the log isn't empty on first open
ns.SEED_LOG = {
	{ ago = 1,  player = "Draven",    amount = 25,  reason = "Molten Core full clear" },
	{ ago = 1,  player = "Morwenna",  amount = 25,  reason = "Molten Core full clear" },
	{ ago = 1,  player = "Kael'thos", amount = -60, reason = "Won: Arcanist Crown" },
	{ ago = 2,  player = "Grimnar",   amount = 10,  reason = "On time bonus" },
	{ ago = 3,  player = "Vex",       amount = -45, reason = "Won: Nightslayer Pants" },
	{ ago = 4,  player = "Sylvara",   amount = 15,  reason = "Onyxia kill" },
	{ ago = 6,  player = "Ilyana",    amount = 20,  reason = "Brought 40 healthstones" },
	{ ago = 7,  player = "Thornbeard",amount = -80, reason = "Won: Onyxia Hide Backpack" },
}

-- ---------------------------------------------------------------------------
-- Guild goals
-- ---------------------------------------------------------------------------
ns.GOAL_CATEGORIES = { "Raiding", "Dungeons", "Professions", "Community" }

ns.GOALS = {
	{ id = "mc",     cat = "Raiding",     icon = "Interface\\Icons\\Spell_Fire_Incinerate",       title = "Extinguish the Firelord",   desc = "Defeat Ragnaros in Molten Core as a guild.",                 max = 10, base = 9,  reward = "Guild title: |cffff8000Firewalker|r" },
	{ id = "ony",    cat = "Raiding",     icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",     title = "Head of the Broodmother",   desc = "Slay Onyxia five times and hang her head in Stormwind.",     max = 5,  base = 3,  reward = "500 guild gold" },
	{ id = "thanes", cat = "Dungeons",    icon = "Interface\\Icons\\INV_Hammer_09",              title = "Dirge for the Thane",       desc = "Clear the Hall of Thanes with an all-guild group 20 times.", max = 20, base = 13, reward = "Tabard of the Thanes" },
	{ id = "ruins",  cat = "Dungeons",    icon = "Interface\\Icons\\Spell_Shadow_RaiseDead",      title = "Reclaim Lordaeron",         desc = "Defeat Rath'mael in the Ruins of Lordaeron.",                max = 15, base = 4,  reward = "Ruins banner for the guild hall" },
	{ id = "flasks", cat = "Professions", icon = "Interface\\Icons\\INV_Potion_62",               title = "Flask Fund",                desc = "Craft Flasks of the Titans for raid night.",                 max = 40, base = 27, reward = "Alchemists earn +5 DKP each" },
	{ id = "arcan",  cat = "Professions", icon = "Interface\\Icons\\INV_Misc_StoneTablet_05",     title = "Arcanite Reserve",          desc = "Transmute bars of Arcanite for the guild bank.",            max = 50, base = 50, reward = "Completed!" },
	{ id = "lvl",    cat = "Community",   icon = "Interface\\Icons\\INV_Misc_Book_09",            title = "Every Initiate to Sixty",   desc = "Help guild initiates reach level 60.",                      max = 12, base = 7,  reward = "Officers buy everyone a pint" },
	{ id = "fish",   cat = "Community",   icon = "Interface\\Icons\\INV_Misc_Fish_14",            title = "Stranglethorn Fishing Extravaganza", desc = "Win the Sunday fishing contest.",                   max = 1,  base = 0,  reward = "Arcanite Fishing Pole bragging rights" },
}

function ns:GoalProgress(goal)
	return math.min(goal.max, goal.base + ((self.db and self.db.goalProgress[goal.id]) or 0))
end

-- ---------------------------------------------------------------------------
-- Dungeons & loot (item IDs taken from AtlasLoot Forever data)
-- ---------------------------------------------------------------------------
ns.DUNGEONS = {
	{ key = "dm",  name = "The Deadmines",          level = "17 - 26", size = 5, image = "dm",
	  lore = "Beneath Moonbrook, Edwin VanCleef's Defias Brotherhood builds a juggernaut of a warship to strike at Stormwind.",
	  bosses = {
		{ name = "Rhahk'Zor",        items = { 872, 5187, 273289 } },
		{ name = "Sneed",            items = { 5194, 5195, 273293, 285292 } },
		{ name = "Gilnid",           items = { 1156, 5199, 273297 } },
		{ name = "Mr. Smite",        items = { 7230, 5192, 5196, 284715 } },
		{ name = "Captain Greenskin",items = { 5201, 10403, 5200 } },
		{ name = "Edwin VanCleef",   items = { 5193, 5202, 10399, 5191 } },
		{ name = "Cookie",           items = { 5198, 5197, 8490, 273298 } },
	}},
	{ key = "sfk", name = "Shadowfang Keep",        level = "22 - 30", size = 5, image = "sfk",
	  lore = "The keep of Baron Silverlaine, now home to the mad archmage Arugal and his cursed worgen.",
	  bosses = {
		{ name = "Razorclaw the Butcher", items = { 1292, 6226, 6633 } },
		{ name = "Baron Silverlaine",     items = { 6321, 6323, 273637, 276631 } },
		{ name = "Commander Springvale",  items = { 6320, 3191, 273643 } },
		{ name = "Odo the Blindwatcher",  items = { 6318, 6319, 273645 } },
		{ name = "Fenrus the Devourer",   items = { 6340, 3230, 273646 } },
		{ name = "Wolf Master Nandos",    items = { 3748, 6314, 273647 } },
		{ name = "Archmage Arugal",       items = { 6324, 6392, 6220 } },
	}},
	{ key = "hot", name = "Hall of Thanes",         level = "13 - 18", size = 5, image = "hot", forever = true,
	  lore = "Deep within the mountain the dwarven thanes of old lie restless, and Durgen Dirgehammer guards their tomb.",
	  bosses = {
		{ name = "Infurnus",           items = { 270230, 270231, 271095 } },
		{ name = "Plunder",            items = { 270228, 270229, 271098 } },
		{ name = "Durgen Dirgehammer", items = { 270256, 270260, 270261 } },
		{ name = "Trash",              items = { 270227, 271096, 271097 } },
	}},
	{ key = "rol", name = "Ruins of Lordaeron",     level = "13 - 18", size = 5, image = "rol", forever = true,
	  lore = "The shattered capital where Arthas slew his father. Something cold still stirs beneath the throne room.",
	  bosses = {
		{ name = "Witherfang",       items = { 271201, 271202, 271203 } },
		{ name = "The Abandoned",    items = { 271207, 271208, 271216 } },
		{ name = "Bjork",            items = { 271209, 271210, 271217 } },
		{ name = "Viktor the Vile",  items = { 271211, 271212, 271218 } },
		{ name = "Rath'mael",        items = { 271213, 271214, 271215 } },
	}},
	{ key = "wc",  name = "Wailing Caverns",        level = "17 - 24", size = 5, image = "wc",
	  lore = "Naralex the druid dreamed of restoring the Barrens; now his Fanged disciples twist the caverns into a nightmare.",
	  bosses = {
		{ name = "Lady Anacondra",        items = { 10412, 5404, 6446 } },
		{ name = "Kresh",                 items = { 13245, 6447, 273084 } },
		{ name = "Lord Pythas",           items = { 6472, 6473, 273089 } },
		{ name = "Skum",                  items = { 6449, 6448, 273137 } },
		{ name = "Lord Serpentis",        items = { 6469, 5970, 10411, 6459 } },
		{ name = "Verdan the Everliving", items = { 6630, 6631, 6629 } },
		{ name = "Mutanus the Devourer",  items = { 6461, 6627, 6463, 10441 } },
		{ name = "Deviate Faerie Dragon", items = { 5243, 6632 } },
	}},
	{ key = "sm",  name = "Scarlet Monastery",      level = "32 - 45", size = 5, image = "sm",
	  lore = "Zealots of the Scarlet Crusade hold Tirisfal's great monastery, purging anything they deem unclean.",
	  bosses = {
		{ name = "Herod",                      items = { 7719, 7718, 10330, 7717 } },
		{ name = "Commander Mograine",         items = { 7724, 10330, 7726, 7723 } },
		{ name = "High Inquisitor Whitemane",  items = { 7720, 7722, 7721 } },
		{ name = "Trash",                      items = { 5819, 7755, 7727, 7728, 7759, 7760, 7754, 10332 } },
	}},
}

-- Seed interest so the browser has something to show before anyone uses it
ns.SEED_INTEREST = {
	[5193]  = { Vex = "need", Corwin = "greed" },
	[5202]  = { Draven = "offspec" },
	[6220]  = { Ilyana = "need", Quillon = "need" },
	[6469]  = { Corwin = "need" },
	[7719]  = { Halvard = "need", Thornbeard = "need", Brom = "greed" },
	[7720]  = { Liora = "need", Seraphine = "need" },
	[7723]  = { Torvald = "need" },
	[273637]= { Brannoc = "greed" },
	[270256]= { Brom = "need" },
}

-- ---------------------------------------------------------------------------
-- News / chronicle for the hall
-- ---------------------------------------------------------------------------
ns.NEWS = {
	{ icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01", text = "|cff7a4a00<Simulacrum>|r has slain |cffff8000Onyxia|r for the third time!", ago = "2 days ago" },
	{ icon = "Interface\\Icons\\INV_Helmet_08",           text = "Kael'thos received |cffa335ee[Arcanist Crown]|r.",                       ago = "3 days ago" },
	{ icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing", text = "Morwenna was promoted to |cffffffffOfficer|r.",                       ago = "5 days ago" },
	{ icon = "Interface\\Icons\\INV_Misc_StoneTablet_05", text = "Guild goal completed: |cff1eff00Arcanite Reserve|r.",                    ago = "1 week ago" },
	{ icon = "Interface\\Icons\\Ability_Mount_RidingHorse", text = "Wren joined the guild. Welcome!",                                       ago = "1 week ago" },
}

ns.MOTD = "Raid tonight: Molten Core at 20:00 server. Fire resist gear on, flasks provided by the Flask Fund!"
ns.MOTTO = "\"We are but reflections - yet together, we cast a shadow over legends.\""

ns.EVENTS = {
	{ day = "Wed", time = "20:00", name = "Molten Core",     icon = "Interface\\Icons\\Spell_Fire_Incinerate" },
	{ day = "Thu", time = "21:00", name = "Onyxia's Lair",   icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01" },
	{ day = "Sat", time = "18:00", name = "Thanes Speedruns",icon = "Interface\\Icons\\INV_Hammer_09" },
	{ day = "Sun", time = "14:00", name = "STV Fishing",     icon = "Interface\\Icons\\INV_Fishingpole_02" },
}
