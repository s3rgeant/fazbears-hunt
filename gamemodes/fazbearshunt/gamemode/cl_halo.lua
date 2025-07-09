local highlightEnabled = false

-- звук для аниматронов
local visionSuccessSound = "vision_success.wav"
local visionUnsuccessSound = "vision_unsuccess.wav"

-- звук для выживших
local visionAffectedSound = "vision_affected.wav"
local visionUnaffectedSound = "vision_unaffected.wav"

-- спрингтрап
local spr_visionAffectedSound = "fnaf3/spr_vision_affected.wav"
local spr_visionUnaffectedSound = "fnaf3/spr_vision_unaffected.wav"

local affectedPlayers = {}
local animatronics = {}
local teammates = {}

local fh_halo_teammates = CreateClientConVar('fh_halo_teammates', 1, true, false, 'Highlight Teammates? (Animatronics Only) Turn Off for Performance.', 0, 1)

net.Receive("NotifySpectators", function()
	if (LocalPlayer():Team() != TEAM_SPECTATOR) then return end
	
	local players = net.ReadTable()
	local ply = net.ReadEntity()
	local player = ply:Nick()
	
	chat:AddText(Color( 255, 0, 0 ), player, Color( 180, 20, 20 ), ' ', language.GetPhrase("fuppr.highlight_specs"), ': ', Color( 170, 55, 50 ), table.concat(players, ", "))
end)

function addAffected(ply, duration)
	local duration = duration or conVars.halo_time:GetFloat()
	
	if !table.HasValue(affectedPlayers, ply) then
		table.insert(affectedPlayers, ply)
	end
	
	if timer.Exists( "RemoveAffectedPlayer"..ply:SteamID64() ) then
		timer.Remove( "RemoveAffectedPlayer"..ply:SteamID64() )
	end
	
	timer.Create( "RemoveAffectedPlayer"..ply:SteamID64(), duration, 1, function()
		if target == ply then return end
		table.RemoveByValue(affectedPlayers, ply)
	end)
end

net.Receive("AddAffectedPlayers", function()
    players = net.ReadTable()
	
	for _, targetPlayer in ipairs(players) do
		addAffected(targetPlayer)
	end
end)

local target
function fh_addpermanent_affected_freddy(ply)
	if !table.HasValue(affectedPlayers, ply) then
		table.insert(affectedPlayers, ply)
	end
	target = ply
	toggleShadows(false)
end

function fh_add_affected_springtrap(ply)
end

function toggleShadows(bool)
	local players = player.GetAll()
	if bool then
		for _, ply in ipairs( players ) do
            ply:DrawShadow(true)
		
			for _, wep in ipairs(dude:GetWeapons()) do
				if IsValid(wep) then
					wep:SetNoDraw(false)
					wep:DrawShadow(true)
					wep:SetRenderMode(RENDERMODE_NORMAL)
				end
			end
		end
	else
		for _, ply in ipairs( players ) do
			if ply ~= target and ply:Team() != 2701 then
				ply:DrawShadow(false)
		
				for _, wep in ipairs(dude:GetWeapons()) do
					if IsValid(wep) then
						wep:SetNoDraw(true)
						wep:DrawShadow(false)
						wep:SetRenderMode(RENDERMODE_NONE)
					end
				end
			end
		end
	end
end

net.Receive("fh_addaffected_stalk", function()
	fh_addpermanent_affected_freddy(net.ReadEntity())
end)

net.Receive("fh_addaffected_springtrap", function()
	addAffected(net.ReadEntity(), 90)
end)

net.Receive("RemoveAffectedPlayer", function()
    targetPlayer = net.ReadEntity()
	if table.HasValue(affectedPlayers, targetPlayer) then
		table.RemoveByValue(affectedPlayers, targetPlayer)
	end
	
	if targetPlayer == target then
		target = nil
		toggleShadows(true)
	end
end)

net.Receive("fh_hl_animatronics", function()
	for _, ply in ipairs(team.GetPlayers(2701)) do
		if !table.HasValue(animatronics, ply) then
			table.insert(animatronics, pk_pills.getMappedEnt(ply))
		end
	end
	surface.PlaySound("human_gift_vision.wav")
	timer.Simple(30, function()
		table.Empty(animatronics)
	end)
end)

net.Receive("fh_hl_teammates", function()
	if LocalPlayer():Team() == 2701 then
		for _, ply in ipairs(team.GetPlayers(2701)) do
			if !table.HasValue(teammates, ply) and LocalPlayer() ~= ply then
				table.insert(teammates, pk_pills.getMappedEnt(ply))
			end
		end
	end
end)

