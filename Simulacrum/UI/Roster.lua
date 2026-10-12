local _, ns = ...
local W = ns.W

local function liveRoster()
	local rows = {}
	for i = 1, GetNumGuildMembers() do
		local name, rankName, rankIndex, level, _, zone, note, _, online, _, class = GetGuildRosterInfo(i)
		if name then
			name = ns.NormName(name)
			rows[#rows + 1] = { name = name, class = class, level = level, rank = rankIndex + 1, rankName = rankName,
				zone = zone or "", note = note or "", online = online, dkp = ns:GetDKP(name), live = true }
		end
	end
	return rows
end

local function demoRoster()
	local rows = {}
	for _, m in ipairs(ns.MEMBERS) do
		local r = CopyTable(m)
		r.dkp = ns:GetDKP(m.name)
		r.rankName = ns.RANKS[m.rank].name
		rows[#rows + 1] = r
	end
	return rows
end

ns:RegisterPage({
	text = "Roster",
	icon = "Interface\\Icons\\INV_Misc_GroupNeedMore",
	tip = "Members, ranks and status",
	build = function(page)
		-- Toolbar ------------------------------------------------------------
		local search = W.EditBox(page, 180, "Search name or zone...")
		search:SetPoint("TOPLEFT", 0, -2)
		local rankItems = { { value = 0, text = "All ranks" } }
		for i, r in ipairs(ns.RANKS) do rankItems[#rankItems + 1] = { value = i, text = r.name, icon = r.icon } end
		local rankSel = W.Select(page, 150, rankItems, function() page:Update() end)
		rankSel:SetPoint("LEFT", search, "RIGHT", 10, 0)
		local onlineOnly = W.Check(page, "Online only", function() page:Update() end)
		onlineOnly:SetPoint("LEFT", rankSel, "RIGHT", 12, 0)
		local live = W.Check(page, "Use my real guild", function(on)
			if on and C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
			page:Update()
		end)
		live:SetPoint("LEFT", onlineOnly, "RIGHT", 100, 0)
		W.Tooltip(live, "Live roster", "Reads your actual guild roster through the WoW API instead of the demo members.")
		search.edit:HookScript("OnTextChanged", function() page:Update() end)

		local count = W.Text(page, 11, W.C.inkSoft)
		count:SetPoint("TOPRIGHT", -4, -9)
		count:SetJustifyH("RIGHT")

		-- Table --------------------------------------------------------------
		local tbl = W.Table(page, 596, 444, {
			{ key = "name", title = "Name", width = 150,
				icon = function(r) return W.ClassIcon(r.class) end,
				fmt = function(r) return r.name, W.ClassColor(r.class) end },
			{ key = "level", title = "Lvl", width = 40, align = "CENTER" },
			{ key = "rank", title = "Rank", width = 116, fmt = function(r) return r.rankName end },
			{ key = "zone", title = "Zone", width = 150, fmt = function(r)
				if r.online then return r.zone end
				return r.zone, 0.55, 0.55, 0.55
			end },
			{ key = "dkp", title = "DKP", width = 56, align = "RIGHT", fmt = function(r) return tostring(r.dkp), 1, 0.82, 0.2 end },
			{ key = "online", title = "", width = 60, align = "CENTER", fmt = function(r)
				if r.online then return "|TInterface\\FriendsFrame\\StatusIcon-Online:12|t" end
				return r.lastSeen and r.lastSeen > 0 and (r.lastSeen .. "d") or "-", 0.55, 0.55, 0.55
			end },
		}, function(row) page:ShowDetails(row) end)
		tbl:SetPoint("TOPLEFT", 0, -36)
		tbl.sortKey = "rank"

		-- Details panel --------------------------------------------------------
		local d = W.Inset(page, 0.12)
		d:SetPoint("TOPLEFT", tbl, "TOPRIGHT", 12, 0)
		d:SetPoint("BOTTOMRIGHT", 0, 2)
		local portrait = d:CreateTexture(nil, "ARTWORK")
		portrait:SetSize(72, 72)
		portrait:SetPoint("TOP", 0, -18)
		local ring = d:CreateTexture(nil, "OVERLAY")
		ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
		ring:SetSize(132, 132)
		ring:SetPoint("TOPLEFT", portrait, "TOPLEFT", -10, 10)
		local name = W.Title(d, 22)
		name:SetPoint("TOP", portrait, "BOTTOM", 0, -12)
		name:SetJustifyH("CENTER")
		local sub = W.Text(d, 12, W.C.inkSoft)
		sub:SetPoint("TOP", name, "BOTTOM", 0, -4)
		sub:SetJustifyH("CENTER")
		local div = W.Divider(d, 250)
		div:SetPoint("TOP", sub, "BOTTOM", 0, -6)

		local fields = {}
		for i, key in ipairs({ "Rank", "Zone", "DKP", "Status", "Note" }) do
			local l = W.Title(d, 14)
			l:SetPoint("TOPLEFT", 20, -212 - (i - 1) * 30)
			l:SetText(key)
			local v = W.Text(d, 12, W.C.ink)
			v:SetPoint("TOPLEFT", l, "TOPLEFT", 70, -1)
			v:SetPoint("RIGHT", d, "RIGHT", -14, 0)
			fields[key] = v
		end

		local whisper = W.Button(d, "Whisper", 118, 26, function()
			if page.current then ChatFrame_OpenChat("/w " .. page.current.name .. " ") end
		end)
		whisper:SetPoint("BOTTOMLEFT", 16, 16)
		local invite = W.Button(d, "Invite", 118, 26, function()
			if not page.current then return end
			local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
			if page.current.live then invite(page.current.name)
			else ns:Print("%s is a demo member - in a real guild this would invite them.", page.current.name) end
		end)
		invite:SetPoint("BOTTOMRIGHT", -16, 16)

		function page:ShowDetails(r)
			self.current = r
			if not r then return end
			portrait:SetTexture(W.ClassIcon(r.class))
			portrait:SetTexCoord(select(2, W.ClassIcon(r.class)))
			name:SetText(r.name)
			name:SetTextColor(W.ClassColor(r.class))
			local cls = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[r.class]) or r.class
			sub:SetText(("Level %d %s"):format(r.level, cls))
			local rk = ns.RANKS[r.rank]
			fields.Rank:SetText((rk and ("|T%s:14|t "):format(rk.icon) or "") .. (r.rankName or ""))
			fields.Zone:SetText(r.zone)
			fields.DKP:SetText(r.dkp)
			fields.Status:SetText(r.online and "|cff1a8a1aOnline|r" or ("|cff8a1a1aOffline|r" .. (r.lastSeen and r.lastSeen > 0 and (" (" .. r.lastSeen .. " days)") or "")))
			fields.Note:SetText(r.note ~= "" and r.note or "|cff8a7a60-|r")
		end

		function page:Update()
			local rows = (live:GetChecked() and IsInGuild()) and liveRoster() or demoRoster()
			local q = search:GetText():lower()
			local rank, onlineOnlyOn = rankSel:GetValue(), onlineOnly:GetChecked()
			local out = {}
			for _, r in ipairs(rows) do
				if (q == "" or r.name:lower():find(q, 1, true) or r.zone:lower():find(q, 1, true))
					and (rank == 0 or r.rank == rank) and (not onlineOnlyOn or r.online) then
					out[#out + 1] = r
				end
			end
			count:SetText(("%d of %d members"):format(#out, #rows))
			tbl:SetData(out)
			if not self.current or self.current.live ~= (rows[1] and rows[1].live) then
				tbl.selected = out[1]
				tbl:Refresh()
				self:ShowDetails(out[1])
			end
		end

		ns:On("GUILD_ROSTER", function() if page:IsVisible() and live:GetChecked() then page:Update() end end)
		ns:On("DKP_CHANGED", function() if page:IsVisible() then page:Update() end end)
	end,
	onShow = function(page) page:Update() end,
})
