local _, ns = ...

-- ===========================================================================
-- Themed widget kit: parchment, gold, dark leather.
-- Everything is built from plain frames + a few vanilla-era Blizzard textures
-- so it does not depend on newer FrameXML templates.
-- ===========================================================================
local W = {}
ns.W = W

local M = ns.media
W.FONT_TITLE = "Fonts\\MORPHEUS.TTF"
W.FONT_BODY = "Fonts\\FRIZQT__.TTF"

W.C = {
	ink = { 0.23, 0.13, 0.05 },
	inkSoft = { 0.42, 0.29, 0.15 },
	gold = { 1.0, 0.82, 0.38 },
	goldDim = { 0.78, 0.62, 0.30 },
	white = { 0.96, 0.93, 0.85 },
	red = { 0.75, 0.12, 0.08 },
	green = { 0.15, 0.55, 0.12 },
}

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local function unpackc(c, a) return c[1], c[2], c[3], a or 1 end

function W.Gradient(tex, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
	tex:SetTexture(M .. "white")
	if CreateColor and pcall(tex.SetGradient, tex, orientation, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2)) then
		return
	end
	if tex.SetGradientAlpha then
		tex:SetGradientAlpha(orientation, r1, g1, b1, a1, r2, g2, b2, a2)
	else
		tex:SetVertexColor(r1, g1, b1, a1)
	end
end

function W.Backdrop(frame, bd, bg, border)
	if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
	frame:SetBackdrop(bd)
	if bg then frame:SetBackdropColor(unpack(bg)) end
	if border then frame:SetBackdropBorderColor(unpack(border)) end
end

function W.Text(parent, size, color, font, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	fs:SetFont(font or W.FONT_BODY, size or 12, "")
	fs:SetTextColor(unpackc(color or W.C.ink))
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(true)
	return fs
end

function W.Title(parent, size, color)
	local fs = W.Text(parent, size or 20, color or W.C.ink, W.FONT_TITLE)
	fs:SetShadowColor(0, 0, 0, 0)
	return fs
end

-- gold text with a dark shadow, for use on dark surfaces
function W.GoldText(parent, size, font)
	local fs = W.Text(parent, size, W.C.gold, font)
	fs:SetFont(font or W.FONT_BODY, size or 12, "")
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
	return fs
end

-- ---------------------------------------------------------------------------
-- Frames
-- ---------------------------------------------------------------------------

-- Crisp outline drawn with four solid textures (no backdrop edge art).
-- Returns the outline so its colour can be changed later with :SetColor().
local OUTLINE = { 0.16, 0.10, 0.04, 1 }

function W.Outline(frame, thickness, color)
	thickness = thickness or 1
	local o, edges = {}, {}
	for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local t = frame:CreateTexture(nil, "OVERLAY", nil, 6)
		t:SetTexture(M .. "white")
		if side == "TOP" or side == "BOTTOM" then
			t:SetPoint(side .. "LEFT")
			t:SetPoint(side .. "RIGHT")
			t:SetHeight(thickness)
		else
			t:SetPoint("TOP" .. side)
			t:SetPoint("BOTTOM" .. side)
			t:SetWidth(thickness)
		end
		edges[#edges + 1] = t
	end
	function o:SetColor(r, g, b, a)
		for _, t in ipairs(edges) do t:SetVertexColor(r, g, b, a or 1) end
	end
	o:SetColor(unpack(color or OUTLINE))
	frame.outline = o
	return o
end

local CORNER_COORDS = {
	TOPLEFT = { 0, 1, 0, 1 }, TOPRIGHT = { 1, 0, 0, 1 },
	BOTTOMLEFT = { 0, 1, 1, 0 }, BOTTOMRIGHT = { 1, 0, 1, 0 },
}

function W.Corners(frame, size, offset)
	size, offset = size or 80, offset or -6
	for point, tc in pairs(CORNER_COORDS) do
		local t = frame:CreateTexture(nil, "OVERLAY", nil, 7)
		t:SetTexture(M .. "corner")
		t:SetTexCoord(unpack(tc))
		t:SetSize(size, size)
		local x = point:find("LEFT") and offset or -offset
		local y = point:find("TOP") and -offset or offset
		t:SetPoint(point, frame, point, x, y)
	end
end

-- Parchment panel with gold rim and filigree corners
function W.Parchment(parent, name)
	local f = CreateFrame("Frame", name, parent, BACKDROP_TEMPLATE)
	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(M .. "parchment")
	bg:SetPoint("TOPLEFT", 10, -10)
	bg:SetPoint("BOTTOMRIGHT", -10, 10)
	f.bg = bg
	-- classic dialog border, tinted towards gold
	W.Backdrop(f, { edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32 }, nil, { 1, 0.86, 0.55, 1 })
	return f
end

-- Subtle sunken area drawn on top of parchment
function W.Inset(parent, alpha)
	local f = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
	W.Backdrop(f, { bgFile = M .. "white", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 } }, { 0.35, 0.22, 0.08, alpha or 0.10 }, { 0.45, 0.30, 0.12, 0.9 })
	return f
end

-- Dark leather/stone panel (used for headers, item grids, inputs)
function W.Dark(parent, alpha)
	local f = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
	W.Backdrop(f, { bgFile = M .. "white", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 } }, { 0.07, 0.05, 0.03, alpha or 0.88 }, { 0.80, 0.62, 0.28, 1 })
	return f
