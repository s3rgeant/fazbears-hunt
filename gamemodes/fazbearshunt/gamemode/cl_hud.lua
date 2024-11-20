currentKiller = ""

currentAbilities = {}
cupcakes = 0


function DrawKillerInterface()
if currentKiller == "" or !currentKiller then return end
	local killerIcon = Material( "vgui/"..currentKiller.."_header.png" )
	
	local cake = Material( "vgui/cake.png" )
	
    local screenW, screenH = ScrW(), ScrH()

	surface.SetMaterial(killerIcon)
    surface.SetDrawColor(255, 255, 255, 255)
	
	local size = 342 * (ScrW() / 1920)
    local avatarX, avatarY = 50, screenH - size - 30
	
    surface.DrawTexturedRect(avatarX, avatarY, size, size)

    local abilityX, abilityY = size * 0.6, screenH - 80

    for abilityName, abilityData in pairs(currentAbilities) do
        if abilityData.timeleft > 0 or !abilityData.hidden then
            draw.RoundedBox(8, abilityX, abilityY, 140, 50, Color(32, 32, 32, 200))
            draw.SimpleText(abilityData.text, "DermaLarge", abilityX + 10, abilityY + 10, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT)
            if (abilityData.timeleft > 0) then 
				draw.SimpleText(tostring(math.ceil(abilityData.timeleft)) .. " s", "DermaLarge", abilityX + 128, abilityY + 10, Color(255, 255, 255, 255), TEXT_ALIGN_RIGHT)
			end
			
			if abilityName == 'Mine' then
				local x_add = 0
				if cupcakes > 0 then
					for i = 1,cupcakes do
						surface.SetMaterial(cake)
						surface.SetDrawColor(255, 255, 255, 255)
				
						surface.DrawTexturedRect(abilityX + x_add, abilityY - 56, 43 * 0.8, 64 * 0.8)
						x_add = x_add + 40
					end
				end
			end
			
            abilityX = abilityX + 155
        end
    end
end

timer.Create("UpdateAbilitiesTime", 0.1, 0, function()
    for _, abilityData in pairs(currentAbilities) do
        if abilityData.timeleft > 0 then
            abilityData.timeleft = abilityData.timeleft - 0.1
        end
    end
end)

function assignAbilitiesByKiller(name)
	addAbility('Highlight', 'R', 0, false)
	addAbility('Kill', 'ЛКМ', 0, true)
	
	if name == "sfreddy" then
		addAbility('Submerge', 'ПКМ', 0, false)
	elseif name == "chica" then
		addAbility('Mine', 'ПКМ', 0, false)
	elseif name == "endo" then
		addAbility('Grab', 'ПКМ', 0, false)
	elseif name == "freddy" then
		addAbility('Stalk', 'ПКМ', 0, false)
	elseif name == "bonnie" then
		addAbility('Yoursmine', 'ПКМ', 0, false)
	end
end

function addAbility(name, text, duration, hidden)
    if currentAbilities[name] then
        return
    end

    currentAbilities[name] = {
        text = text,
        timeleft = duration,
        hidden = hidden or false
    }
end

function setDuration(name, newDuration)
    if currentAbilities[name] then
        currentAbilities[name].timeleft = newDuration
    end
end
net.Receive("ApplyKiller", function()
	hook.Add("HUDPaint", "DrawKillerInterface", DrawKillerInterface)
    currentKiller = net.ReadString()
	assignAbilitiesByKiller(currentKiller)
end)

net.Receive("fh_remove_hud_mine", function()
	if cupcakes > 0 then
		cupcakes = cupcakes - 1
	end
end)

net.Receive("RemoveKiller", function()
	hook.Remove("HUDPaint", "DrawKillerInterface")
    currentKiller = ""
	currentAbilities = {}
	cupcakes = 0
end)

net.Receive("fh_net_killer_change", function()
	local str = net.ReadString()
    setDuration(str, net.ReadFloat())
	if str == 'Mine' then
		cupcakes = cupcakes + 1
	end
	--[[
	if str == 'Submerge' then
		hook.Add("RenderScreenspaceEffects", "NightVisionEffect", function()
            local colorCorrection = {
                ["$pp_colour_addr"] = 0.3,
                ["$pp_colour_addg"] = -0.6,
                ["$pp_colour_addb"] = 0.3,
                ["$pp_colour_brightness"] = 0,
                ["$pp_colour_contrast"] = 0.6,
                ["$pp_colour_colour"] = 0.4,
                ["$pp_colour_mulr"] = 0,
                ["$pp_colour_mulg"] = 0,
                ["$pp_colour_mulb"] = 0
            }
            DrawColorModify(colorCorrection)
        end)
	end
	]]
end)