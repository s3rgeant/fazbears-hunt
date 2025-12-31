local highlightEnabled = false

-- звук для аниматронов
local visionSuccessSound = "vision_success.wav"
local visionUnsuccessSound = "vision_unsuccess.wav"

local affectedPlayers = {}
local affectedPlayers_force = {}
local animatronics = {}
local teammates = {}

local fh_halo_teammates = CreateClientConVar('fh_halo_teammates', 1, true, false, 'Highlight Teammates? (Animatronics Only) Turn Off for Performance.', 0, 1)

net.Receive("NotifySpectators", function()
	local players = net.ReadTable()
	local ply = net.ReadEntity()
	local player = ply:Nick()
	
	chat:AddText(Color( 255, 0, 0 ), player, Color( 180, 20, 20 ), ' ', language.GetPhrase("fuppr.highlight_specs"), ': ', Color( 170, 55, 50 ), table.concat(players, ", "))
end)

function addAffected(ply, duration, color, force)
	local duration = duration or conVars.halo_time:GetFloat()
	
	if !affectedPlayers[ply] or force then
		affectedPlayers[ply] = color or Color(255,0,0)
	end
	
	if force then
		affectedPlayers_force[ply] = true
	end
end

function removeAffected(ply, force)
	if affectedPlayers[ply] and !affectedPlayers_force[ply] or force then
		affectedPlayers[ply] = nil
		affectedPlayers_force[ply] = nil
	end
end

net.Receive("AddAffectedPlayers", function()
    players = net.ReadTable()
	duration = net.ReadFloat()
	color = net.ReadColor()
	
	if duration <= 0 then duration = nil end
	
	for _, targetPlayer in ipairs(players) do
		if IsValid(targetPlayer) then
			addAffected(targetPlayer, duration, color)
		end
	end
end)

net.Receive("fh_addaffected_springtrap", function()
	local player = net.ReadEntity()
	
	local starttime = CurTime()
	
    hook.Add("RenderScreenspaceEffects", "fh_springtrap_fx", function()
        local lp = LocalPlayer()

        local t = CurTime() - starttime
        local frac = 1 - math.Clamp((t / 90), 0, 1)

        DrawToyTown(2, ScrH()/2)
		DrawBloom( 0.65, 1 * frac, 9, 9, 1, 1, 1, 1, 1 )
    end)
	
	timer.Simple(90, function()
		hook.Remove("RenderScreenspaceEffects", "fh_springtrap_fx")
	end)
	
	if player:IsPlayer() then
		LocalPlayer():ChatPrint(string.format(language.GetPhrase('fazhunt.springtrap.target'), player:Nick() ))
	end
end)

net.Receive("RemoveAffectedPlayer", function()
    targetPlayer = net.ReadEntity()
	removeAffected(targetPlayer)
end)

net.Receive("fh_hl_badkid", function ()
	local player = net.ReadEntity()
	if LocalPlayer() ~= player and LocalPlayer():Team() == 2701 then
		surface.PlaySound("vision_unbox_success.wav")
	end
	
	if LocalPlayer() == player then
		drawHighlightTimer(true)
		surface.PlaySound("vision_affected.wav")
	end
end)

net.Receive("PlayHighlightSounds", function()
    local isAffected = net.ReadBool()
	local sound = net.ReadString()
	
	surface.PlaySound(sound)
    if isAffected then
		drawHighlightTimer(true)
    end
end)

net.Receive("fh_draw_hl_overlay", function()
    local bool = net.ReadBool()
    drawHighlightTimer(bool)
end)

net.Receive("fh_draw_hl_overlay_timed", function()
    local bool = net.ReadBool()
    local dur = net.ReadFloat()
    drawHighlightTimer(bool, dur)
end)

net.Receive("fh_nodraw_hl_overlay", function()
	hook.Remove("HUDPaint", "fh_hl_overlay_draw")
end)
	
function drawHighlightTimer(bool, duration)
	duration = duration or conVars.halo_time:GetFloat()
	hook.Add("HUDPaint", "fh_hl_overlay_draw", drawHighlight)
	
	if timer.Exists('fh_hud_hl_overlay') then
		timer.Remove('fh_hud_hl_overlay')
	end
	
	if !bool then return end
	timer.Create( "fh_hud_hl_overlay", duration, 1, function()
		hook.Remove("HUDPaint", "fh_hl_overlay_draw")
	end)
end