end

function W.Divider(parent, width)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetTexture(M .. "divider")
	t:SetTexCoord(0, 1, 0.15, 0.85)
	t:SetSize(width or 360, (width or 360) / 11.4)
	return t
end

function W.Icon(parent, size, texture)
	local f = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
	f:SetSize(size, size)
	local t = f:CreateTexture(nil, "ARTWORK")
	t:SetPoint("TOPLEFT", 2, -2)
	t:SetPoint("BOTTOMRIGHT", -2, 2)
	t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	t:SetTexture(texture)
	f.icon = t
	W.Backdrop(f, { edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 }, nil, { 0.85, 0.68, 0.30, 1 })
	return f
end

-- Generic tooltip helper
function W.Tooltip(frame, title, ...)
	local lines = { ... }
	frame:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(type(title) == "function" and title(self) or title, 1, 0.82, 0)
		for _, l in ipairs(lines) do GameTooltip:AddLine(l, 1, 1, 1, true) end
		GameTooltip:Show()
	end)
	frame:HookScript("OnLeave", GameTooltip_Hide)
end

-- ---------------------------------------------------------------------------
-- Button
-- ---------------------------------------------------------------------------
function W.Button(parent, text, width, height, onClick)
	-- the game's own red panel button (gold text, red background)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width or 120, height or 24)
	b:SetText(text)
	b.text = b:GetFontString()
	b:SetScript("OnClick", function(self, ...)
		ns:Sound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION or 852)
		if onClick then onClick(self, ...) end
	end)
	return b
end

