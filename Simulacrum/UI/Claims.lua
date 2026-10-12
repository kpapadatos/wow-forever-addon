local _, ns = ...
local W = ns.W
local C = ns.Claims

local READY = "Interface\\RaidFrame\\ReadyCheck-Ready"
local WAIT = "Interface\\RaidFrame\\ReadyCheck-Waiting"
local NOT = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local HELP = "Interface\\Icons\\INV_Misc_QuestionMark"

-- state -> label, colour, explanation
local STATES = {
	queued    = { "Queued", "ffffd100", "Your claim is stored by your addon. The guild master has not been online since the kill, so nobody has received it yet. It is delivered automatically the next time you and the guild master are online together." },
	collecting= { "Collecting", "ffffd100", "The guild master has received this run and is waiting for the other party members' claims. Each member's addon delivers its own claim when that member and the guild master are online together." },
	review    = { "Manual review", "ff7fb2ff", "This run could not be verified automatically (for example the guild master was offline during the run and could not see where you were). It sits in the guild master's review list." },
	sus       = { "Flagged", "ffff8040", "Something did not add up (wrong location, a 15-minute lockout, unknown boss...). The guild master will look at it by hand." },
	accepted  = { "Approved", "ff3cd23c", "Approved! The DKP is assigned on the guild master's side and becomes official once the guild master saves (reloads). You will be notified." },
	complete  = { "Complete", "ff3cd23c", "Done. The DKP has been written to your officer note." },
	rejected  = { "Rejected", "ffd23c3c", "The guild master rejected this claim." },
}

local HOW = {
	"|cffe6c35cHow dungeon DKP works|r",
	"1. Clear a dungeon's final boss with a full group of 5 guild members who all run Simulacrum.",
	"2. Every party member's addon creates a claim and sends it to the guild master. If the guild master is offline, the claim waits in your addon and is delivered the next time you are both online.",
	"3. Other guild members online at the time check the guild roster to see where you are and send a 'verification' to the guild master. More verifications help your claim.",
	"4. If the guild master was online, saw all 5 of you in the dungeon and received all 5 claims, the DKP is awarded automatically. Otherwise it is reviewed by hand.",
	"5. After a claim, other boss kills within 15 minutes are never auto-approved.",
	" ",
	"|cff888888Why so many steps? Any single addon could be modified to lie. Requiring every party member, the server's own location data and independent witnesses makes faking a run about as hard as doing it.|r",
}

local function chipTip(chip)
	local c, name, i = chip.claim, chip.name, chip.i
	GameTooltip:SetOwner(chip, "ANCHOR_TOP")
	GameTooltip:SetText(name, 1, 0.82, 0)
	local recv = c.ack and c.ack.recv and c.ack.recv:sub(i, i)
	if c.state == "complete" then
		GameTooltip:AddLine("Claim complete.", 0.3, 0.9, 0.3)
	elseif recv == "1" then
		GameTooltip:AddLine("The guild master has received this member's claim.", 0.3, 0.9, 0.3, true)
	elseif c.ack then
		GameTooltip:AddLine(name == ns:PlayerName() and "Your claim has not reached the guild master yet."
			or (name .. " and the guild master have not been online at the same time yet. " .. name .. "'s addon will deliver the claim automatically."), 1, 1, 1, true)
	else
		GameTooltip:AddLine("Not known yet: the guild master has not been online since the kill, so nobody's claim has been received.", 1, 1, 1, true)
	end
	GameTooltip:Show()
end

