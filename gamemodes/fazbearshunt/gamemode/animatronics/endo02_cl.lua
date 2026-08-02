AddCSLuaFile()

if not CLIENT then return end

local endo_ability_selector = Material("vgui/endo/endo_ability_selector.png")
	
function draw_killer_selector()
	if not istable(animatronics) then return end

	selector_panel = vgui.Create("DFrame")
	selector_panel:SetTitle("")
	selector_panel:SetDraggable(false)
	selector_panel:ShowCloseButton(false)
	selector_panel:SetSize(752, 200)
	selector_panel:Center()
	selector_panel.Paint=function(self, w, h)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(endo_ability_selector)
		surface.DrawTexturedRect(0, 0, w, h)
	end
	selector_panel.Think=function(delta)
		gui.EnableScreenClicker(true)
	end
	gui.EnableScreenClicker(true)
	
	selector_panel.OnClose = function()
		gui.EnableScreenClicker(false)
	end
end