net.Receive("fh_uhl_teammates", function()
	table.Empty(teammates)
end)

net.Receive("fh_hl_badkid", function ()
	local player = net.ReadEntity()
	if LocalPlayer() ~= player and LocalPlayer():Team() == 2701 then
		addAffected(player)
		surface.PlaySound("vision_unbox_success.wav")
	end
	
	if LocalPlayer() == player then
		drawHighlightTimer(true)
		surface.PlaySound(visionAffectedSound)
	end
end)

net.Receive("PlayHighlightSounds", function()
    local isAffected = net.ReadBool()
	local springtrap = net.ReadBool() or false
    if isAffected then
		surface.PlaySound(springtrap and spr_visionAffectedSound or visionAffectedSound)
		drawHighlightTimer(true)
    else
		surface.PlaySound(springtrap and spr_visionUnaffectedSound or visionUnaffectedSound)
    end
end)

net.Receive("fh_draw_hl_overlay", function()
    local bool = net.ReadBool()
    drawHighlightTimer(bool)
end)

net.Receive("fh_nodraw_hl_overlay", function()
	hook.Remove("HUDPaint", "fh_hl_overlay_draw")
end)
	
function drawHighlightTimer(bool)
	hook.Add("HUDPaint", "fh_hl_overlay_draw", drawHighlight)
	
	if timer.Exists('fh_hud_hl_overlay') then
		timer.Remove('fh_hud_hl_overlay')
	end
	
	if !bool then return end
	timer.Create( "fh_hud_hl_overlay", conVars.halo_time:GetFloat(), 1, function()
		hook.Remove("HUDPaint", "fh_hl_overlay_draw")
	end)
end

local highlight_mat = Material("vgui/highlightOverlay.png")
function drawHighlight()
	if !GetConVar("cl_drawhud"):GetBool() then return end
    surface.SetDrawColor(255, 255, 255, 23)
    
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

hook.Add( "PreDrawHalos", "HaloDo", function()
	-- ДЛЯ ВЫЖИВШИХ
	halo.Add(animatronics, Color(255, 155, 0, 255), 0.5, 0.5, 1, true, true)
	
	-- ДЛЯ АНИМАТРОНИКОВ
	halo.Add(affectedPlayers, Color(255, 0, 0, 255), 0.5, 0.5, 1, true, true)
	
	if fh_halo_teammates:GetBool() then
	
		halo.Add(teammates, Color(0, 255, 0, 255), 0.5, 0.5, 1, true, true)
		
		if LocalPlayer():Team() == 2701 then
			halo.Add(ents.FindByClass("plushtrap"), Color(0, 255, 0, 255), 0.5, 0.5, 1, true, true)
		end
		
	end
	
	local ent = pk_pills.getMappedEnt(LocalPlayer())
	
	if ent and ent.formTable then
		if ent.formTable.name == "pill_wchica2" then -- ДЛЯ ЧИКИ
			halo.Add(ents.FindByClass("cakemine"), Color(255, 155, 0, 255), 0.5, 0.5, 1, true, true)
		end
	end
end)

