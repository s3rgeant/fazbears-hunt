-- звук для аниматронов
local visionSuccessSound = "vision_success.wav"
local visionUnsuccessSound = "vision_unsuccess.wav"

local affectedPlayers = {}
local affectedPlayers_force = {}
local animatronics = {}
local teammates = {}

include("halo_module.lua")

hook.Add("PillApply", "fh_joinpill", function(ply, ent)
	timer.Simple(1, function()
		if IsValid(ent) then
			ply = ent:GetPillUser()
			
			if IsValid(ply) then
				animatronics[ply] = true
			end
		end
	end)
end)

hook.Add("OnReloaded", "reloaded_clhalo", function()
	for _, ent in ents.Iterator() do
		if ent:GetClass() == "pill_costume" then
			ply = ent:GetPillUser()
			
			if IsValid(ply) then
				animatronics[ply] = true
			end
		end
	end
end)

hook.Add("OnEntityCreated", "fh_plushtrap_halo", function(ent)
	if ent:GetClass() == "plushtrap" then
		if IsValid(ent) then
			animatronics[ent] = true
		end
	end
end)

hook.Add("EntityRemoved", "fh_plushtrap_hao", function(ent)
	if ent:GetClass() == "plushtrap" then
		animatronics[ent] = nil
	end
end)

hook.Add("PillRestore", "fh_restorepill", function(ply, ent)
	animatronics[ply] = nil
end)

hook.Add( "NotifyShouldTransmit", "fh_animatronic_transmit", function( entity, started )
	if entity:IsPlayer() then
		local ply = entity
		if !animatronics[ply] and ply:GetPill() then
			animatronics[ply] = true
		end
	end
end)

local myself

local fh_halo_teammates = CreateClientConVar('fh_halo_teammates', 1, true, false, 'Highlight Teammates? (Animatronics Only) Turn Off for Performance.', 0, 1)