local highlight_mat = Material("vgui/highlight2.vtf")
function drawHighlight()
	if !GetConVar("cl_drawhud"):GetBool() then return end
	
	if highlight_mat:IsError() then return end
	
	-- 80 0 255 ШФ
    surface.SetDrawColor(255, 255, 255, 225)
    surface.SetMaterial(highlight_mat)
    surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
end

local scale = ScrH() / 1080
local size = 128 * scale

local plushalert_y = -size
local plushalert_y_target = 0

local plushalert_alpha = 0
local plushalert_alpha_target = 20

net.Receive("fh_plushalert_inrange", function()
	hook.Add("HUDPaint", "fh_plushalert_draw", plushtrap_alert)
	plushalert_y_target = 10
	plushalert_alpha_target = 10
end)

net.Receive("fh_plushalert_outrange", function()
	plushalert_y_target = -size
	plushalert_alpha_target = 0
	hook.Add("Think", "fh_plushalert_removing", function()
		if math.floor(plushalert_y) == math.floor(plushalert_y_target) then
			hook.Remove("HUDPaint", "fh_plushalert_draw")
			hook.Remove("HUDPaint", "fh_plushalert_removing")
		end
	end)
end)

local plushtrap_overlay_mat = Material("vgui/plushtrap overlay.png")
local plushtrap_alert_mat = Material("vgui/plushtrap_alert.vtf")

function plushtrap_alert()
	if plushtrap_overlay_mat:IsError() then return end
	
    local speed = FrameTime() * 2
    plushalert_y = Lerp(speed, plushalert_y, plushalert_y_target)
    plushalert_alpha = Lerp(speed, plushalert_alpha, plushalert_alpha_target)
	
	if !GetConVar("cl_drawhud"):GetBool() then return end
	
    surface.SetDrawColor(255, 255, 255, plushalert_alpha)
    surface.SetMaterial(plushtrap_overlay_mat)
    surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
	
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(plushtrap_alert_mat)
    surface.DrawTexturedRect(ScrW() / 2 - size / 2, (ScrH() - size) - plushalert_y, size, size)
end

net.Receive("ToggleHighlightSound", function()
    local success = net.ReadBool()
    if success then
		surface.PlaySound(visionSuccessSound)
    else
		surface.PlaySound(visionUnsuccessSound)
    end
end)

local spectateColor = Color(155,0,255,255)
hook.Add( "PreDrawHalos", "fh_affected", function()
	-- ДЛЯ АНИМАТРОНИКОВ
	
	local coloredHalo = {}

	for ply, color in pairs(affectedPlayers) do
		if ply ~= LocalPlayer() and IsValid(ply) and ply:Health() > 0 and not ply:IsInvisible() then
			local pos = ply:GetPos()
			if pos:ToScreen().visible then
				local key = ("%d_%d_%d"):format(color.r, color.g, color.b)

				if not coloredHalo[key] then
					coloredHalo[key] = {
						color = color,
						players = {}
					}
				end

				table.insert(coloredHalo[key].players, ply)
			end
		end
	end

	for _, data in pairs(coloredHalo) do
		local c = data.color
		c.a = 255
		halo.Add(data.players, c, 0.5, 0.5, 1, true, true)
	end
	
	local lp = LocalPlayer()
	local lp_obsmode = lp:GetObserverMode()
	
	if IsValid(lp) and !lp:Alive() and lp_obsmode ~= OBS_MODE_NONE then
		local spectateTargets = {}
		for _, ply in player.Iterator() do
			if !ply:Alive() then continue end
		
			local ent = ply:GetPill()
			
			--[[ 
				ЗАМЕТОЧКА:
						Игроков с SetNoDraw(true) нельзя просветить.
			]]--
			
			if lp:GetObserverTarget() == ply and lp_obsmode == OBS_MODE_IN_EYE then continue end
			
			if !IsValid(ent) and ply:GetMaterial() == "models/null" then
				table.insert(spectateTargets, ply)
			elseif IsValid(ent) and ent:GetMaterial() == "models/null" then
				table.insert(spectateTargets, ent)
			end
		end
		
		halo.Add(spectateTargets, spectateColor, 1, 1, 2, true, false)
	end
	
	local ent = pills.getMappedEnt(LocalPlayer())
	
	if ent and ent.formTable then
		if ent.formTable.name == "pill_wchica2" then -- ДЛЯ ЧИКИ
			halo.Add(ents.FindByClass("cakemine"), Color(255, 155, 0, 255), 0.5, 0.5, 1, true, true)
		end
	end
end)