hook.Add("HUDPaint", "fh_cupcake_count_draw", function()
	local ent = pk_pills.getMappedEnt(LocalPlayer())
	if !ent then return end
	if ent.formTable and ent.formTable.name != "pill_wchica2" then return end
    local cakemines = ents.FindByClass("cakemine")

    for i, ent in ipairs(cakemines) do
        if not IsValid(ent) then continue end

        local pos = ent:GetPos():ToScreen() -- Преобразуем координаты в экранные

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

local target_orb = Material("vgui/target_orb.png", "noclamp smooth")
local maxDistance = 1650

hook.Add("HUDPaint", "fh_draw_affected", function()
    cam.Start3D()
        for k, v in pairs(affectedPlayers) do
            if v ~= LocalPlayer() and v:IsValid() and v:Health() > 0 then
                v:DrawModel()
            end
        end
    cam.End3D()
	
	draw_orbs(affectedPlayers)
end)

function draw_orbs(tbl, material)
	local material = material or target_orb

    local ply = LocalPlayer()
    if !IsValid(ply) or !ply:Alive() then return end
	
    local screenW, screenH = ScrW(), ScrH()
    local halfW, halfH = screenW / 2, screenH / 2
    local textureSize = 64 / 2 -- Половина размера текстуры
    
    for _, target in ipairs(tbl) do
        if IsValid(target) and target:Alive() and target:Team() != TEAM_SPECTATOR then
            local min, max = target:GetCollisionBounds()
            local targetPos = target:GetPos() + Vector(0, 0, (min.z + max.z) / 2) -- Размещение в центре хитбокса
            local screenPos = targetPos:ToScreen()
            local dist = ply:GetPos():Distance(target:GetPos())
            
            if dist > maxDistance then
                local alpha = math.Clamp((dist - maxDistance) / 200, 0, 1) * 255 -- Плавное появление
                
                -- ограничиваем координаты, чтобы текстура не уходила за границы экрана более чем на половину
                local clampedX = math.Clamp(screenPos.x, textureSize, screenW - textureSize)
                local clampedY = math.Clamp(screenPos.y, textureSize, screenH - textureSize)
                
                surface.SetDrawColor(255, 255, 255, alpha)
                surface.SetMaterial(material)
                surface.DrawTexturedRect(clampedX - textureSize, clampedY - textureSize, 64, 64)
            end
        end
    end
end

hook.Add("PrePlayerDraw", "fh_stalker_pv", function(ply)
	if target then
		if (ply ~= target and ply:Team() != 2701) then
			return true
		end
	end
end)

hook.Add("PostCleanupMap", "fh_cleanup", function(ply)
	target = nil
	toggleShadows(true)
	table.Empty(affectedPlayers)
	
	hook.Remove("HUDPaint", "fh_hl_overlay_draw")
	hook.Remove("HUDPaint", "fh_pt_draw_affected")
	
	hook.Remove("HUDPaint", "fh_plushalert_draw")
	hook.Remove("HUDPaint", "fh_plushalert_removing")
	
	if IsValid(selector) then
		selector:Close()
	end
end)

net.Receive("fh_start_yoursmine_view", function()
    local target = net.ReadEntity()
    LocalPlayer().fh_target_player = target
    LocalPlayer().fh_start_time = CurTime()
    LocalPlayer().fh_initial_phase_duration = 5
    LocalPlayer().fh_rotation_duration = 0.7
    LocalPlayer().fh_total_duration = LocalPlayer().fh_initial_phase_duration + LocalPlayer().fh_rotation_duration
	
	LocalPlayer():DrawViewModel( false, 0 )
	
	LocalPlayer():SetFOV(0, 0)
	
	local ent = pk_pills.getMappedEnt(LocalPlayer())
	
	if IsValid(ent) and !table.HasValue(animatronics, ent) then
		table.insert(animatronics, ent)
	end

    hook.Add("CalcView", "fh_yoursmine_view", function(viewer, origin, angles, fov)
        if viewer ~= LocalPlayer() then return end
        if not IsValid(viewer.fh_target_player) then return end

        local t = CurTime() - viewer.fh_start_time

        if t < viewer.fh_initial_phase_duration then
            local view = {}
            view.origin = viewer.fh_target_player:EyePos()
            view.angles = viewer.fh_target_player:EyeAngles()
            view.fov = fov
            return view
        elseif t < viewer.fh_total_duration then
            local progress = (t - viewer.fh_initial_phase_duration) / viewer.fh_rotation_duration
            progress = math.Clamp(progress, 0, 1)

            local view = {}
            view.origin = viewer.fh_target_player:EyePos()

            local targetPos = viewer:EyePos()
            local direction = (targetPos - viewer.fh_target_player:EyePos()):GetNormalized()
            local targetAngle = direction:Angle()

            local currentAngle = viewer.fh_target_player:EyeAngles()
            view.angles = LerpAngle(progress, currentAngle, targetAngle)
            view.fov = fov
            return view
        else
            local view = {}
            view.origin = viewer.fh_target_player:EyePos()
            local targetPos = viewer:EyePos()
            local direction = (targetPos - viewer.fh_target_player:EyePos()):GetNormalized()
            view.angles = direction:Angle()
            view.fov = fov
            return view
        end
    end)

    hook.Add("PrePlayerDraw", "fh_yoursmine_ply", function(ply)
        if not IsValid(LocalPlayer().fh_target_player) then return end
        if ply == LocalPlayer().fh_target_player then
            return true
        end
    end)
end)

net.Receive("fh_stop_yoursmine_view", function()
    hook.Remove("CalcView", "fh_yoursmine_view")
    hook.Remove("CalcView", "fh_yoursmine_ply")
    LocalPlayer().fh_target_player = nil
    LocalPlayer().fh_start_time = nil
    LocalPlayer().fh_initial_phase_duration = nil
    LocalPlayer().fh_rotation_duration = nil
    LocalPlayer().fh_total_duration = nil
	
	LocalPlayer():DrawViewModel( true, 0 )
	
	local ent = pk_pills.getMappedEnt(LocalPlayer())
	
	if IsValid(ent) and table.HasValue(animatronics, ent) then
		table.RemoveByValue(animatronics, ent)
	end
end)