-- ---------------------------------------------------------------------------
-- Small square icon button (used in toolbars)
function W.IconButton(parent, size, texture, tip, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	b:SetNormalTexture(texture)
	b:GetNormalTexture():SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	b:SetPushedTexture(texture)
	b:GetPushedTexture():SetTexCoord(0.1, 0.96, 0.1, 0.96)
	b:SetScript("OnClick", onClick)
	if tip then W.Tooltip(b, tip) end
	return b
end

-- ---------------------------------------------------------------------------
-- Tab group
-- ---------------------------------------------------------------------------
function W.Tabs(parent, defs, onSelect)
	local group = { buttons = {}, selected = nil }
	local prev
	for i, def in ipairs(defs) do
		-- flat tab: plain fill, a thin accent line on top of the selected one, no border
		local b = CreateFrame("Button", nil, parent)
		b:SetHeight(28)
		local bg = b:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		b.bg = bg
		local accent = b:CreateTexture(nil, "BORDER")
		accent:SetPoint("TOPLEFT")
		accent:SetPoint("TOPRIGHT")
		accent:SetHeight(2)
		accent:SetColorTexture(0.78, 0.55, 0.18, 1)
		b.accent = accent

		local icon = b:CreateTexture(nil, "ARTWORK")
		icon:SetSize(18, 18)
		icon:SetPoint("LEFT", 9, 0)
		icon:SetTexture(def.icon)
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		local fs = W.GoldText(b, 13, W.FONT_TITLE)
		fs:SetPoint("LEFT", icon, "RIGHT", 6, 0)
		fs:SetText(def.text)
		b:SetWidth(fs:GetStringWidth() + 44)
		b.fs, b.icon = fs, icon

		local hl = b:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints(bg)
		hl:SetColorTexture(1, 0.85, 0.5, 0.12)
		hl:SetBlendMode("ADD")

		-- bottom-aligned so the selected (taller) tab grows upwards without shifting the row
		if prev then b:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", 3, 0) else b:SetPoint("BOTTOMLEFT", 0, 0) end
		prev = b
		b:SetScript("OnClick", function() group:Select(i) end)
		if def.tip then W.Tooltip(b, def.text, def.tip) end
		group.buttons[i] = b
	end

	function group:Select(i, silent)
		self.selected = i
		for j, b in ipairs(self.buttons) do
			if j == i then
				b.bg:SetColorTexture(0.85, 0.74, 0.55, 1)
				b.accent:Show()
				b.fs:SetTextColor(unpackc(W.C.ink))
				b.fs:SetShadowColor(0, 0, 0, 0)
				b.icon:SetDesaturated(false)
				b:SetHeight(32)
			else
				b.bg:SetColorTexture(0.20, 0.13, 0.07, 0.92)
				b.accent:Hide()
				b.fs:SetTextColor(unpackc(W.C.goldDim))
				b.fs:SetShadowColor(0, 0, 0, 1)
				b.icon:SetDesaturated(true)
				b:SetHeight(28)
			end
		end
		if not silent then ns:Sound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB or 841) end
		onSelect(i)
	end

	return group
end

-- ---------------------------------------------------------------------------
-- Inputs
-- ---------------------------------------------------------------------------
local INPUT_BD = { bgFile = M .. "white", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 } }

local function focusGlow(box, frame)
	box:HookScript("OnEditFocusGained", function() frame:SetBackdropBorderColor(1, 0.85, 0.35, 1) end)
	box:HookScript("OnEditFocusLost", function() frame:SetBackdropBorderColor(0.6, 0.45, 0.2, 1) end)
end

local function addPlaceholder(box, text)
	local ph = W.Text(box, 12, { 0.55, 0.5, 0.42 })
	ph:SetFont(W.FONT_BODY, 12, "")
	ph:SetPoint("TOPLEFT", 1, 0)
	ph:SetText(text)
	local function upd() ph:SetShown(box:GetText() == "" and not box:HasFocus()) end
	box:HookScript("OnTextChanged", upd)
	box:HookScript("OnEditFocusGained", upd)
	box:HookScript("OnEditFocusLost", upd)
	box.placeholder = ph
end

function W.EditBox(parent, width, placeholder, numeric)
	local f = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
	f:SetSize(width or 200, 26)
	W.Backdrop(f, INPUT_BD, { 0.05, 0.035, 0.02, 0.85 }, { 0.6, 0.45, 0.2, 1 })
	local e = CreateFrame("EditBox", nil, f)
	e:SetPoint("TOPLEFT", 8, -6)
	e:SetPoint("BOTTOMRIGHT", -8, 5)
	e:SetFont(W.FONT_BODY, 12, "")
	e:SetTextColor(unpackc(W.C.white))
	e:SetAutoFocus(false)
	e:SetNumeric(numeric and true or false)
	e:SetScript("OnEscapePressed", e.ClearFocus)
	e:SetScript("OnEnterPressed", e.ClearFocus)
	if placeholder then addPlaceholder(e, placeholder) end
	focusGlow(e, f)
	f:EnableMouse(true)
	f:SetScript("OnMouseDown", function() e:SetFocus() end)
	f.edit = e
	function f:GetText() return e:GetText() end
	function f:SetText(t) e:SetText(t or "") end
	return f
end