local teammateColor = Color(0, 255, 0)
local enemyColor = Color(255, 155, 0)
local outlineMaterial = Material("models/debug/debugwhite")

local teammatesColors = {}

hook.Add("HUDPaint", "fh_draw_affected", function()
    cam.Start3D()
        for v, color in pairs(affectedPlayers) do
            if v ~= LocalPlayer() and v:IsValid() and v:Health() > 0 and !v:IsInvisible() then
				local pos = v:GetPos()
				if pos:ToScreen().visible then
					v:DrawModel()
				end
            end
        end
    cam.End3D()

	local affectedPlayersReal = {}
	
	for v, color in pairs(affectedPlayers) do
		if v ~= LocalPlayer() and v:IsValid() and v:Health() > 0 and !v:IsInvisible() then
			affectedPlayersReal[v] = color
		end
	end
	draw_orbs(affectedPlayersReal)
	
	if fh_halo_teammates:GetBool() then 
		if !table.IsEmpty(teammatesColors) then
			draw_orbs(teammatesColors, nil, GetGlobal2Float("FarZ", 8000))
		end
	end
end)

net.Receive("fh_hl_animatronics", function()
	for _, ply in ipairs(team.GetPlayers(2701)) do
		if !table.HasValue(animatronics, ply) then
			local ent = pills.getMappedEnt(ply)
			table.insert(animatronics, ent)
			teammatesColors[ent] = 0
		end
	end
	surface.PlaySound("human_gift_vision.wav")
	timer.Simple(30, function()
		table.Empty(animatronics)
		if !LocalPlayer():IsAnimatronic() then
			table.Empty(teammatesColors)
		end
	end)
end)

net.Receive("fh_hl_teammates", function()
	if LocalPlayer():Team() == 2701 then
		for _, ply in ipairs(team.GetPlayers(2701)) do
			local ent = pills.getMappedEnt(ply)
			if ply ~= LocalPlayer() and IsValid(ent) then
				teammatesColors[ent] = teammateColor
			end
			
			if ply ~= LocalPlayer() then
				teammates[ply] = ent
			end
		end
	end
end)

net.Receive("fh_uhl_teammates", function()
	table.Empty(teammatesColors)
	table.Empty(teammates)
end)

hook.Add("PostDrawOpaqueRenderables", "fh_draw_teammates", function(depth, skybox, skybox3d )
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
	
	if skybox3d then return end
	
	local function drawAnimatronics(tbl, color)
		local viewEntity = ply:GetViewEntity()
		local eyePos = IsValid(viewEntity) and (viewEntity:IsPlayer() and viewEntity:EyePos() or viewEntity:GetPos() ) or ply:EyePos()
		for _, ent in pairs(tbl) do
			if not IsValid(ent) or not ent.DrawModel then continue end
			
			local pos = ent:GetPos()
			local distance = pos:Distance(LocalPlayer():GetPos())
			
			if distance > GetGlobal2Float("FarZ", 8000) + 50 then continue end
			
			local toScreen = pos:ToScreen()
			if toScreen.visible then
				local tr = util.TraceLine( {
					start = eyePos,
					endpos = pos + ent:OBBCenter(),
					filter = function(ent)
						return !ent:IsPlayer() and ent ~= ply
					end,
					mask = MASK_SHOT_HULL,
				} )
				
				local entIsPill = ( ent == pills.getMappedEnt(tr.Entity) )
				
				if ( !tr.Hit or entIsPill ) and !ent:IsInvisible() then continue end
				
				if !ent:IsInvisible() and pos:Distance(eyePos) < 250 then continue end

				cam.IgnoreZ(true)
				local oldfogmode = render.GetFogMode()
				render.FogMode( 0 )
				
				local clr = color or killers.getColor(ent:GetPillName())
				
				render.SuppressEngineLighting(true)
				render.SetColorModulation(clr.r / 255, clr.g / 255, clr.b / 255)
				render.SetBlend(0.5)
				render.MaterialOverride(outlineMaterial)

				ent:SetLOD(8) -- мы делаем модельку обводки "уёбищной" чтобы она не жрала фпс
				ent:DrawShadow( false )
				ent:DrawModel()

				render.MaterialOverride(nil)
				render.SetColorModulation(1, 1, 1)
				render.SetBlend(1)
				render.SuppressEngineLighting(false)
				render.FogMode( oldfogmode )

				ent:SetLOD(-1)
				ent:DrawShadow( true )
				cam.IgnoreZ(false)
			end
		end
	end
	
	if fh_halo_teammates:GetBool() then 
		if !table.IsEmpty(teammates) then
			drawAnimatronics(teammates, teammateColor)
		end
	
		if LocalPlayer():IsAnimatronic() then
			drawAnimatronics(ents.FindByClass("plushtrap"), teammateColor)
		end
	end
	
	if !table.IsEmpty(animatronics) then
		drawAnimatronics(animatronics)
	end
end)

