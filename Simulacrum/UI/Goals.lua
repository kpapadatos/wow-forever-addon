local _, ns = ...
local W = ns.W

local CARD_W, CARD_H = 448, 100

local function makeCard(parent)
	local c = W.Inset(parent, 0.14)
	c:SetSize(CARD_W, CARD_H)
	c.icon = W.Icon(c, 52, nil)
	c.icon:SetPoint("TOPLEFT", 12, -12)
	c.check = c:CreateTexture(nil, "OVERLAY")
	c.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
	c.check:SetSize(26, 26)
	c.check:SetPoint("BOTTOMRIGHT", c.icon, 8, -8)
	c.title = W.Title(c, 16)
	c.title:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 12, 0)
	c.title:SetPoint("RIGHT", -170, 0)
	c.title:SetWordWrap(false)
	c.cat = W.Text(c, 10, W.C.inkSoft)
	c.cat:SetPoint("TOPRIGHT", -12, -12)
	c.cat:SetJustifyH("RIGHT")
	c.desc = W.Text(c, 11, W.C.ink)
	c.desc:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -3)
	c.desc:SetPoint("RIGHT", -12, 0)
	c.bar = W.Progress(c, 250, 18)
	c.bar:SetPoint("BOTTOMLEFT", c.icon, "BOTTOMRIGHT", 10, -26)
	c.cat:SetWidth(160)
	c.cat:SetWordWrap(false)
	c.icon:EnableMouse(true)
	W.Tooltip(c.icon, function() return c.goal.title end)
	c.icon:HookScript("OnEnter", function()
		GameTooltip:AddLine(c.goal.cat, 0.7, 0.7, 0.7)
		GameTooltip:AddLine("Reward: " .. c.goal.reward, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	c.btn = W.Button(c, "Contribute", 100, 24)
	c.btn:SetPoint("LEFT", c.bar, "RIGHT", 10, 0)
	c.btn:SetScript("OnClick", function(self)
		local g = self.goal
		ns.db.goalProgress[g.id] = (ns.db.goalProgress[g.id] or 0) + 1
		ns:Sound(SOUNDKIT and SOUNDKIT.LOOT_WINDOW_COIN_SOUND or 120)
		if ns:GoalProgress(g) >= g.max then
			ns:Sound(SOUNDKIT and SOUNDKIT.ACHIEVEMENT_MENU_OPEN or 13832)
			UIErrorsFrame:AddMessage("Guild goal achieved: " .. g.title, 1, 0.82, 0)
			ns:Print("Guild goal achieved: |cffffd100%s|r! Reward: %s", g.title, g.reward)
		end
		ns:Fire("GOALS_CHANGED")
	end)
	W.Tooltip(c.btn, "Contribute", "Adds one point of progress toward this goal (demo - stored in your SavedVariables).")
	return c
end

local function fill(c, g)
	local cur = ns:GoalProgress(g)
	local done = cur >= g.max
	c.btn.goal, c.goal = g, g
	c.icon.icon:SetTexture(g.icon)
	c.icon.icon:SetDesaturated(false)
	c.check:SetShown(done)
	c.title:SetText(g.title)
	c.cat:SetText("|TInterface\\MoneyFrame\\UI-GoldIcon:0|t " .. g.reward)
	c.desc:SetText(g.desc)
	c.bar:SetProgress(cur, g.max, done and "Complete!" or nil)
	if done then c.btn:Disable() else c.btn:Enable() end
end

ns:RegisterPage({
	text = "Goals",
	icon = "Interface\\Icons\\INV_Misc_Note_02",
	tip = "Guild-wide objectives and their progress",
	build = function(page)
		local catItems = { { value = "ALL", text = "All categories", icon = "Interface\\Icons\\INV_Misc_Book_09" } }
		for _, c in ipairs(ns.GOAL_CATEGORIES) do catItems[#catItems + 1] = { value = c, text = c } end

		local label = W.Title(page, 15)
		label:SetPoint("TOPLEFT", 4, -6)
		label:SetText("Show:")
		local sel = W.Select(page, 180, catItems, function() page:Update() end)
		sel:SetPoint("LEFT", label, "RIGHT", 8, 0)
		local hide = W.Check(page, "Hide achieved goals", function() page:Update() end)
		hide:SetPoint("LEFT", sel, "RIGHT", 16, 0)

		local totalLabel = W.Title(page, 15)
		totalLabel:SetPoint("TOPRIGHT", -326, -6)
		totalLabel:SetText("Overall progress")
		local total = W.Progress(page, 310, 20)
		total:SetPoint("TOPRIGHT", -4, -2)

		local cards = {}
		for i = 1, #ns.GOALS do
			local c = makeCard(page)
			local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
			c:SetPoint("TOPLEFT", col * (CARD_W + 12), -38 - row * (CARD_H + 8))
			cards[i] = c
		end

		function page:Update()
			local cat, hideDone = sel:GetValue(), hide:GetChecked()
			local i, sum, max = 0, 0, 0
			for _, g in ipairs(ns.GOALS) do
				local cur = ns:GoalProgress(g)
				sum, max = sum + cur / g.max, max + 1
				if (cat == "ALL" or g.cat == cat) and not (hideDone and cur >= g.max) then
					i = i + 1
					fill(cards[i], g)
					cards[i]:Show()
				end
			end
			for j = i + 1, #cards do cards[j]:Hide() end
			total:SetProgress(sum, max, ("%d%%"):format(sum / max * 100))
		end
		ns:On("GOALS_CHANGED", function() if page:IsVisible() then page:Update() end end)
	end,
	onShow = function(page) page:Update() end,
})
