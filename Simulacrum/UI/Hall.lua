local _, ns = ...
local W = ns.W

local BANNER_V = 342 / 512 -- banner.tga has the image in its top 342 rows

local function section(parent, title, width, height)
	local box = W.Inset(parent)
	box:SetSize(width, height)
	local t = W.Title(box, 17)
	t:SetPoint("TOPLEFT", 12, -10)
	t:SetText(title)
	local d = W.Divider(box, math.min(width - 40, 240))
	d:SetPoint("TOP", 0, -32)
	d:SetAlpha(0.8)
	return box
end

ns:RegisterPage({
	text = "Hall",
	icon = "Interface\\Icons\\INV_Misc_Book_11",
	tip = "Welcome, message of the day and guild chronicle",
	build = function(page)
		-- Banner image -------------------------------------------------------
		local banner = CreateFrame("Frame", nil, page, BackdropTemplateMixin and "BackdropTemplate")
		banner:SetPoint("TOPLEFT")
		banner:SetPoint("TOPRIGHT")
		banner:SetHeight(220)
		local img = banner:CreateTexture(nil, "ARTWORK")
		img:SetTexture(ns.media .. "banner")
		img:SetPoint("TOPLEFT", 5, -5)
		img:SetPoint("BOTTOMRIGHT", -5, 5)
		img:SetTexCoord(0, 1, 0.12 * BANNER_V, 0.86 * BANNER_V)
		W.GoldBorder(banner, 14)

		local band = banner:CreateTexture(nil, "OVERLAY")
		band:SetPoint("BOTTOMLEFT", 5, 5)
		band:SetPoint("BOTTOMRIGHT", -5, 5)
		band:SetHeight(34)
		W.Gradient(band, "VERTICAL", 0, 0, 0, 0.85, 0, 0, 0, 0)

		local welcome = W.GoldText(banner, 18, W.FONT_TITLE)
		welcome:SetPoint("BOTTOMLEFT", 16, 12)
		page.welcome = welcome

		local stats = W.GoldText(banner, 12)
		stats:SetPoint("BOTTOMRIGHT", -16, 14)
		stats:SetJustifyH("RIGHT")
		page.stats = stats

		local colW = 290
		-- Message of the day + motto ------------------------------------------
		local motd = section(page, "Message of the Day", colW, 248)
		motd:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -10)
		local seal = motd:CreateTexture(nil, "ARTWORK")
		seal:SetTexture("Interface\\Icons\\INV_Letter_15")
		seal:SetSize(34, 34)
		seal:SetPoint("TOPLEFT", 14, -58)
		local motdText = W.Text(motd, 13, W.C.ink)
		motdText:SetPoint("TOPLEFT", seal, "TOPRIGHT", 10, 0)
		motdText:SetPoint("RIGHT", -14, 0)
		page.motdText = motdText
		local motto = W.Text(motd, 12, W.C.inkSoft, W.FONT_TITLE)
		motto:SetPoint("BOTTOMLEFT", 14, 16)
		motto:SetPoint("RIGHT", -14, 0)
		motto:SetJustifyH("CENTER")
		motto:SetText(ns.MOTTO)

		-- Upcoming events -----------------------------------------------------
		local ev = section(page, "This Week", colW, 248)
		ev:SetPoint("TOPLEFT", motd, "TOPRIGHT", 9, 0)
		for i, e in ipairs(ns.EVENTS) do
			local row = CreateFrame("Frame", nil, ev)
			row:SetSize(colW - 28, 44)
			row:SetPoint("TOPLEFT", 14, -54 - (i - 1) * 46)
			local ic = W.Icon(row, 36, e.icon)
			ic:SetPoint("LEFT")
			local day = W.Title(row, 15)
			day:SetPoint("TOPLEFT", ic, "TOPRIGHT", 10, -2)
			day:SetText(e.name)
			local when = W.Text(row, 11, W.C.inkSoft)
			when:SetPoint("TOPLEFT", day, "BOTTOMLEFT", 0, -3)
			when:SetText(("%s  -  %s server time"):format(e.day, e.time))
		end

		-- Chronicle (news) ----------------------------------------------------
		local news = section(page, "Guild Chronicle", 908 - 2 * colW - 18, 248)
		news:SetPoint("TOPLEFT", ev, "TOPRIGHT", 9, 0)
		news:SetPoint("RIGHT", page, "RIGHT")
		for i, n in ipairs(ns.NEWS) do
			local ic = news:CreateTexture(nil, "ARTWORK")
			ic:SetTexture(n.icon)
			ic:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			ic:SetSize(22, 22)
			ic:SetPoint("TOPLEFT", 14, -58 - (i - 1) * 37)
			local t = W.Text(news, 11, W.C.ink)
			t:SetPoint("TOPLEFT", ic, "TOPRIGHT", 8, 1)
			t:SetPoint("RIGHT", news, "RIGHT", -10, 0)
			-- chronicle uses chat-style colour codes; darken by drawing on ink
			t:SetText(n.text)
			local ago = W.Text(news, 10, W.C.inkSoft)
			ago:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -2)
			ago:SetText(n.ago)
		end
	end,
	onShow = function(page)
		local online = 0
		for _, m in ipairs(ns.MEMBERS) do if m.online then online = online + 1 end end
		local done = 0
		for _, g in ipairs(ns.GOALS) do if ns:GoalProgress(g) >= g.max then done = done + 1 end end
		page.welcome:SetText(("Well met, %s!"):format(ns.FirstName(ns:PlayerName())))
		page.stats:SetText(("|cffffffff%d|r members  -  |cff3cd23c%d|r online  -  |cffffffff%d/%d|r guild goals achieved")
			:format(#ns.MEMBERS, online, done, #ns.GOALS))
		local live = IsInGuild() and GetGuildRosterMOTD and GetGuildRosterMOTD()
		page.motdText:SetText(ns.db.motd or (live and live ~= "" and live) or ns.MOTD)
	end,
})