function W.TextArea(parent, width, height, placeholder)
	local f = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
	f:SetSize(width, height)
	W.Backdrop(f, INPUT_BD, { 0.05, 0.035, 0.02, 0.85 }, { 0.6, 0.45, 0.2, 1 })
	local sf = CreateFrame("ScrollFrame", nil, f)
	sf:SetPoint("TOPLEFT", 8, -8)
	sf:SetPoint("BOTTOMRIGHT", -8, 8)
	local e = CreateFrame("EditBox", nil, sf)
	e:SetMultiLine(true)
	e:SetWidth(width - 16)
	e:SetFont(W.FONT_BODY, 12, "")
	e:SetTextColor(unpackc(W.C.white))
	e:SetAutoFocus(false)
	e:SetScript("OnEscapePressed", e.ClearFocus)
	sf:SetScrollChild(e)
	-- keep the caret visible while typing
	e:SetScript("OnCursorChanged", function(_, _, y, _, h)
		local top, view = sf:GetVerticalScroll(), sf:GetHeight()
		y = -y
		if y < top then sf:SetVerticalScroll(y) elseif y + h > top + view then sf:SetVerticalScroll(y + h - view) end
	end)
	sf:EnableMouseWheel(true)
	sf:SetScript("OnMouseWheel", function(self, d)
		local max = math.max(0, e:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - d * 20)))
	end)
	if placeholder then addPlaceholder(e, placeholder) end
	focusGlow(e, f)
	f:EnableMouse(true)
	f:SetScript("OnMouseDown", function() e:SetFocus() end)
	f.edit = e
	function f:GetText() return e:GetText() end
	function f:SetText(t) e:SetText(t or "") end
	return f
end

-- ---------------------------------------------------------------------------
-- Select / dropdown (custom popup, closes on outside click or Escape)
-- ---------------------------------------------------------------------------
local openPopup
local function closePopup()
	if openPopup then openPopup:Hide(); openPopup = nil end
end
W.ClosePopups = closePopup

