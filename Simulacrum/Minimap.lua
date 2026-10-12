local _, ns = ...

local LDB = LibStub("LibDataBroker-1.1")
local DBIcon = LibStub("LibDBIcon-1.0")

local launcher = LDB:NewDataObject("Simulacrum", {
	type = "launcher",
	text = "Simulacrum",
	icon = ns.media .. "icon",
	OnClick = function(_, button)
		if button == "RightButton" then
			for i, p in ipairs(ns.pages) do if p.text == "Settings" then ns:Toggle(i) end end
		else
			ns:Toggle()
		end
	end,
	OnTooltipShow = function(tt)
		tt:AddDoubleLine("|cffe6c35cSimulacrum|r", "|cffffffffv" .. ns.version .. "|r")
		tt:AddLine(ns.MOTTO, 0.8, 0.8, 0.8, true)
		tt:AddLine(" ")
		tt:AddLine("|cffcfcfcfLeft-click:|r open the guild hall")
		tt:AddLine("|cffcfcfcfRight-click:|r settings")
		tt:AddLine("|cffcfcfcfDrag:|r move this button")
	end,
})

ns:On("DB_READY", function()
	DBIcon:Register("Simulacrum", launcher, ns.db.minimap)
end)

ns:On("MINIMAP_TOGGLED", function()
	if ns.db.minimap.hide then DBIcon:Hide("Simulacrum") else DBIcon:Show("Simulacrum") end
end)
