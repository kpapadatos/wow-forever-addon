local _, ns = ...
local W = ns.W

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local ROLE_ICON = {
	Tank = "Interface\\Icons\\Ability_Defend",
	Healer = "Interface\\Icons\\Spell_Holy_Heal",
	DPS = "Interface\\Icons\\Ability_DualWield",
}

local SEED_APPS = {
	{ name = "Lunarfrost", class = "MAGE", level = 60, roles = { DPS = true }, avail = "Weeknights", status = "pending",
	  text = "Ex-raider from <Ashen Verdict>. Pre-raid BiS, fire resist set ready. Looking for a calm, organised raid team." },
	{ name = "Bronzehelm", class = "WARRIOR", level = 58, roles = { Tank = true, DPS = true }, avail = "Weekends", status = "pending",
	  text = "Dwarf prot warrior, almost 60. Happy to tank alt runs and learn the raid encounters." },
}

local function label(parent, text, anchor, x, y)
	local l = W.Title(parent, 14)
	l:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -12)
	l:SetText(text)
	return l
end

ns:RegisterPage({
	text = "Recruitment",
	icon = "Interface\\Icons\\INV_Letter_02",
	tip = "Application form and pending applicants",
	build = function(page)
		if #ns.db.applications == 0 then
			for _, a in ipairs(SEED_APPS) do table.insert(ns.db.applications, CopyTable(a)) end
		end

		-- Form ----------------------------------------------------------------
		local form = W.Inset(page, 0.12)
		form:SetPoint("TOPLEFT")
		form:SetPoint("BOTTOMLEFT", 0, 2)
		form:SetWidth(440)
		local t = W.Title(form, 20)
		t:SetPoint("TOPLEFT", 16, -12)
		t:SetText("Apply to <Simulacrum>")
		local d = W.Divider(form, 260)
		d:SetPoint("TOP", 0, -40)

		local l1 = label(form, "Character name", t, 0, -36)
		local name = W.EditBox(form, 190, "e.g. Thrallmar")
		name:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -4)
		name:SetText(ns:PlayerName())

		local classItems = {}
		for i, c in ipairs(CLASSES) do
			local tex, l, r, tp, b = W.ClassIcon(c)
			local cr, cg, cb = W.ClassColor(c)
			classItems[i] = { value = c, text = ("|cff%02x%02x%02x%s|r"):format(cr * 255, cg * 255, cb * 255,
				(LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c]) or c),
				icon = tex, coords = { l, r, tp, b } }
		end
		local l2 = W.Title(form, 14)
		l2:SetPoint("TOPLEFT", l1, "TOPLEFT", 210, 0)
		l2:SetText("Class")
		local class = W.Select(form, 190, classItems)
		class:SetPoint("TOPLEFT", l2, "BOTTOMLEFT", 0, -4)
		local _, myClass = UnitClass("player")
		if myClass then class:SetValue(myClass) end

		local l3 = label(form, "Level", name, 0, -16)
		local level = W.Slider(form, 190, 1, 60, 1)
		level:SetPoint("TOPLEFT", l3, "BOTTOMLEFT", 0, -20)
		level:SetValue(UnitLevel("player") or 60)

		local l4 = W.Title(form, 14)
		l4:SetPoint("TOPLEFT", l3, "TOPLEFT", 210, 0)
		l4:SetText("Raid availability")
		local avail = W.Select(form, 190, {
			{ value = "Weeknights", text = "Weeknights", icon = "Interface\\Icons\\INV_Misc_PocketWatch_01" },
			{ value = "Weekends", text = "Weekends", icon = "Interface\\Icons\\INV_Misc_PocketWatch_02" },
			{ value = "Both", text = "Any day", icon = "Interface\\Icons\\INV_Misc_PocketWatch_03" },
		})
		avail:SetPoint("TOPLEFT", l4, "BOTTOMLEFT", 0, -4)

		local l5 = label(form, "Roles", level, 0, -28)
		local roles, prev = {}, nil
		for _, role in ipairs({ "Tank", "Healer", "DPS" }) do
			local c = W.Check(form, ("|T%s:16|t %s"):format(ROLE_ICON[role], role))
			if prev then c:SetPoint("LEFT", prev, "RIGHT", 90, 0) else c:SetPoint("TOPLEFT", l5, "BOTTOMLEFT", 0, -4) end
			roles[role], prev = c, c
		end

		local l6 = label(form, "Tell us about yourself", roles.Tank, 0, -12)
		local about = W.TextArea(form, 408, 110, "Experience, professions, why Simulacrum...")
		about:SetPoint("TOPLEFT", l6, "BOTTOMLEFT", 0, -4)
		local chars = W.Text(form, 10, W.C.inkSoft)
		chars:SetPoint("TOPRIGHT", about, "BOTTOMRIGHT", 0, -3)
		chars:SetJustifyH("RIGHT")
		about.edit:SetMaxLetters(400)
		about.edit:HookScript("OnTextChanged", function(e) chars:SetText(("%d / 400"):format(e:GetNumLetters())) end)
		chars:SetText("0 / 400")

		local submit = W.Button(form, "Submit application", 170, 28)
		submit:SetPoint("BOTTOMLEFT", 16, 14)
		local clear = W.Button(form, "Clear", 90, 28, function()
			name:SetText(""); about:SetText("")
			for _, c in pairs(roles) do c:SetChecked(false) end
		end)
		clear:SetPoint("LEFT", submit, "RIGHT", 8, 0)

		-- Applications list -----------------------------------------------------
		local right = W.Dark(page, 0.72)
		right:SetPoint("TOPLEFT", form, "TOPRIGHT", 12, 0)
		right:SetPoint("BOTTOMRIGHT", 0, 2)
		local rt = W.GoldText(right, 18, W.FONT_TITLE)
		rt:SetPoint("TOPLEFT", 14, -10)
		rt:SetText("Applications")
		local pend = W.Text(right, 11, { 0.75, 0.68, 0.55 })
		pend:SetPoint("TOPRIGHT", -14, -14)
		pend:SetJustifyH("RIGHT")

		local list = W.ScrollList(right, 432, 420, 105, function(owner)
			local c = CreateFrame("Frame", nil, owner, BackdropTemplateMixin and "BackdropTemplate")
			W.Backdrop(c, { bgFile = ns.media .. "white", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
				insets = { left = 3, right = 3, top = 3, bottom = 3 } }, { 1, 0.9, 0.7, 0.05 }, { 0.5, 0.4, 0.2, 0.9 })
			c.icon = c:CreateTexture(nil, "ARTWORK")
			c.icon:SetSize(36, 36)
			c.icon:SetPoint("TOPLEFT", 10, -10)
			c.name = W.GoldText(c, 15, W.FONT_TITLE)
			c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 10, 0)
			c.meta = W.Text(c, 11, { 0.75, 0.68, 0.55 })
			c.meta:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
			c.status = W.Text(c, 11)
			c.status:SetPoint("TOPRIGHT", -10, -10)
			c.text = W.Text(c, 11, W.C.white)
			c.text:SetPoint("TOPLEFT", c.icon, "BOTTOMLEFT", 0, -6)
			c.text:SetPoint("RIGHT", -110, 0)
			c.text:SetHeight(42)
			c.text:SetJustifyV("TOP")
			c.accept = W.Button(c, "Accept", 88, 22, function() c.app.status = "accepted"; page:Update() end)
			c.accept:SetPoint("BOTTOMRIGHT", -10, 34)
			c.decline = W.Button(c, "Decline", 88, 22, function() c.app.status = "declined"; page:Update() end)
			c.decline:SetPoint("BOTTOMRIGHT", -10, 8)
			return c
		end, function(c, app)
			c.app = app
			c:SetHeight(100)
			c.icon:SetTexture(W.ClassIcon(app.class))
			c.icon:SetTexCoord(select(2, W.ClassIcon(app.class)))
			c.name:SetText(app.name)
			c.name:SetTextColor(W.ClassColor(app.class))
			local rl = {}
			for _, role in ipairs({ "Tank", "Healer", "DPS" }) do
				if app.roles[role] then rl[#rl + 1] = ("|T%s:12|t %s"):format(ROLE_ICON[role], role) end
			end
			c.meta:SetText(("Level %d  -  %s  -  %s"):format(app.level, table.concat(rl, " "), app.avail))
			local s = app.status
			c.status:SetText(s == "accepted" and "|cff3cd23cAccepted|r" or s == "declined" and "|cffd23c3cDeclined|r" or "|cffffd100Pending|r")
			c.text:SetText(app.text ~= "" and app.text or "|cff777777(no message)|r")
			c.accept:SetShown(s == "pending")
			c.decline:SetShown(s == "pending")
		end)
		list:SetPoint("TOPLEFT", 8, -36)

		function page:Update()
			local n = 0
			for _, a in ipairs(ns.db.applications) do if a.status == "pending" then n = n + 1 end end
			pend:SetText(("%d pending  -  %d total"):format(n, #ns.db.applications))
			list:SetData(ns.db.applications)
		end

		submit:SetScript("OnClick", function()
			local n = strtrim(name:GetText())
			local r, any = {}, false
			for role, c in pairs(roles) do if c:GetChecked() then r[role], any = true, true end end
			if n == "" or not any then
				UIErrorsFrame:AddMessage("Please enter a name and pick at least one role.", 1, 0.2, 0.2)
				ns:Sound(SOUNDKIT and SOUNDKIT.IG_QUEST_FAILED or 847)
				return
			end
			table.insert(ns.db.applications, 1, { name = n, class = class:GetValue(), level = math.floor(level:GetValue()),
				roles = r, avail = avail:GetValue(), text = strtrim(about:GetText()), status = "pending" })
			about:SetText("")
			ns:Sound(SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_COMPLETE or 878)
			ns:Print("Application from |cffffffff%s|r submitted. The officers will review it.", n)
			page:Update()
		end)
	end,
	onShow = function(page) page:Update() end,
})