function W.Select(parent, width, items, onChange)
	local f = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
	f:SetSize(width or 160, 26)
	W.Backdrop(f, INPUT_BD, { 0.05, 0.035, 0.02, 0.85 }, { 0.6, 0.45, 0.2, 1 })
	local fs = W.Text(f, 12, W.C.white)
	fs:SetPoint("LEFT", 10, 0)
	fs:SetPoint("RIGHT", -26, 0)
	fs:SetWordWrap(false)
	local arrow = f:CreateTexture(nil, "OVERLAY")
	arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
	arrow:SetSize(22, 22)
	arrow:SetPoint("RIGHT", -2, 0)
	f:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
	f:GetHighlightTexture():SetAlpha(0.25)

	local pop = CreateFrame("Frame", nil, f, BACKDROP_TEMPLATE)
	pop:SetFrameStrata("FULLSCREEN_DIALOG")
	pop:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, 2)
	pop:SetWidth(width or 160)
	W.Backdrop(pop, INPUT_BD, { 0.06, 0.04, 0.02, 0.97 }, { 0.9, 0.72, 0.3, 1 })
	pop:Hide()
	pop:EnableMouse(true)
	f.items, f.rows = {}, {}

	function f:SetItems(list)
		self.items = list
		for i, it in ipairs(list) do
			local r = self.rows[i]
			if not r then
				r = CreateFrame("Button", nil, pop)
				r:SetHeight(20)
				r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 20)
				r:SetPoint("RIGHT", -4, 0)
				r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
				r.check = r:CreateTexture(nil, "OVERLAY")
				r.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
				r.check:SetSize(16, 16)
				r.check:SetPoint("LEFT", 2, 0)
				r.icon = r:CreateTexture(nil, "OVERLAY")
				r.icon:SetSize(14, 14)
				r.icon:SetPoint("LEFT", 20, 0)
				r.fs = W.Text(r, 12, W.C.white)
				r.fs:SetPoint("LEFT", 38, 0)
				r:SetScript("OnClick", function(btn) f:SetValue(btn.value); closePopup(); if onChange then onChange(btn.value) end end)
				self.rows[i] = r
			end
			r.value = it.value
			r.fs:SetText(it.text)
			r.icon:SetTexture(it.icon)
			r.icon:SetTexCoord(unpack(it.coords or { 0, 1, 0, 1 }))
			r.fs:SetPoint("LEFT", it.icon and 38 or 20, 0)
			r:Show()
		end
		for i = #list + 1, #self.rows do self.rows[i]:Hide() end
		pop:SetHeight(#list * 20 + 8)
	end

	function f:SetValue(v)
		self.value = v
		for i, it in ipairs(self.items) do
			self.rows[i].check:SetShown(it.value == v)
			if it.value == v then fs:SetText(it.text) end
		end
	end
	function f:GetValue() return self.value end

	f:SetScript("OnClick", function()
		if pop:IsShown() then closePopup() return end
		closePopup()
		pop:Show()
		openPopup = pop
		ns:Sound(SOUNDKIT and SOUNDKIT.U_CHAT_SCROLL_BUTTON or 1115)
	end)
	f:SetScript("OnHide", closePopup)
	f:SetItems(items or {})
	if items and items[1] then f:SetValue(items[1].value) end
	return f
end

-- ---------------------------------------------------------------------------
-- Checkbox & slider
-- ---------------------------------------------------------------------------
function W.Check(parent, label, onChange)
	local c = CreateFrame("CheckButton", nil, parent)
	c:SetSize(24, 24)
	c:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
	c:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
	c:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
	c:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	local fs = W.Text(c, 12, W.C.ink)
	fs:SetPoint("LEFT", c, "RIGHT", 4, 1)
	fs:SetText(label)
	c.label = fs
	c:SetHitRectInsets(0, -fs:GetStringWidth() - 6, 0, 0)
	c:SetScript("OnClick", function(self)
		ns:Sound(self:GetChecked() and (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856) or (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857))
		if onChange then onChange(self:GetChecked()) end
	end)
	return c
end

function W.Slider(parent, width, minV, maxV, step, onChange, fmt)
	local s = CreateFrame("Slider", nil, parent, BACKDROP_TEMPLATE)
	s:SetOrientation("HORIZONTAL")
	s:SetSize(width or 200, 17)
	W.Backdrop(s, { bgFile = "Interface\\Buttons\\UI-SliderBar-Background", edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
		tile = true, tileSize = 8, edgeSize = 8, insets = { left = 3, right = 3, top = 6, bottom = 6 } })
	s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
	local lo, hi, val = W.Text(s, 10, W.C.inkSoft), W.Text(s, 10, W.C.inkSoft), W.Text(s, 12, W.C.ink)
	lo:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 2, -1)
	hi:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", -2, -1)
	val:SetPoint("BOTTOM", s, "TOP", 0, 2)
	fmt = fmt or "%s"
	lo:SetText(fmt:format(minV))
	hi:SetText(fmt:format(maxV))
	s:SetScript("OnValueChanged", function(_, v)
		v = math.floor(v / step + 0.5) * step
		val:SetText(fmt:format(v))
		if onChange then onChange(v) end
	end)
	s.valueText = val
	return s
end

-- ---------------------------------------------------------------------------
-- Progress bar
-- ---------------------------------------------------------------------------
function W.Progress(parent, width, height)
	local f = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
	f:SetSize(width, height or 18)
	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetPoint("TOPLEFT", 1, -1)
	bg:SetPoint("BOTTOMRIGHT", -1, 1)
	bg:SetColorTexture(0.08, 0.05, 0.02, 0.9)
	local bar = CreateFrame("StatusBar", nil, f)
	bar:SetPoint("TOPLEFT", 1, -1)
	bar:SetPoint("BOTTOMRIGHT", -1, 1)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetStatusBarColor(0.95, 0.68, 0.15)
	local spark = bar:CreateTexture(nil, "OVERLAY")
	spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	spark:SetBlendMode("ADD")
	spark:SetSize(20, (height or 18) * 2)
	local border = CreateFrame("Frame", nil, f)
	border:SetAllPoints()
	border:SetFrameLevel(bar:GetFrameLevel() + 2)
	W.Outline(border, 1)
	local fs = W.GoldText(border, 11)
	fs:SetPoint("CENTER")
	f.bar, f.text = bar, fs

	function f:SetProgress(cur, max, label)
		bar:SetMinMaxValues(0, max)
		bar:SetValue(cur)
		local done = cur >= max
		bar:SetStatusBarColor(done and 0.25 or 0.95, done and 0.75 or 0.68, done and 0.2 or 0.15)
		spark:SetShown(cur > 0 and not done)
		spark:SetPoint("CENTER", bar, "LEFT", bar:GetWidth() * cur / max, 0)
		fs:SetText(label or ("%d / %d"):format(cur, max))
	end
	return f
