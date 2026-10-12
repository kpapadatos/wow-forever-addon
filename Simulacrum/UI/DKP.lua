local _, ns = ...
local W = ns.W

local BAR_ROWS = 13

ns:RegisterPage({
	text = "DKP",
	icon = "Interface\\Icons\\INV_Misc_Coin_02",
	tip = "Dragon Kill Points standings, awards and history",
	build = function(page)
		-- Standings chart ------------------------------------------------------
		local left = W.Inset(page, 0.12)
		left:SetPoint("TOPLEFT")
		left:SetPoint("BOTTOMLEFT", 0, 2)
		left:SetWidth(430)
		local t = W.Title(left, 18)
		t:SetPoint("TOPLEFT", 14, -10)
		t:SetText("Standings")
		local hint = W.Text(left, 10, W.C.inkSoft)
		hint:SetPoint("TOPRIGHT", -14, -15)
		hint:SetJustifyH("RIGHT")
		hint:SetText("Click a bar to select a member")

		local bars = {}
		for i = 1, BAR_ROWS do
			local b = CreateFrame("Button", nil, left)
			b:SetSize(402, 30)
			b:SetPoint("TOPLEFT", 14, -38 - (i - 1) * 32)
			b.rank = W.Title(b, 15)
			b.rank:SetPoint("LEFT", 0, 0)
			b.rank:SetWidth(24)
			b.rank:SetJustifyH("RIGHT")
			b.icon = b:CreateTexture(nil, "ARTWORK")
			b.icon:SetSize(22, 22)
			b.icon:SetPoint("LEFT", 30, 0)
			b.track = b:CreateTexture(nil, "BACKGROUND")
			b.track:SetPoint("LEFT", 58, 0)
			b.track:SetSize(340, 22)
			b.track:SetColorTexture(0.3, 0.2, 0.08, 0.18)
			b.fill = b:CreateTexture(nil, "BORDER")
			b.fill:SetPoint("LEFT", b.track, "LEFT")
			b.fill:SetHeight(22)
			b.name = W.GoldText(b, 12)
			b.name:SetPoint("LEFT", b.track, "LEFT", 6, 0)
			b.val = W.GoldText(b, 12)
			b.val:SetPoint("RIGHT", b.track, "RIGHT", -6, 0)
			b.sel = b:CreateTexture(nil, "OVERLAY")
			b.sel:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
			b.sel:SetBlendMode("ADD")
			b.sel:SetAllPoints(b.track)
			b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
			b:GetHighlightTexture():SetAllPoints(b.track)
			b:SetScript("OnClick", function(self) page:Select(self.member) end)
			bars[i] = b
		end

		-- Award form -------------------------------------------------------------
		local form = W.Inset(page, 0.12)
		form:SetPoint("TOPLEFT", left, "TOPRIGHT", 12, 0)
		form:SetPoint("RIGHT")
		form:SetHeight(150)
		local ft = W.Title(form, 18)
		ft:SetPoint("TOPLEFT", 14, -10)
		ft:SetText("Award Points")

		local who = W.Text(form, 13, W.C.ink)
		who:SetPoint("TOPRIGHT", -14, -14)
		who:SetJustifyH("RIGHT")

		local targetSel = W.Select(form, 190, {
			{ value = "one", text = "Selected member", icon = "Interface\\Icons\\INV_Misc_Head_Human_01" },
			{ value = "raid", text = "Everyone online", icon = "Interface\\Icons\\INV_Misc_GroupNeedMore" },
			{ value = "raiders", text = "Raiders and above", icon = "Interface\\Icons\\INV_Shield_06" },
		})
		targetSel:SetPoint("TOPLEFT", 14, -40)
		local amount = W.EditBox(form, 70, "Amount", true)
		amount:SetPoint("LEFT", targetSel, "RIGHT", 8, 0)
		amount:SetText("10")
		local reason = W.EditBox(form, 420, "Reason (e.g. Ragnaros kill, on-time bonus, won [item])")
		reason:SetPoint("TOPLEFT", targetSel, "BOTTOMLEFT", 0, -8)

		local function targets()
			local v = targetSel:GetValue()
			if v == "one" then return page.selected and { page.selected } or {} end
			local out = {}
			for _, m in ipairs(ns.MEMBERS) do
				if (v == "raid" and m.online) or (v == "raiders" and m.rank <= 3) then out[#out + 1] = m.name end
			end
			return out
		end
		local function apply(sign)
			local n = tonumber(amount:GetText())
			local list = targets()
			if not n or n <= 0 or #list == 0 then
				UIErrorsFrame:AddMessage("Pick a member and enter an amount.", 1, 0.2, 0.2)
				return
			end
			local why = reason:GetText() ~= "" and reason:GetText() or (sign > 0 and "Manual award" or "Manual deduction")
			for _, name in ipairs(list) do ns:AwardDKP(name, sign * n, why) end
			ns:Sound(SOUNDKIT and SOUNDKIT.LOOT_WINDOW_COIN_SOUND or 120)
			reason:SetText("")
		end
		local award = W.Button(form, "Award", 96, 26, function() apply(1) end)
		award:SetPoint("TOPLEFT", reason, "BOTTOMLEFT", 0, -10)
		local deduct = W.Button(form, "Deduct", 96, 26, function() apply(-1) end)
		deduct:SetPoint("LEFT", award, "RIGHT", 8, 0)
		local undo = W.Button(form, "Undo last", 96, 26, function()
			local e = table.remove(ns.db.dkpLog, 1)
			if e then
				ns.db.dkpAdjust[e.player] = (ns.db.dkpAdjust[e.player] or 0) - e.amount
				ns:Fire("DKP_CHANGED")
			end
		end)
		undo:SetPoint("LEFT", deduct, "RIGHT", 8, 0)

		-- History log ---------------------------------------------------------------
		local logBox = W.Dark(page, 0.72)
		logBox:SetPoint("TOPLEFT", form, "BOTTOMLEFT", 0, -10)
		logBox:SetPoint("BOTTOMRIGHT", 0, 2)
		local lt = W.GoldText(logBox, 15, W.FONT_TITLE)
		lt:SetPoint("TOPLEFT", 12, -8)
		lt:SetText("History")

		local list = W.ScrollList(logBox, 440, 264, 22, function(owner)
			local r = CreateFrame("Frame", nil, owner)
			r.when = W.Text(r, 11, { 0.6, 0.55, 0.45 })
			r.when:SetPoint("LEFT", 4, 0)
			r.who = W.Text(r, 12)
			r.who:SetPoint("LEFT", 92, 0)
			r.amt = W.Text(r, 12)
			r.amt:SetPoint("LEFT", 190, 0)
			r.amt:SetWidth(44)
			r.amt:SetJustifyH("RIGHT")
			r.why = W.Text(r, 11, W.C.white)
			r.why:SetPoint("LEFT", 246, 0)
			r.why:SetPoint("RIGHT", -2, 0)
			r.why:SetWordWrap(false)
			return r
		end, function(r, e)
			r.when:SetText(date("%d %b %H:%M", e.time))
			r.who:SetText(e.player)
			local m = ns:GetMember(e.player)
			r.who:SetTextColor(W.ClassColor(m and m.class))
			r.amt:SetText((e.amount > 0 and "+" or "") .. e.amount)
			r.amt:SetTextColor(e.amount > 0 and 0.3 or 1, e.amount > 0 and 0.9 or 0.3, 0.3)
			r.why:SetText(e.reason)
		end)
		list:SetPoint("TOPLEFT", 10, -30)

		function page:Select(name)
			self.selected = name
			local m = ns:GetMember(name)
			local _, l, r, t, b = W.ClassIcon(m and m.class)
			who:SetText(name and ("Selected: |TInterface\\TargetingFrame\\UI-Classes-Circles:16:16:0:0:256:256:%d:%d:%d:%d|t |cff3a1f05%s|r")
				:format(l * 256, r * 256, t * 256, b * 256, name) or "")
			for _, b in ipairs(bars) do b.sel:SetShown(b.member == name) end
		end

		function page:Update()
			local sorted = {}
			for _, m in ipairs(ns.MEMBERS) do sorted[#sorted + 1] = { name = m.name, class = m.class, dkp = ns:GetDKP(m.name) } end
			table.sort(sorted, function(a, b) return a.dkp > b.dkp end)
			local top = math.max(1, sorted[1].dkp)
			for i, b in ipairs(bars) do
				local s = sorted[i]
				b.member = s.name
				b.rank:SetText(i)
				b.icon:SetTexture(W.ClassIcon(s.class))
				b.icon:SetTexCoord(select(2, W.ClassIcon(s.class)))
				local r, g, bl = W.ClassColor(s.class)
				W.Gradient(b.fill, "HORIZONTAL", r * 0.45, g * 0.45, bl * 0.45, 0.95, r, g, bl, 0.95)
				b.fill:SetWidth(math.max(2, 340 * math.max(0, s.dkp) / top))
				b.name:SetText(s.name)
				b.val:SetText(s.dkp)
				b.sel:SetShown(s.name == self.selected)
			end
			-- history: my edits first, then the seeded entries
			local log = {}
			for _, e in ipairs(ns.db.dkpLog) do log[#log + 1] = e end
			local now = time()
			for _, e in ipairs(ns.SEED_LOG) do
				log[#log + 1] = { time = now - e.ago * 86400 - 3600 * 3, player = e.player, amount = e.amount, reason = e.reason }
			end
			list:SetData(log)
		end

		ns:On("DKP_CHANGED", function() if page:IsVisible() then page:Update() end end)
		page:Select(ns:GetMember(ns:PlayerName()) and ns:PlayerName() or "Draven")
	end,
	onShow = function(page) page:Update() end,
})
