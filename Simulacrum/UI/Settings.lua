local _, ns = ...
local W = ns.W

StaticPopupDialogs["SIMULACRUM_RESET"] = {
	text = "Reset all Simulacrum data (interests, DKP edits, goal progress, applications) and reload the UI?",
	button1 = YES,
	button2 = NO,
	OnAccept = function() SimulacrumDB = nil; ReloadUI() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

ns:RegisterPage({
	text = "Settings",
	icon = "Interface\\Icons\\INV_Misc_Gear_01",
	tip = "Options and about",
	build = function(page)
		local box = W.Inset(page, 0.12)
		box:SetPoint("TOPLEFT")
		box:SetPoint("BOTTOMLEFT", 0, 2)
		box:SetWidth(440)
		local t = W.Title(box, 20)
		t:SetPoint("TOPLEFT", 16, -12)
		t:SetText("Options")
		local d = W.Divider(box, 260)
		d:SetPoint("TOP", 0, -40)

		local mm = W.Check(box, "Show minimap button", function(on)
			ns.db.minimap.hide = not on
			ns:Fire("MINIMAP_TOGGLED")
		end)
		mm:SetPoint("TOPLEFT", 16, -72)
		local snd = W.Check(box, "Play interface sounds", function(on) ns.db.sounds = on end)
		snd:SetPoint("TOPLEFT", mm, "BOTTOMLEFT", 0, -8)
		local bc = W.Check(box, "Share my loot interest with the guild", function(on) ns.db.broadcast = on end)
		bc:SetPoint("TOPLEFT", snd, "BOTTOMLEFT", 0, -8)

		local sl = W.Title(box, 14)
		sl:SetPoint("TOPLEFT", bc, "BOTTOMLEFT", 0, -20)
		sl:SetText("Window scale")
		local scale = W.Slider(box, 260, 0.6, 1.4, 0.05, nil, "%.2f")
		scale:SetPoint("TOPLEFT", sl, "BOTTOMLEFT", 4, -22)
		-- only apply on release so the window doesn't jump under the cursor while dragging
		scale:SetScript("OnMouseUp", function(self) ns:SetScale(math.floor(self:GetValue() * 20 + 0.5) / 20) end)

		local ml = W.Title(box, 14)
		ml:SetPoint("TOPLEFT", scale, "BOTTOMLEFT", -4, -26)
		ml:SetText("Message of the day override")
		local motd = W.EditBox(box, 400, "Leave empty to use the guild's MOTD")
		motd:SetPoint("TOPLEFT", ml, "BOTTOMLEFT", 0, -4)
		motd.edit:HookScript("OnTextChanged", function(e, user)
			if user then ns.db.motd = e:GetText() ~= "" and e:GetText() or nil end
		end)

		local resetPos = W.Button(box, "Reset window", 130, 26, function()
			SimulacrumFrame:ClearAllPoints()
			SimulacrumFrame:SetPoint("CENTER", 0, 30)
			ns:SetScale(1)
			scale:SetValue(1)
		end)
		resetPos:SetPoint("BOTTOMLEFT", 16, 16)
		local resetAll = W.Button(box, "Reset all data", 130, 26, function() StaticPopup_Show("SIMULACRUM_RESET") end)
		resetAll:SetPoint("LEFT", resetPos, "RIGHT", 8, 0)

		-- About ----------------------------------------------------------------
		local about = W.Dark(page, 0.75)
		about:SetPoint("TOPLEFT", box, "TOPRIGHT", 12, 0)
		about:SetPoint("BOTTOMRIGHT", 0, 2)
		local crest = about:CreateTexture(nil, "ARTWORK")
		crest:SetTexture(ns.media .. "icon")
		crest:SetSize(128, 128)
		crest:SetPoint("TOP", 0, -26)
		local rim = CreateFrame("Frame", nil, about)
		rim:SetAllPoints(crest)
		W.Outline(rim, 1, { 0, 0, 0, 1 })
		local name = W.GoldText(about, 30, W.FONT_TITLE)
		name:SetPoint("TOP", crest, "BOTTOM", 0, -16)
		name:SetText("Simulacrum")
		local ver = W.Text(about, 12, { 0.75, 0.68, 0.55 })
		ver:SetPoint("TOP", name, "BOTTOM", 0, -4)
		ver:SetText("Guild Companion  v" .. ns.version)
		local div = W.Divider(about, 360)
		div:SetPoint("TOP", ver, "BOTTOM", 0, -6)
		local body = W.Text(about, 12, W.C.white)
		body:SetPoint("TOP", div, "BOTTOM", 0, -8)
		body:SetWidth(390)
		body:SetJustifyH("CENTER")
		body:SetText(ns.MOTTO .. "\n\n"
			.. "A demonstration addon for World of Warcraft Forever: tabs, tables, lists, inputs, selects, text areas, "
			.. "sliders, progress bars, images, item icons with live tooltips and guild-synced loot interest.\n\n"
			.. "|cffe6c35cSlash commands|r\n/sim  -  toggle window\n/sim minimap  -  toggle minimap button\n/sim reset  -  wipe saved data\n\n"
			.. "|cff888888Artwork generated locally with Qwen-Image 2.1.|r")

		function page:Sync()
			mm:SetChecked(not ns.db.minimap.hide)
			snd:SetChecked(ns.db.sounds)
			bc:SetChecked(ns.db.broadcast)
			scale:SetValue(ns.db.scale or 1)
			motd:SetText(ns.db.motd or "")
		end
	end,
	onShow = function(page) page:Sync() end,
})