end

-- ---------------------------------------------------------------------------
-- Virtual scroll list (fixed row pool, mouse wheel + scroll bar)
-- ---------------------------------------------------------------------------
function W.ScrollList(parent, width, height, rowHeight, createRow, updateRow)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, height)
	f.rows, f.data, f.offset = {}, {}, 0
	local visible = math.floor(height / rowHeight)

	local sb = CreateFrame("Slider", nil, f, BACKDROP_TEMPLATE)
	sb:SetPoint("TOPRIGHT", 0, -2)
	sb:SetPoint("BOTTOMRIGHT", 0, 2)
	sb:SetWidth(12)
	sb:SetOrientation("VERTICAL")
	W.Backdrop(sb, { bgFile = M .. "white", insets = { left = 4, right = 4, top = 0, bottom = 0 } }, { 0.3, 0.2, 0.08, 0.35 })
	sb:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
	sb:GetThumbTexture():SetSize(18, 24)
	sb:SetValueStep(1)
	sb:SetMinMaxValues(0, 0)
	if sb.SetObeyStepOnDrag then sb:SetObeyStepOnDrag(true) end
	f.scrollBar = sb

	for i = 1, visible do
		local r = createRow(f, i)
		r:SetHeight(rowHeight)
		r:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(i - 1) * rowHeight)
		r:SetPoint("RIGHT", sb, "LEFT", -4, 0)
		f.rows[i] = r
	end

	function f:Refresh()
		local n = #self.data
		local maxOff = math.max(0, n - visible)
		if self.offset > maxOff then self.offset = maxOff end
		sb:SetMinMaxValues(0, maxOff)
		sb:SetShown(maxOff > 0)
		for i, r in ipairs(self.rows) do
			local idx = i + self.offset
			if idx <= n then
				r.index = idx
				updateRow(r, self.data[idx], idx)
				r:Show()
			else
				r:Hide()
			end
		end
	end

	function f:SetData(d)
		self.data = d
		self:Refresh()
	end

	sb:SetScript("OnValueChanged", function(_, v)
		v = math.floor(v + 0.5)
		if v ~= f.offset then f.offset = v; f:Refresh() end
	end)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(_, d)
		local _, maxOff = sb:GetMinMaxValues()
		sb:SetValue(math.max(0, math.min(maxOff, f.offset - d * 3)))
	end)
	return f
end

