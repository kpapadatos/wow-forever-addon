local _, ns = ...
local W = ns.W

ns.pages = {}

-- Each UI\*.lua file registers a page: { text, icon, tip, build(page), onShow(page) }
function ns:RegisterPage(def)
	table.insert(self.pages, def)
end

local WIDTH, HEIGHT = 960, 640
local frame, tabs

local function build()
	frame = W.Parchment(UIParent, "SimulacrumFrame")
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER", 0, 30)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetScale(ns.db.scale or 1)
	frame:Hide()
	tinsert(UISpecialFrames, "SimulacrumFrame") -- Escape closes it
	frame:SetScript("OnShow", function() ns:Sound(SOUNDKIT and SOUNDKIT.IG_SPELLBOOK_OPEN or 829) end)
	frame:SetScript("OnHide", function() W.ClosePopups(); ns:Sound(SOUNDKIT and SOUNDKIT.IG_SPELLBOOK_CLOSE or 830) end)

	-- Header band -----------------------------------------------------------
	local header = CreateFrame("Frame", nil, frame)
	header:SetPoint("TOPLEFT", 10, -10)
	header:SetPoint("TOPRIGHT", -10, -10)
	header:SetHeight(64)
	local hbg = header:CreateTexture(nil, "BACKGROUND")
	hbg:SetAllPoints()
	W.Gradient(hbg, "VERTICAL", 0.10, 0.06, 0.03, 0.95, 0.03, 0.02, 0.06, 0.95)
	-- a slice of the banner's sky, faded, behind the title
	local sky = header:CreateTexture(nil, "BACKGROUND", nil, 1)
	sky:SetTexture(ns.media .. "banner")
	sky:SetTexCoord(0.25, 0.75, 0.05 * 0.668, 0.25 * 0.668)
	sky:SetPoint("TOPLEFT", 120, 0)
	sky:SetPoint("BOTTOMRIGHT", -120, 0)
	sky:SetAlpha(0.35)

	local crest = header:CreateTexture(nil, "ARTWORK")
	crest:SetTexture(ns.media .. "icon")
	crest:SetSize(52, 52)
	crest:SetPoint("LEFT", 18, 0)
	local crestRim = CreateFrame("Frame", nil, header, BackdropTemplateMixin and "BackdropTemplate")
	crestRim:SetPoint("TOPLEFT", crest, -4, 4)
	crestRim:SetPoint("BOTTOMRIGHT", crest, 4, -4)
	W.GoldBorder(crestRim, 12)

	local title = W.GoldText(header, 34, W.FONT_TITLE)
	title:SetPoint("LEFT", crest, "RIGHT", 16, 4)
	title:SetText("Simulacrum")
	local sub = W.Text(header, 11, { 0.75, 0.68, 0.55 })
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 2, -1)
	sub:SetText("Guild Companion  -  World of Warcraft Forever")

	local who = W.GoldText(header, 12)
	who:SetPoint("RIGHT", -44, 8)
	who:SetJustifyH("RIGHT")
	local whoSub = W.Text(header, 11, { 0.75, 0.68, 0.55 })
	whoSub:SetPoint("TOPRIGHT", who, "BOTTOMRIGHT", 0, -3)
	whoSub:SetJustifyH("RIGHT")
	frame.who, frame.whoSub = who, whoSub

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -8, -8)
	close:SetFrameLevel(header:GetFrameLevel() + 5)


	-- Tabs ------------------------------------------------------------------
	local tabBar = CreateFrame("Frame", nil, frame)
	tabBar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 14, -40)
	tabBar:SetSize(WIDTH - 40, 1)

	local content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", 26, -122)
	content:SetPoint("BOTTOMRIGHT", -26, 40)
	frame.content = content

	-- tab underline
	local underline = frame:CreateTexture(nil, "ARTWORK")
	underline:SetTexture(ns.media .. "white")
	underline:SetVertexColor(0.55, 0.38, 0.14, 0.9)
	underline:SetHeight(2)
	underline:SetPoint("TOPLEFT", tabBar, "TOPLEFT", -4, 0)
	underline:SetPoint("RIGHT", frame, "RIGHT", -24, 0)

	local defs = {}
	for i, p in ipairs(ns.pages) do
		defs[i] = { text = p.text, icon = p.icon, tip = p.tip }
		local page = CreateFrame("Frame", nil, content)
		page:SetAllPoints()
		page:Hide()
		p.frame = page
	end

	tabs = W.Tabs(tabBar, defs, function(i)
		W.ClosePopups()
		for j, p in ipairs(ns.pages) do
			if j == i then
				if not p.built then p.build(p.frame); p.built = true end
				p.frame:Show()
				if p.onShow then p.onShow(p.frame) end
			else
				p.frame:Hide()
			end
		end
		ns.db.lastTab = i
	end)

	-- Footer ----------------------------------------------------------------
	local foot = W.Text(frame, 10, W.C.inkSoft)
	foot:SetPoint("BOTTOMLEFT", 32, 24)
	foot:SetText(("v%s  -  /sim to toggle  -  drag the header to move"):format(ns.version))
	local foot2 = W.Text(frame, 10, W.C.inkSoft)
	foot2:SetPoint("BOTTOMRIGHT", -32, 24)
	foot2:SetJustifyH("RIGHT")
	foot2:SetText("For the glory of <Simulacrum>")

	W.Corners(frame, 96, -10)
end

local function updateWho()
	local name = ns:PlayerName()
	local guild, rank = GetGuildInfo("player")
	local m = ns:GetMember(name)
	frame.who:SetText(("%s  |cffffffff%d DKP|r"):format(name, ns:GetDKP(name)))
	if guild then
		frame.whoSub:SetText(("<%s>  %s"):format(guild, rank or ""))
	else
		frame.whoSub:SetText(m and ns.RANKS[m.rank].name or "Honorary guest of <Simulacrum>")
	end
end

function ns:Toggle(tab)
	if not frame then build() end
	if frame:IsShown() and not tab then
		frame:Hide()
		return
	end
	frame:Show()
	updateWho()
	tabs:Select(tab or ns.db.lastTab or 1, true)
end

function ns:SetScale(s)
	ns.db.scale = s
	if frame then frame:SetScale(s) end
end

ns:On("DKP_CHANGED", function() if frame and frame:IsShown() then updateWho() end end)
