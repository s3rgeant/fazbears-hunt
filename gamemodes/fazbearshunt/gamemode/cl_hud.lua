currentKiller = ""

currentAbilities = {}
cupcakes = 0

function DrawKillerInterface()
if currentKiller == "" or !currentKiller or !GetConVar("cl_drawhud"):GetBool() then return end
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
            local clr = abilityData.color
            if type(clr) == "function" then
                clr = clr()
            end
            draw.RoundedBox(8, abilityX, abilityY, 140, 50, clr or Color(32, 32, 32, 200))
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
        abilityParentClrFunc('Submerge', function()
            return isNotStuck()
        end)
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

function isNotStuck()
	local ply = LocalPlayer()
	if ply:GetMoveType() == 2 then return end
	local trace = util.TraceHull({
		start = ply:GetPos(),
		endpos = ply:GetPos(),
        mins = ply:OBBMins(),
        maxs = ply:OBBMaxs(),
		filter = ply,
	})
	if trace.Hit then
		return Color(200, 32, 32, 200)
	end
	return Color(32, 32, 32, 200)
end

function abilityParentClrFunc(name, func)
	currentAbilities[name].color = func
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





-- текст смешной сверху
surface.CreateFont("BigTextFont", {
    font = "Arial",
	outline = true,
    size = 48,
    weight = 700
})

surface.CreateFont("SmallTextFont", {
    font = "Arial",
	outline = true,
    size = 32,
    weight = 500
})

local displayText1 = ""
local displayText2 = ""
local displayDuration = 0
local startTime = 0
local isDisplaying = false
hook.Add("HUDPaint", "fh_display_text", function()
    if isDisplaying and GetConVar("cl_drawhud"):GetBool() then
        local elapsedTime = CurTime() - startTime
        local alpha = 255

        if elapsedTime > displayDuration then
            local fadeDuration = 1
            local fadeTime = elapsedTime - displayDuration
            if fadeTime < fadeDuration then
                alpha = 255 * (1 - fadeTime / fadeDuration)
            else
                isDisplaying = false
                return
            end
        end

        surface.SetFont("BigTextFont")
        surface.SetTextColor(255, 255, 255, alpha)

        local w, h = surface.GetTextSize(displayText1)
        local x = ScrW() / 2 - w / 2
        local y = ScrH() / 4

        surface.SetTextPos(x, y)
        surface.DrawText(displayText1)

        surface.SetFont("SmallTextFont")
        surface.SetTextColor(255, 255, 255, alpha)

        local w2, h2 = surface.GetTextSize(displayText2)
        local x2 = ScrW() / 2 - w2 / 2
        local y2 = y + h + 5

        surface.SetTextPos(x2, y2)
        surface.DrawText(displayText2)
    end
end)

function fh_change_display(text1, text2, duration)
    displayText1 = text1
    displayText2 = text2
    displayDuration = duration
    startTime = CurTime()
    isDisplaying = true
end

--[[
concommand.Add("fh_test_broadcast", function(ply, cmd, args)
	if ply:IsAdmin() then
		local text1 = args[1] or "Hello"
		local text2 = args[2] or "World"
		local duration = tonumber(args[3]) or 5
		
		fh_change_display(text1, text2, duration)
	end
end)
]]--

net.Receive("fh_net_display", function()
    local text1 = net.ReadString()
    local text2 = net.ReadString()
    local duration = net.ReadFloat()
    fh_change_display(text1, text2, duration)
end)

//think fast chucklenuts

function chucklenuts()
    if GetConVar("cl_drawhud"):GetBool() then
		surface.SetDrawColor(255, 255, 255, 255)
		
		surface.SetMaterial(Material("vgui/thinkFast.png"))
		
		surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
    end
end

net.Receive("fh_net_thinkfast", function()
	hook.Add("HUDPaint", "fh_thinkfast", chucklenuts)
	
	surface.PlaySound('thinkfast.wav')
	
	timer.Simple(1.2, function() 
		LocalPlayer():ScreenFade( SCREENFADE.IN, Color( 255, 255, 255, 255 ), 2, 2 )
		LocalPlayer():SetDSP(35, false)
		
		hook.Remove("HUDPaint", "fh_thinkfast")
		
		timer.Simple(1.5, function()
			LocalPlayer():SetDSP(35, true)
		end)
	end)
end)

hook.Add("OnContextMenuOpen", "fh_contextmenu", function()
	RunConsoleCommand( "playermodel_selector" )
	-- 
end)