-- ---------------------------------------------------------------------------
-- Sortable table built on ScrollList
-- columns = { {key, title, width, align, fmt = function(row) -> text, r,g,b , icon = function(row) -> tex, coords} }
-- ---------------------------------------------------------------------------
function W.Table(parent, width, height, columns, onRowClick)
	local f = W.Dark(parent, 0.72)
	f:SetSize(width, height)
	f.sortKey, f.sortAsc = columns[1].key, true

	local header = W.Dark(f, 0.85)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header:SetHeight(26)

	local x = 6
	for _, col in ipairs(columns) do
		local h = CreateFrame("Button", nil, header)
		h:SetSize(col.width, 22)
		h:SetPoint("LEFT", x, 0)
		local fs = W.GoldText(h, 12, W.FONT_TITLE)
		fs:SetAllPoints()
		fs:SetJustifyH(col.align or "LEFT")
		fs:SetText(col.title)
		h.fs = fs
		h:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		h:SetScript("OnClick", function()
			if f.sortKey == col.key then f.sortAsc = not f.sortAsc else f.sortKey, f.sortAsc = col.key, true end
			ns:Sound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION or 852)
			f:Refresh()
		end)
		col.header = h
		col.x = x
		x = x + col.width
	end

	local list = W.ScrollList(f, width - 8, height - 36, 24, function(owner, i)
		local r = CreateFrame("Button", nil, owner)
		local stripe = r:CreateTexture(nil, "BACKGROUND")
		stripe:SetAllPoints()
		stripe:SetColorTexture(1, 0.85, 0.6, (i % 2 == 0) and 0.05 or 0)
		r.sel = r:CreateTexture(nil, "BACKGROUND", nil, 1)
		r.sel:SetAllPoints()
		r.sel:SetColorTexture(0.85, 0.6, 0.15, 0.30)
		r.sel:Hide()
		r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		r:GetHighlightTexture():SetAlpha(0.5)
		r.cells = {}
		for c, col in ipairs(columns) do
			local fs = W.Text(r, 12, W.C.white)
			fs:SetWordWrap(false)
			fs:SetJustifyH(col.align or "LEFT")
			fs:SetPoint("LEFT", col.x + (col.icon and 22 or 0), 0)
			fs:SetWidth(col.width - (col.icon and 26 or 4))
			r.cells[c] = fs
			if col.icon then
				local t = r:CreateTexture(nil, "ARTWORK")
				t:SetSize(18, 18)
				t:SetPoint("LEFT", col.x, 0)
				fs.icon = t
			end
		end
		r:SetScript("OnClick", function(self, button)
			f.selected = self.data
			f:Refresh()
			if onRowClick then onRowClick(self.data, button) end
		end)
		return r
	end, function(r, row)
		r.data = row
		r.sel:SetShown(f.selected == row)
		for c, col in ipairs(columns) do
			local fs = r.cells[c]
			local text, cr, cg, cb
			if col.fmt then text, cr, cg, cb = col.fmt(row) else text = tostring(row[col.key] or "") end
			fs:SetText(text)
			if cr then fs:SetTextColor(cr, cg, cb) else fs:SetTextColor(unpackc(W.C.white)) end
			if fs.icon then
				local tex, l, rr, t, b = col.icon(row)
				fs.icon:SetTexture(tex)
				fs.icon:SetTexCoord(l or 0, rr or 1, t or 0, b or 1)
			end
		end
	end)
	list:SetPoint("TOPLEFT", 4, -30)
	f.list = list

	function f:SetData(rows)
		self.rows = rows
		self:Refresh()
	end

	function f:Refresh()
		local key, asc = self.sortKey, self.sortAsc
		local rows = self.rows or {}
		table.sort(rows, function(a, b)
			local va, vb = a[key], b[key]
			if va == vb then return (a.name or "") < (b.name or "") end
			if type(va) ~= type(vb) then va, vb = tostring(va), tostring(vb) end
			if asc then return va < vb else return va > vb end
		end)
		for _, col in ipairs(columns) do
			local arrow = (col.key == key) and (asc and " |TInterface\\Buttons\\Arrow-Up-Up:12|t" or " |TInterface\\Buttons\\Arrow-Down-Up:12|t") or ""
			col.header.fs:SetText(col.title .. arrow)
		end
		list:SetData(rows)
	end

	return f
end

-- ---------------------------------------------------------------------------
-- Items: icons, quality borders, tooltips, links
-- ---------------------------------------------------------------------------
local GetItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
local GetItemIcon = C_Item and C_Item.GetItemIconByID or GetItemIcon
local GetItemQuality = C_Item and C_Item.GetItemQualityByID

function W.QualityColor(q)
	if not q then return 0.6, 0.6, 0.6 end
	if C_Item and C_Item.GetItemQualityColor then
		local r, g, b = C_Item.GetItemQualityColor(q)
		if r then return r, g, b end
	end
	if GetItemQualityColor then
		local r, g, b = GetItemQualityColor(q)
		if r then return r, g, b end
	end
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

function ns:ItemData(id)
	local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(id)
	icon = icon or GetItemIcon(id)
	quality = quality or (GetItemQuality and GetItemQuality(id))
	return name, link, quality, icon
end

