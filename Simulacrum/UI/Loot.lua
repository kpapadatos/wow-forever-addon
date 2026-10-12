local _, ns = ...
local W = ns.W

local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
local WISHLIST = "__wishlist"

local function itemSubtitle(id)
	local _, itemType, subType, equipLoc = GetItemInfoInstant(id)
	local slot = equipLoc and equipLoc ~= "" and _G[equipLoc]
	if slot and subType and subType ~= "" and subType ~= "Miscellaneous" then return slot .. ", " .. subType end
	return slot or subType or itemType or ""
end

local function interestSummary(id)
	local who = ns:GetInterest(id)
	if not who then return "" end
	local parts = {}
	for _, kind in ipairs({ "need", "greed", "offspec" }) do
		local n = 0
		for _, k in pairs(who) do if k == kind then n = n + 1 end end
		if n > 0 then parts[#parts + 1] = ("|c%s%d %s|r"):format(ns.INTEREST[kind].color, n, ns.INTEREST[kind].text) end
	end
	return table.concat(parts, "  ")
end

local function makeItemRow(parent)
	local r = CreateFrame("Frame", nil, parent)
	r:SetHeight(38)
	local bg = r:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(1, 0.85, 0.6, 0.04)
	r.btn = W.ItemButton(r, 32)
	r.btn:SetPoint("LEFT", 4, 0)
	r.btn:SetScript("OnClick", function(self)
		if W.HandleItemModifiedClick(self.itemID) then return end
		ns:SetInterest(self.itemID, ns:PlayerName(), ns:MyInterest(self.itemID) ~= "need" and "need" or nil)
		ns:Sound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
	end)
	r.name = W.Text(r, 13, W.C.white)
	r.name:SetPoint("TOPLEFT", r.btn, "TOPRIGHT", 10, -1)
	r.name:SetWidth(200)
	r.name:SetWordWrap(false)
	r.sub = W.Text(r, 11, { 0.65, 0.6, 0.5 })
	r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
	r.sub:SetWidth(200)
	r.sub:SetWordWrap(false)
	r.summary = W.Text(r, 11, W.C.white)
	r.summary:SetPoint("LEFT", 256, 0)
	r.summary:SetWidth(124)

	r.kinds = {}
	local prev
	for i, kind in ipairs({ "offspec", "greed", "need" }) do
		local def = ns.INTEREST[kind]
		local b = CreateFrame("Button", nil, r)
		b:SetSize(26, 26)
		if prev then b:SetPoint("RIGHT", prev, "LEFT", -2, 0) else b:SetPoint("RIGHT", -6, 0) end
		b:SetNormalTexture(def.icon)
		b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		local glow = b:CreateTexture(nil, "OVERLAY")
		glow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
		glow:SetBlendMode("ADD")
		glow:SetAllPoints()
		b.glow = glow
		b:SetScript("OnClick", function()
			local cur = ns:MyInterest(r.itemID)
			ns:SetInterest(r.itemID, ns:PlayerName(), cur ~= kind and kind or nil)
			ns:Sound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
		end)
		W.Tooltip(b, ("|c%s%s|r"):format(def.color, def.text), "Declare " .. def.text:lower() .. " interest in this item. Guild members running Simulacrum will see it.")
		r.kinds[kind] = b
		prev = b
	end

	function r:SetItem(id)
		self.itemID = id
		self.btn:SetItem(id)
		local name, _, quality = ns:ItemData(id)
		if name then
			self.name:SetText(name)
			self.name:SetTextColor(W.QualityColor(quality or 1))
		else
			self.name:SetText("Retrieving item " .. id .. "...")
			self.name:SetTextColor(0.6, 0.6, 0.6)
		end
		self.sub:SetText(itemSubtitle(id))
		self.summary:SetText(interestSummary(id))
		local mine = ns:MyInterest(id)
		for kind, b in pairs(self.kinds) do
			b.glow:SetShown(mine == kind)
			b:GetNormalTexture():SetDesaturated(mine ~= nil and mine ~= kind)
			b:SetAlpha((mine == nil or mine == kind) and 1 or 0.5)
		end
	end
	return r
end

ns:RegisterPage({
	text = "Loot",
	icon = "Interface\\Icons\\INV_Box_01",
	tip = "Browse dungeon drops and declare interest - like AtlasLoot, with your guild",
	build = function(page)
		-- seed interest for demo (only fills items nobody has touched yet)
		for id, who in pairs(ns.SEED_INTEREST) do
			if not ns.db.interests[id] then ns.db.interests[id] = CopyTable(who) end
		end

		-- Dungeon list with thumbnails ------------------------------------------
		local dl = CreateFrame("Frame", nil, page)
		dl:SetPoint("TOPLEFT")
		dl:SetSize(210, 480)
		local dButtons = {}
		for i, d in ipairs(ns.DUNGEONS) do
			local b = CreateFrame("Button", nil, dl, BackdropTemplateMixin and "BackdropTemplate")
			b:SetSize(210, 72)
			b:SetPoint("TOPLEFT", 0, -(i - 1) * 78)
			local img = b:CreateTexture(nil, "ARTWORK")
			img:SetTexture(ns.media .. "dungeon_" .. d.image)
			img:SetTexCoord(0, 1, 0.22, 0.78)
			img:SetPoint("TOPLEFT", 4, -4)
			img:SetPoint("BOTTOMRIGHT", -4, 4)
			b.img = img
			local shade = b:CreateTexture(nil, "ARTWORK", nil, 1)
			shade:SetPoint("BOTTOMLEFT", img)
			shade:SetPoint("BOTTOMRIGHT", img)
			shade:SetHeight(34)
			W.Gradient(shade, "VERTICAL", 0, 0, 0, 0.9, 0, 0, 0, 0)
			local n = W.GoldText(b, 15, W.FONT_TITLE)
			n:SetPoint("BOTTOMLEFT", 10, 18)
			n:SetText(d.name)
			local lv = W.Text(b, 10, { 0.85, 0.8, 0.7 })
			lv:SetPoint("BOTTOMLEFT", 10, 7)
			lv:SetText(("Level %s  -  %d players%s"):format(d.level, d.size, d.forever and "  -  |cff66ccffForever|r" or ""))
			W.GoldBorder(b, 12)
			local hl = b:CreateTexture(nil, "HIGHLIGHT")
			hl:SetAllPoints(img)
			hl:SetColorTexture(1, 0.85, 0.4, 0.15)
			b:SetScript("OnClick", function() page:SelectDungeon(i) end)
			dButtons[i] = b
		end

		-- Dungeon header ---------------------------------------------------------
		local head = CreateFrame("Frame", nil, page, BackdropTemplateMixin and "BackdropTemplate")
		head:SetPoint("TOPLEFT", dl, "TOPRIGHT", 12, 0)
		head:SetPoint("RIGHT")
		head:SetHeight(124)
		local himg = head:CreateTexture(nil, "ARTWORK")
		himg:SetPoint("TOPLEFT", 5, -5)
		himg:SetPoint("BOTTOMRIGHT", -5, 5)
		local hshade = head:CreateTexture(nil, "ARTWORK", nil, 1)
		hshade:SetPoint("TOPLEFT", himg)
		hshade:SetPoint("BOTTOMLEFT", himg)
		hshade:SetWidth(420)
		W.Gradient(hshade, "HORIZONTAL", 0, 0, 0, 0.85, 0, 0, 0, 0)
		W.GoldBorder(head, 14)
		local hname = W.GoldText(head, 26, W.FONT_TITLE)
		hname:SetPoint("TOPLEFT", 18, -16)
		local hlvl = W.Text(head, 11, { 0.9, 0.85, 0.7 })
		hlvl:SetPoint("TOPLEFT", hname, "BOTTOMLEFT", 2, -2)
		local hlore = W.Text(head, 12, W.C.white)
		hlore:SetPoint("TOPLEFT", hlvl, "BOTTOMLEFT", 0, -8)
		hlore:SetWidth(380)

		-- Boss list -----------------------------------------------------------
		local bossBox = W.Inset(page, 0.12)
		bossBox:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -10)
		bossBox:SetPoint("BOTTOMLEFT", dl, "BOTTOMRIGHT", 12, 2)
		bossBox:SetWidth(176)
		local bossButtons = {}
		local function bossButton(i)
			local b = bossButtons[i]
			if b then return b end
			b = CreateFrame("Button", nil, bossBox)
			b:SetSize(164, 30)
			b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 31)
			b.sel = b:CreateTexture(nil, "BACKGROUND")
			b.sel:SetAllPoints()
			W.Gradient(b.sel, "HORIZONTAL", 0.6, 0.35, 0.08, 0.45, 0.6, 0.35, 0.08, 0)
			b.skull = b:CreateTexture(nil, "ARTWORK")
			b.skull:SetSize(18, 18)
			b.skull:SetPoint("LEFT", 4, 0)
			b.fs = W.Title(b, 14)
			b.fs:SetPoint("LEFT", 26, 0)
			b.fs:SetPoint("RIGHT", -2, 0)
			b.fs:SetWordWrap(false)
			b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
			b:SetScript("OnClick", function(self) page:SelectBoss(self.key) end)
			bossButtons[i] = b
			return b
		end

		-- Item list -------------------------------------------------------------
		local itemsBox = W.Dark(page, 0.75)
		itemsBox:SetPoint("TOPLEFT", bossBox, "TOPRIGHT", 10, 0)
		itemsBox:SetPoint("BOTTOMRIGHT", 0, 2)
		local itemTitle = W.GoldText(itemsBox, 16, W.FONT_TITLE)
		itemTitle:SetPoint("TOPLEFT", 12, -9)
		local legend = W.Text(itemsBox, 10, { 0.65, 0.6, 0.5 })
		legend:SetPoint("TOPRIGHT", -10, -12)
		legend:SetJustifyH("RIGHT")
		legend:SetText("|cff3cd23cNeed|r / |cffffd100Greed|r / |cff7fb2ffOff-spec|r")

		local list = W.ScrollList(itemsBox, 488, 304, 38, function(owner) return makeItemRow(owner) end,
			function(r, id) r:SetItem(id) end)
		list:SetPoint("TOPLEFT", 6, -32)
		local empty = W.Text(itemsBox, 12, { 0.65, 0.6, 0.5 })
		empty:SetPoint("CENTER", 0, -10)
		empty:SetJustifyH("CENTER")
		empty:SetText("Your wishlist is empty.\nDeclare interest on any item to add it here.")

		function page:SelectBoss(key)
			self.boss = key
			local d = ns.DUNGEONS[self.dungeon]
			local items
			if key == WISHLIST then
				items = {}
				for id, who in pairs(ns.db.interests) do if who[ns:PlayerName()] then items[#items + 1] = id end end
				table.sort(items)
				itemTitle:SetText("My Wishlist")
			else
				items = d.bosses[key].items
				itemTitle:SetText(d.bosses[key].name)
			end
			empty:SetShown(key == WISHLIST and #items == 0)
			for _, b in ipairs(bossButtons) do b.sel:SetShown(b.key == key) end
			list.offset = 0
			list:SetData(items)
		end

		function page:SelectDungeon(i)
			self.dungeon = i
			local d = ns.DUNGEONS[i]
			for j, b in ipairs(dButtons) do
				local v = j == i and 1 or 0.5
				b.img:SetVertexColor(v, v, v)
				b:SetBackdropBorderColor(1, 1, 1, j == i and 1 or 0.55)
			end
			himg:SetTexture(ns.media .. "dungeon_" .. d.image)
			himg:SetTexCoord(0, 1, 0.30, 0.66)
			hname:SetText(d.name)
			hlvl:SetText(("Level %s  -  %d-player %s"):format(d.level, d.size, d.size > 5 and "raid" or "dungeon"))
			hlore:SetText(d.lore)
			local n = 0
			for bi, boss in ipairs(d.bosses) do
				n = bi
				local b = bossButton(bi)
				b.key = bi
				b.fs:SetText(boss.name)
				b.skull:SetTexture(boss.name == "Trash" and "Interface\\Icons\\INV_Misc_Bone_01" or "Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
				b.skull:SetTexCoord(0, 1, 0, 1)
				b:Show()
			end
			local wl = bossButton(n + 1)
			wl.key = WISHLIST
			wl.fs:SetText("|cff3cd23cMy Wishlist|r")
			wl.skull:SetTexture("Interface\\Icons\\INV_Misc_Note_04")
			wl.skull:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			wl:Show()
			for j = n + 2, #bossButtons do bossButtons[j]:Hide() end
			self:SelectBoss(1)
			ns:Sound(SOUNDKIT and SOUNDKIT.IG_QUEST_LOG_OPEN or 844)
		end

		local function refresh()
			if page:IsVisible() then
				if page.boss == WISHLIST then page:SelectBoss(WISHLIST) else list:Refresh() end
			end
		end
		ns:On("INTEREST_CHANGED", refresh)
		-- item names arrive asynchronously from the server; repaint when they do
		local pending
		ns:On("ITEM_INFO", function()
			if pending or not page:IsVisible() then return end
			pending = true
			C_Timer.After(0.1, function() pending = false; list:Refresh() end)
		end)
		page:SelectDungeon(1)
	end,
})