hook.Add("HUDPaint", "fh_cupcake_count_draw", function()
	local ent = pills.getMappedEnt(LocalPlayer())
	if !ent then return end
	if ent.formTable and ent.formTable.name != "pill_wchica2" then return end
    local cakemines = ents.FindByClass("cakemine")

    for i, ent in ipairs(cakemines) do
        if not IsValid(ent) then continue end

        local pos = ent:GetPos():ToScreen()

        if pos.visible then
            draw.SimpleTextOutlined(
                i, 
                "DermaLarge", 
                pos.x, pos.y - 25, 
                Color(255, 155, 0, 255), 
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 
                1, Color(0, 0, 0, 255)
            )
        end
    end
end)

local target_orb = Material("vgui/target_orb_color.png", "noclamp smooth")

local function IsOverlapping(x, y, size)
    for _, ico in ipairs(drawnIcons) do
        if math.abs(ico.x - x) < size * 2 and math.abs(ico.y - y) < size * 2 then
            return true
        end
    end
    return false
end

local function RegisterIcon(x, y)
    drawnIcons[#drawnIcons + 1] = { x = x, y = y }
end

function draw_orbs(tbl, material, distance)
    local material = material or target_orb

    local ply = LocalPlayer()
    if !IsValid(ply) or !ply:Alive() then return end
    
    local screenW, screenH = ScrW(), ScrH()
    local halfW, halfH = screenW / 2, screenH / 2
    local textureSize = 32
    
    local maxDistance = distance or 1650

    local overlap = {}
	drawnIcons = {}

    for target, color in pairs(tbl) do
        if IsValid(target) then
            if target:IsPlayer() and (!target:Alive() or target:Team() == TEAM_SPECTATOR) then continue end

            local min, max = target:GetCollisionBounds()
            local targetPos = target:GetPos() + Vector(0, 0, (min.z + max.z) / 2)
            local screenPos = targetPos:ToScreen()
            local dist = ply:GetPos():Distance(target:GetPos())
            
            if dist > maxDistance then
                local alpha = math.Clamp((dist - maxDistance) / 200, 0, 1) * 255
                
                local clampedX = math.Clamp(screenPos.x, textureSize, screenW - textureSize)
                local clampedY = math.Clamp(screenPos.y, textureSize, screenH - textureSize)
                
                local ourColor = IsColor(color) and color:Copy() or Color(255,0,0,255)
				
                if target:GetClass() == "pill_costume" and killers.GetFullName(target:GetPillName()) and ply:IsAnimatronic() then
                    
					local textureSize = 16

					local drawX = clampedX
					local drawY = clampedY

					local step = textureSize * 2
					local maxSteps = 6
					local placed = false

					for i = 0, maxSteps do
						local offset = i * step

						local tryRight = drawX + offset
						if not IsOverlapping(tryRight, drawY, textureSize/1.5) then
							drawX = tryRight
							placed = true
							break
						end

						local tryLeft = drawX - offset
						if not IsOverlapping(tryLeft, drawY, textureSize/1.5) then
							drawX = tryLeft
							placed = true
							break
						end
					end
					
					if terror_radius.imChasing() then
						alpha = 60
						if drawX > (ScrW()/2) - 65 and drawX < (ScrW()/2) + 65 then continue end
					end

					RegisterIcon(drawX, drawY)
					
                    local nickname = nil
                    local name = killers.GetFullName(target:GetPillName())
                    if IsValid(target:GetParent()) and target:GetParent():IsPlayer() then
                        nickname = target:GetParent():Nick()
                    end

                    local pillMaterial = killers.GetAvatar(target:GetPillName())
                    if pillMaterial then
                        ourColor = Color(255,255,255, alpha)
                    end

                    surface.SetDrawColor(ourColor:Unpack())
                    surface.SetMaterial(pillMaterial or material)
                    surface.DrawTexturedRect(drawX - textureSize, drawY - textureSize, textureSize*2, textureSize*2)

                    if nickname then
                        draw.SimpleText(nickname, "CreditsText",
                            drawX, drawY + 32, IsColor(color) and color or Color(255,255,255,alpha),
                            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
                        )
                    end

                    continue
                end
				
                if target:GetClass() == "pill_costume" and killers.GetFullName(target:GetPillName()) and ply:IsSurvivor() then
					ourColor = IsColor(color) and color or killers.getColor(target:GetPillName())
				end
				ourColor.a = alpha

				surface.SetDrawColor(ourColor)
				surface.SetMaterial(material)
				surface.DrawTexturedRect(clampedX - textureSize, clampedY - textureSize, 64, 64)
            end
        end
    end
end

hook.Add("PostCleanupMap", "fh_cleanup_halo", function(ply)
	table.Empty(affectedPlayers)
	
	hook.Remove("HUDPaint", "fh_hl_overlay_draw")
	hook.Remove("HUDPaint", "fh_pt_draw_affected")
	
	hook.Remove("HUDPaint", "fh_plushalert_draw")
	hook.Remove("HUDPaint", "fh_plushalert_removing")
	
	hook.Remove("RenderScreenspaceEffects", "fh_springtrap_fx")
	
	if IsValid(selector) then
		selector:Close()
	end
end)

hook.Add("HandlePillThirdperson", "no_thirdperson_yoursmine", function(ply, ent)
	if ply._yoursmine_target then
		return false
	end
end)

net.Receive("fh_start_yoursmine_view", function()
    local target = net.ReadEntity()
    LocalPlayer()._yoursmine_target = target
    LocalPlayer()._yoursmine_start_time = CurTime()
    LocalPlayer()._yoursmine_initial_phase_duration = 5
    LocalPlayer()._yoursmine_rotation_duration = 0.7
    LocalPlayer()._yoursmine_total_dur = LocalPlayer()._yoursmine_initial_phase_duration + LocalPlayer()._yoursmine_rotation_duration
	
	LocalPlayer():DrawViewModel( false, 0 )
	
	LocalPlayer():SetFOV(0, 0)
	
	local ent = pills.getMappedEnt(LocalPlayer())
	
	if IsValid(ent) and !table.HasValue(animatronics, ent) then
		table.insert(animatronics, ent)
	end
	
	--[[
    hook.Add("CalcView", "fh_yoursmine_view", function(viewer, origin, angles, fov)
        if viewer ~= LocalPlayer() then return end
        if not IsValid(viewer._yoursmine_target) then return end

		local eyeangles = LocalPlayer():EyeAngles()

		local view = {}
		view.origin = viewer._yoursmine_target:EyePos()
		view.angles = eyeangles
		view.fov = fov
		return view
    end)
	]]--
	
    hook.Add("RenderScreenspaceEffects", "fh_yoursmine_fx", function()
        local lp = LocalPlayer()
        if not IsValid(lp._yoursmine_target) then return end

        local t = CurTime() - lp._yoursmine_start_time
        local frac = 1 - math.Clamp((t / lp._yoursmine_total_dur), 0, 1)

        DrawMotionBlur(0.1, 0.8 * frac, 0.01)
        DrawToyTown(2, ScrH()/2)
		DrawBloom( 0.65, 1 * frac, 9, 9, 1, 1, 1, 1, 1 )
    end)

	hook.Add("PrePlayerDraw", "fh_yoursmine_ply", function(ply)
		if not IsValid(LocalPlayer()._yoursmine_target) then return end
		if ply == LocalPlayer()._yoursmine_target then
			return true
		end
	end)
	
	LocalPlayer():ScreenFade( SCREENFADE.IN, Color( 0, 0, 0, 180 ), 2, 0 )
end)

net.Receive("fh_stop_yoursmine_view", function()
    hook.Remove("CalcView", "fh_yoursmine_view")
    hook.Remove("PrePlayerDraw", "fh_yoursmine_ply")
    hook.Remove("RenderScreenspaceEffects", "fh_yoursmine_fx")
    LocalPlayer()._yoursmine_target = nil
    LocalPlayer()._yoursmine_start_time = nil
    LocalPlayer()._yoursmine_initial_phase_duration = nil
    LocalPlayer()._yoursmine_rotation_duration = nil
    LocalPlayer()._yoursmine_total_dur = nil
	
	LocalPlayer():DrawViewModel( true, 0 )
	
	LocalPlayer():ScreenFade( SCREENFADE.IN, Color( 0, 0, 0, 180 ), 2, 0 )
	
	local ent = pills.getMappedEnt(LocalPlayer())
	
	if IsValid(ent) and table.HasValue(animatronics, ent) then
		table.RemoveByValue(animatronics, ent)
	end
end)