local function makeCard(owner)
	local c = CreateFrame("Frame", nil, owner, BackdropTemplateMixin and "BackdropTemplate")
	W.Backdrop(c, { bgFile = ns.media .. "white", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
		insets = { left = 3, right = 3, top = 3, bottom = 3 } }, { 1, 0.9, 0.7, 0.05 }, { 0.5, 0.4, 0.2, 0.9 })
	c.icon = c:CreateTexture(nil, "ARTWORK")
	c.icon:SetSize(34, 34)
	c.icon:SetPoint("TOPLEFT", 10, -10)
	c.icon:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
	c.title = W.GoldText(c, 15, W.FONT_TITLE)
	c.title:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 10, 0)
	c.meta = W.Text(c, 11, { 0.75, 0.68, 0.55 })
	c.meta:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -3)

	c.state = CreateFrame("Frame", nil, c)
	c.state:SetSize(130, 20)
	c.state:SetPoint("TOPRIGHT", -10, -10)
	c.state:EnableMouse(true)
	c.stateText = W.Text(c.state, 12)
	c.stateText:SetPoint("RIGHT")
	c.stateText:SetJustifyH("RIGHT")
	c.state:SetScript("OnEnter", function(self)
		local s = STATES[self.key] or STATES.queued
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText(s[1], 1, 0.82, 0)
		GameTooltip:AddLine(s[3], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	c.state:SetScript("OnLeave", GameTooltip_Hide)

	c.chips = {}
	for i = 1, 5 do
		local chip = CreateFrame("Frame", nil, c)
		chip:SetSize(92, 20)
		chip:SetPoint("TOPLEFT", 10 + (i - 1) * 94, -54)
		chip:EnableMouse(true)
		chip.icon = chip:CreateTexture(nil, "ARTWORK")
		chip.icon:SetSize(16, 16)
		chip.icon:SetPoint("LEFT")
		chip.text = W.Text(chip, 11, W.C.white)
		chip.text:SetPoint("LEFT", chip.icon, "RIGHT", 3, 0)
		chip.text:SetWidth(72)
		chip.text:SetWordWrap(false)
		chip:SetScript("OnEnter", chipTip)
		chip:SetScript("OnLeave", GameTooltip_Hide)
		c.chips[i] = chip
	end

	c.verif = CreateFrame("Frame", nil, c)
	c.verif:SetSize(220, 18)
	c.verif:SetPoint("BOTTOMLEFT", 10, 8)
	c.verif:EnableMouse(true)
	c.verifText = W.Text(c.verif, 11, { 0.75, 0.68, 0.55 })
	c.verifText:SetPoint("LEFT")
	W.Tooltip(c.verif, "Verifications", "Other guild members online during your run who saw, in the guild roster, that your party was in the dungeon. They send this to the guild master as independent evidence. More is better.")

	c.note = W.Text(c, 11, { 0.75, 0.68, 0.55 })
	c.note:SetPoint("BOTTOMRIGHT", -10, 10)
	c.note:SetJustifyH("RIGHT")
	return c
end

local function fillCard(card, c)
	card:SetHeight(100)
	card.title:SetText(("%s  |cffbbbbbb-  %s|r"):format(c.encName or "?", c.inst or "?"))
	card.meta:SetText(date("%a %d %b  %H:%M", c.kill) .. (c.lockout and "   |cffff8040within 15-min lockout|r" or ""))
	local key = c.state or "queued"
	local s = STATES[key] or STATES.queued
	card.state.key = key
	card.stateText:SetText(("|c%s%s|r |TInterface\\FriendsFrame\\InformationIcon:14|t"):format(s[2], s[1]))
	local names = { strsplit(",", c.members) }
	for i, chip in ipairs(card.chips) do
		local name = names[i]
		chip:SetShown(name ~= nil)
		if name then
			chip.claim, chip.name, chip.i = c, name, i
			local recv = c.ack and c.ack.recv and c.ack.recv:sub(i, i)
			chip.icon:SetTexture((c.state == "complete" or recv == "1") and READY or (c.state == "rejected" and NOT) or WAIT)
			chip.text:SetText(name == ns:PlayerName() and ("|cffffd100" .. name .. "|r") or name)
		end
	end
	local v = c.ack and c.ack.verif or 0
	card.verifText:SetText(("|TInterface\\Icons\\INV_Misc_Spyglass_03:14|t  %d verification%s"):format(v, v == 1 and "" or "s"))
	if c.state == "complete" then
		card.note:SetText(("|cff3cd23c+%d DKP|r"):format(c.amount or 0))
	elseif c.ack and c.ack.amount then
		card.note:SetText(("worth |cffffffff%d DKP|r"):format(c.ack.amount))
	else
		card.note:SetText(c.ack and "" or "|cffaaaaaanot delivered yet|r")
	end
end

ns:RegisterPage({
	text = "Claims",
	icon = "Interface\\Icons\\INV_Misc_Note_06",
	tip = "Dungeon DKP claims and their status",
	build = function(page)
		-- Left: how it works + live checklist + save -----------------------------
		local left = W.Inset(page, 0.12)
		left:SetPoint("TOPLEFT")
		left:SetPoint("BOTTOMLEFT", 0, 2)
		left:SetWidth(380)
		local t = W.Title(left, 18)
		t:SetPoint("TOPLEFT", 14, -12)
		t:SetText("Dungeon DKP")
		local help = W.IconButton(left, 20, HELP, nil)
		help:SetPoint("LEFT", t, "RIGHT", 8, 0)
		help:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(HOW[1])
			for i = 2, #HOW do GameTooltip:AddLine(HOW[i], 1, 1, 1, true) end
			GameTooltip:Show()
		end)
		help:SetScript("OnLeave", GameTooltip_Hide)

		local blurb = W.Text(left, 12, W.C.ink)
		blurb:SetPoint("TOPLEFT", 14, -40)
		blurb:SetPoint("RIGHT", -14, 0)
		blurb:SetText("Clear a dungeon's final boss with 5 guild members running Simulacrum to earn DKP. Hover the |TInterface\\Icons\\INV_Misc_QuestionMark:14|t for the details.")

		local ct = W.Title(left, 15)
		ct:SetPoint("TOPLEFT", 14, -92)
		ct:SetText("Right now")
		local rows = {}
		for i = 1, 7 do
			local r = CreateFrame("Frame", nil, left)
			r:SetSize(350, 30)
			r:SetPoint("TOPLEFT", 14, -114 - (i - 1) * 32)
			r.icon = r:CreateTexture(nil, "ARTWORK")
			r.icon:SetSize(18, 18)
			r.icon:SetPoint("TOPLEFT", 0, -1)
			r.label = W.Text(r, 12, W.C.ink)
			r.label:SetPoint("TOPLEFT", 24, 0)
			r.detail = W.Text(r, 10, W.C.inkSoft)
			r.detail:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -1)
			r.detail:SetWidth(320)
			r.detail:SetWordWrap(false)
			rows[i] = r
		end

		local masterLine = W.Text(left, 11, W.C.inkSoft)
		masterLine:SetPoint("BOTTOMLEFT", 14, 52)
		masterLine:SetPoint("RIGHT", -14, 0)

		local save = W.Button(left, "Save pending requests", 190, 26, function() StaticPopup_Show("SIMULACRUM_SAVE") end)
		save:SetPoint("BOTTOMLEFT", 14, 16)
		local saveNote = W.Text(left, 10, W.C.inkSoft)
		saveNote:SetPoint("LEFT", save, "RIGHT", 8, 0)
		saveNote:SetPoint("RIGHT", -10, 0)
		W.Tooltip(save, "Save pending requests", "Writes your claims and verifications to disk with a /reload, so a crash or disconnect cannot lose them. A normal logout saves too.")

		-- Right: my claims ---------------------------------------------------------
		local right = W.Dark(page, 0.72)
		right:SetPoint("TOPLEFT", left, "TOPRIGHT", 12, 0)
		right:SetPoint("BOTTOMRIGHT", 0, 2)
		local rt = W.GoldText(right, 18, W.FONT_TITLE)
		rt:SetPoint("TOPLEFT", 14, -10)
		rt:SetText("My claims")
		local count = W.Text(right, 11, { 0.75, 0.68, 0.55 })
		count:SetPoint("TOPRIGHT", -14, -14)
		count:SetJustifyH("RIGHT")
		local empty = W.Text(right, 12, { 0.65, 0.6, 0.5 })
		empty:SetPoint("CENTER")
		empty:SetJustifyH("CENTER")
		empty:SetText("No claims yet.\nClear a dungeon's final boss with a full guild group!")

		local list = W.ScrollList(right, 500, 420, 106, makeCard, fillCard)
		list:SetPoint("TOPLEFT", 8, -36)

		function page:Update()
			local ok, checks = C:Qualification()
			for i, r in ipairs(rows) do
				local ch = checks[i]
				r:SetShown(ch ~= nil)
				if ch then
					r.icon:SetTexture(ch.ok and READY or NOT)
					r.label:SetText(ch.label)
					r.detail:SetText(ch.detail or "")
				end
			end
			local m = C.master
			if not IsInGuild() then
				masterLine:SetText("You are not in a guild.")
			elseif m then
				masterLine:SetText(("Guild master: |cff3a1f05%s|r - %s"):format(m, C:MasterOnline() and "|cff1a8a1aonline|r" or "|cff8a1a1aoffline|r"))
			else
				masterLine:SetText("Guild master: unknown (roster not loaded yet)")
			end
			local queued, proofs = 0, 0
			for _, c in ipairs(ns.db.claims) do if not c.ack then queued = queued + 1 end end
			for _, p in ipairs(ns.db.proofs) do if not p.acked then proofs = proofs + 1 end end
			saveNote:SetText(ns.db.dirty and "|cffa01010Unsaved changes|r" or "Everything saved")
			count:SetText(("%d claims  -  %d undelivered  -  %d verifications to deliver"):format(#ns.db.claims, queued, proofs))
			empty:SetShown(#ns.db.claims == 0)
			list:SetData(ns.db.claims)
		end
		ns:On("CLAIMS_CHANGED", function() if page:IsVisible() then page:Update() end end)
	end,
	onShow = function(page) page:Update() end,
})