ns.INTEREST = {
	need    = { text = "Need",     color = "ff3cd23c", icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up" },
	greed   = { text = "Greed",    color = "ffffd100", icon = "Interface\\Buttons\\UI-GroupLoot-Coin-Up" },
	offspec = { text = "Off-spec", color = "ff7fb2ff", icon = "Interface\\Icons\\INV_Sword_04" },
}

function W.AddInterestLines(tooltip, itemID)
	local who = ns:GetInterest(itemID)
	tooltip:AddLine(" ")
	tooltip:AddLine("|TInterface\\AddOns\\Simulacrum\\Media\\icon:14|t |cffe6c35c<Simulacrum> interest|r")
	if not who or not next(who) then
		tooltip:AddLine("  Nobody yet - be the first!", 0.6, 0.6, 0.6)
	else
		for _, kind in ipairs({ "need", "greed", "offspec" }) do
			local names = {}
			for player, k in pairs(who) do
				if k == kind then
					local m = ns:GetMember(player)
					local c = m and RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class]
					names[#names + 1] = c and ("|c%s%s|r"):format(c.colorStr or "ffffffff", player) or player
				end
			end
			if #names > 0 then
				table.sort(names)
				local def = ns.INTEREST[kind]
				tooltip:AddLine(("  |c%s%s:|r %s"):format(def.color, def.text, table.concat(names, ", ")), 1, 1, 1, true)
			end
		end
	end
	tooltip:AddLine("|cff888888Click: toggle Need  Shift-click: link  Ctrl-click: dress up|r")
end

function W.ItemButton(parent, size)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local glow = b:CreateTexture(nil, "OVERLAY")
	glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	glow:SetBlendMode("ADD")
	glow:SetPoint("CENTER")
	glow:SetSize(size * 1.85, size * 1.85)
	local frame = CreateFrame("Frame", nil, b, BACKDROP_TEMPLATE)
	frame:SetPoint("TOPLEFT", -2, 2)
	frame:SetPoint("BOTTOMRIGHT", 2, -2)
	W.Backdrop(frame, { edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 }, nil, { 0.6, 0.6, 0.6, 1 })
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	local badge = b:CreateTexture(nil, "OVERLAY", nil, 2)
	badge:SetSize(size * 0.5, size * 0.5)
	badge:SetPoint("BOTTOMRIGHT", 4, -4)
	local count = W.GoldText(b, 11)
	count:SetFont(W.FONT_BODY, 11, "OUTLINE")
	count:SetPoint("TOPRIGHT", -1, -2)
	b.icon, b.glow, b.border, b.badge, b.count = icon, glow, frame, badge, count

	function b:SetItem(id)
		self.itemID = id
		local _, _, quality, tex = ns:ItemData(id)
		icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
		local r, g, bl = W.QualityColor(quality)
		frame:SetBackdropBorderColor(r, g, bl, 1)
		glow:SetVertexColor(r, g, bl, 0.7)
		glow:SetShown(quality and quality >= 2)
		local mine = ns:MyInterest(id)
		badge:SetShown(mine ~= nil)
		if mine then badge:SetTexture(ns.INTEREST[mine].icon) end
		local who = ns:GetInterest(id)
		local n = 0
		if who then for _ in pairs(who) do n = n + 1 end end
		count:SetText(n > 0 and n or "")
	end

	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetHyperlink("item:" .. self.itemID)
		W.AddInterestLines(GameTooltip, self.itemID)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", GameTooltip_Hide)
	return b
end

function W.HandleItemModifiedClick(itemID)
	local _, link = ns:ItemData(itemID)
	link = link or ("item:" .. itemID)
	if IsShiftKeyDown() and ChatEdit_InsertLink then
		ChatEdit_InsertLink(link)
		return true
	elseif IsControlKeyDown() and DressUpItemLink then
		DressUpItemLink(link)
		return true
	end
end

-- class icon from the classic class-circle atlas
function W.ClassIcon(class)
	local tc = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
	if tc then return "Interface\\TargetingFrame\\UI-Classes-Circles", unpack(tc) end
	return "Interface\\Icons\\INV_Misc_QuestionMark", 0, 1, 0, 1
end

function W.ClassColor(class)
	local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end