net.Receive("NotifySpectators", function()
	local players = net.ReadTable()
	local ply = net.ReadEntity()
	local player = IsValid(ply) and ply:Nick() or "UNKNOWN USER"
	
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
local function collectSpects(lp, rule)
	local lp_obsmode = lp:GetObserverMode()
	local out = {}
	
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
			
			local entry
			if !IsValid(ent) and ply:GetMaterial() == "models/null" then
				entry = OUTLINE.NormalizeEntry(rule, {
					ent = ply,
					outline_color = SPECTATOR_COLOR,
					fill_color = SPECTATOR_COLOR
				})
			elseif IsValid(ent) and ent:GetMaterial() == "models/null" then
				entry = OUTLINE.NormalizeEntry(rule, {
					ent = ent,
					outline_color = SPECTATOR_COLOR,
					fill_color = SPECTATOR_COLOR
				})
			end
			if entry then
				out[#out + 1] = entry
			end
		end
	end
	return (#out > 0) and out or nil
end 

local SPECTATOR_COLOR = Color(155, 0, 255, 255)
OUTLINE.RegisterRule("spectators", {
    priority = 10,
    render_max_dist = 3000,

    outline_color = SPECTATOR_COLOR,
    outline_width = 3,
    outline_min_dist = 1000,
    outline_max_dist = 2200,

    fill_color = SPECTATOR_COLOR,
    fill_min_dist = 1500,
    fill_max_dist = 2600,

    mode = OUTLINE_MODE_VISIBLE,
    collect = collectSpects
})

local function getAffected(lp, rule)
    if not istable(affectedPlayers) then return nil end

    local out = {}
    local maxDist = tonumber(rule.render_max_dist) or math.huge
    local maxDistSqr = maxDist > 0 and (maxDist * maxDist) or math.huge

    for ent, color in pairs(affectedPlayers) do
        if not IsValid(ent) then continue end
        if not ent:IsPlayer() then continue end
        if ent == lp then continue end
        if not ent:Alive() then continue end
        if ent:Team() == TEAM_SPECTATOR then continue end
        if ent:Health() <= 0 then continue end
        if ent.IsInvisible and ent:IsInvisible() then continue end
		local pos = ent:GetPos()
		if !pos:ToScreen().visible then continue end

        local entry = OUTLINE.NormalizeEntry(rule, {
            ent = ent,
            outline_color = color or color_white,
            fill_color = color or color_white
        })

        if entry then
            out[#out + 1] = entry
        end
    end

    return (#out > 0) and out or nil
end

OUTLINE.RegisterRule("affected_players", {
    priority = 100,
    render_max_dist = 9000,

    outline_color = Color(255, 0, 0, 255),
    outline_width = 3,
    outline_min_dist = 800,
    outline_max_dist = 2000,

    fill_color = Color(255, 0, 0, 255),
    fill_min_dist = 1000,
    fill_max_dist = 1800,

    mode = OUTLINE_MODE_BOTH,
    collect = getAffected
})
local function GetViewOrigin(ply)
    local viewEnt = ply:GetViewEntity()

    if IsValid(viewEnt) then
        if viewEnt:IsPlayer() then
            return viewEnt:EyePos()
        end

        return viewEnt:GetPos()
    end

    return ply:EyePos()
end

local CUPCAKE_COLOR   = Color(255, 155, 0, 255)
local function getCupcakes(lp, rule)
    local pillEnt = pills.getMappedEnt(lp)
    if not IsValid(pillEnt) or not pillEnt.formTable then return nil end
    if pillEnt.formTable.name ~= "pill_wchica2" then return nil end

    local out = {}
    local viewOrigin = GetViewOrigin(lp)
    local maxDist = tonumber(rule.render_max_dist) or math.huge
    local maxDistSqr = maxDist > 0 and (maxDist * maxDist) or math.huge

    for _, ent in ipairs(ents.FindByClass("cakemine")) do
        if not IsValid(ent) then continue end
        if not ent.DrawModel then continue end

        local mdl = ent:GetModel()
        if not mdl or mdl == "" then continue end

        if ent:GetPos():DistToSqr(viewOrigin) > maxDistSqr then
            continue
        end

        if not ent:GetPos():ToScreen().visible then
            continue
        end

        local entry = OUTLINE.NormalizeEntry(rule, {
            ent = ent,
            outline_color = CUPCAKE_COLOR,
            fill_color = CUPCAKE_COLOR
        })

        if entry then
            out[#out + 1] = entry
        end
    end

    return (#out > 0) and out or nil
end

OUTLINE.RegisterRule("cupcakes", {
    priority = 20,
    render_max_dist = 9000,

    outline_color = CUPCAKE_COLOR,
    outline_width = 4,
    outline_min_dist = 500,
    outline_max_dist = 2000,
    
    fill_color = CUPCAKE_COLOR,
    fill_min_dist = 400,
    fill_max_dist = 2000,

    mode = OUTLINE_MODE_BOTH,
    collect = getCupcakes
})

local TEAMMATE_COLOR = Color(0, 255, 0)
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
	
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
	
    local haloTeammates = GetConVar("fh_halo_teammates")
    if haloTeammates and not haloTeammates:GetBool() and ply:IsAnimatronic() then return end
	
	if table.IsEmpty(animatronics) then return end
	
    if ply:IsAnimatronic() or ply:GetNWBool("AnimVisibilityFH") then
		draw_orbs(animatronics, nil, GetGlobal2Float("FarZ", 8000))
	end
end)

net.Receive("fh_hl_animatronics", function()
	surface.PlaySound("human_gift_vision.wav")
end)

local function ResolveTeammateColor(lp, ent, storedColor)
    if IsColor(storedColor) then
        return storedColor
    end

    if !lp:IsAnimatronic() and killers and killers.getColor and ent.GetPillName then
        local pillName = ent:GetPillName()
        if pillName then
            local killerColor = killers.getColor(pillName)
            if IsColor(killerColor) then
                return killerColor
            end
        end
    end

    return TEAMMATE_COLOR
end

local forcetmdistance = 1100
local function getTeammates(lp, rule)
    local haloTeammates = GetConVar("fh_halo_teammates")
    if haloTeammates and not haloTeammates:GetBool() and lp:IsAnimatronic() then return nil end
    if not lp:IsAnimatronic() and not lp:GetNWBool("AnimVisibilityFH") then return nil end

    if not istable(animatronics) or table.IsEmpty(animatronics) then return nil end

    local out = {}
    local viewOrigin = GetViewOrigin(lp)
    local maxDist = tonumber(rule.render_max_dist) or math.huge
    local maxDistSqr = maxDist > 0 and (maxDist * maxDist) or math.huge

    for ent, storedColor in pairs(animatronics) do
		if !IsValid(ent) then continue end
		if ent:IsPlayer() then 
			if ent:Team() ~= TEAM_PILLS then continue end
			if ent == lp then continue end 
			ent = ent:GetPill() 
		end
        if not IsValid(ent) then continue end
        if not ent.DrawModel then continue end
		
		local pos = ent:GetPos() + ent:OBBCenter()
		
		local distance = pos:DistToSqr(viewOrigin)
        if distance > maxDistSqr then
            continue
        end
		
		local tr = util.TraceLine( {
			start = viewOrigin,
			endpos = pos,
			filter = function(ent)
				return not ent:IsPlayer()
			end,
			mask = MASK_VISIBLE_AND_NPCS,
		})
		
		if not tr.Hit and distance < forcetmdistance*forcetmdistance then continue end
		
        if not pos:ToScreen().visible then
            continue
        end

        local resolvedColor = ResolveTeammateColor(lp, ent, storedColor)
		
        local entry = OUTLINE.NormalizeEntry(rule, {
            ent = ent,
            outline_color = resolvedColor,
            fill_color = resolvedColor
        })

        if entry then
            out[#out + 1] = entry
        end
    end

    return (#out > 0) and out or nil
end

OUTLINE.RegisterRule("animatronics", {
    priority = 30,
    render_max_dist = 9000,

    outline_color = TEAMMATE_COLOR,
    outline_width = 3,
    outline_min_dist = 1000,
    outline_max_dist = 2200,
    
    fill_color = TEAMMATE_COLOR,
    fill_min_dist = 1500,
    fill_max_dist = 2600,

    mode = OUTLINE_MODE_BOTH,
    collect = getTeammates
})

hook.Add("HUDPaint", "fh_cupcake_count_draw", function()
	local ent = pills.getMappedEnt(LocalPlayer())
	if not IsValid(ent) then return end
	if ent.formTable and ent.formTable.name ~= "pill_wchica2" then return end
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

local speaker = Material("voice/icntlk_pl.vtf")
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
				
				local ent = target:GetPill()
				
                if IsValid(ent) and killers.GetFullName(ent:GetPillName()) and ply:IsAnimatronic() then
					local owner = ent:GetPillUser()
                    
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
                    local name = killers.GetFullName(ent:GetPillName())
                    if IsValid(owner) and owner:IsPlayer() then
                        nickname = owner:Nick()
                    end

                    local pillMaterial = killers.GetAvatar(ent:GetPillName())
                    if pillMaterial then
                        ourColor = color_white
                    end

					if IsValid(owner) and owner:VoiceVolume() > 0 then
						local aa = owner:VoiceVolume() * 255
						surface.SetDrawColor(aa, aa, aa, 255)
						surface.SetMaterial(speaker)
						surface.DrawTexturedRect(drawX - textureSize, drawY - textureSize*2, textureSize*2, textureSize*2)
					end
                    surface.SetDrawColor(ourColor.r, ourColor.g, ourColor.b, alpha)
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
				
                if IsValid(ent) and killers.GetFullName(ent:GetPillName()) and ply:IsSurvivor() then
					ourColor = IsColor(color) and color or killers.getColor(ent:GetPillName())
				end

				surface.SetDrawColor(ourColor.r, ourColor.g, ourColor.b, alpha)
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
	local myself = LocalPlayer()

    local target = net.ReadEntity()
    myself._yoursmine_target = target
    myself._yoursmine_start_time = CurTime()
    myself._yoursmine_initial_phase_duration = 5
    myself._yoursmine_rotation_duration = 0.7
    myself._yoursmine_total_dur = LocalPlayer()._yoursmine_initial_phase_duration + LocalPlayer()._yoursmine_rotation_duration
	
	myself:DrawViewModel( false, 0 )
	
	myself:SetFOV(0, 0)
	
	local ent = pills.getMappedEnt(myself)
	
	animatronics[myself] = true
	
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