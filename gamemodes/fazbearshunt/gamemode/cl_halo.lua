local highlightEnabled = false

local visionSuccessSound = "vision_success.wav"
local visionUnsuccessSound = "vision_unsuccess.wav"
local visionAffectedSound = "vision_affected.wav"
local visionUnaffectedSound = "vision_unaffected.wav"

local visionSuccessCake = "vision_success_cake.wav"
local visionAffectedCake = "vision_affected_cake.wav"

local affectedPlayers = {}
local animatronics = {}
local teammates = {}

net.Receive("NotifySpectators", function()
	if LocalPlayer():Team() != TEAM_SPECTATOR then return end
	
	local players = net.ReadTable()
	local ply = net.ReadEntity()
	local player = ''
	
	if (ply:SteamID64() == "76561199015248705") then 
		player = 'пиздюк'
	elseif (ply:SteamID64() == "76561198258358427") then
		player = "мумук"
	else
		player = ply:Nick()
	end	
	
	chat:AddText(Color( 255, 0, 0 ), player, Color( 180, 20, 20 ), ' ', language.GetPhrase("fuppr.highlight_specs"), ': ', Color( 170, 55, 50 ), table.concat(players, ", "))
end)

net.Receive("AddAffectedPlayers", function()
    players = net.ReadTable()
	
	for _, targetPlayer in ipairs(players) do
		if !table.HasValue(affectedPlayers, targetPlayer) then
			table.insert(affectedPlayers, targetPlayer)
		end
		
		if timer.Exists( "RemoveAffectedPlayer"..targetPlayer:SteamID64() ) then
			timer.Remove( "RemoveAffectedPlayer"..targetPlayer:SteamID64())
		end
		
		timer.Create( "RemoveAffectedPlayer"..targetPlayer:SteamID64(), conVars.halo_time:GetFloat(), 1, function()
			table.RemoveByValue(affectedPlayers, targetPlayer)
		end)
	end
end)

function addAffected(ply)
	if !table.HasValue(affectedPlayers, ply) then
		table.insert(affectedPlayers, ply)
	end
	
	if timer.Exists( "RemoveAffectedPlayer"..ply:SteamID64() ) then
		timer.Remove( "RemoveAffectedPlayer"..ply:SteamID64())
	end
	
	timer.Create( "RemoveAffectedPlayer"..ply:SteamID64(), conVars.halo_time:GetFloat(), 1, function()
		table.RemoveByValue(affectedPlayers, ply)
	end)
end

local target
function addPermanentAffected(ply)
	if !table.HasValue(affectedPlayers, ply) then
		table.insert(affectedPlayers, ply)
	end
	target = ply
	toggleShadows(false)
end

function toggleShadows(bool)
	if bool then
		for _, ply in ipairs(player.GetAll()) do
            ply:DrawShadow(true)
		end
	else
		for _, ply in ipairs(player.GetAll()) do
			if ply ~= target and ply:Team() != 2701 then
				ply:DrawShadow(false)
			end
		end
	end
end

net.Receive("fh_addaffected_stalk", function()
	addPermanentAffected(net.ReadEntity())
end)

net.Receive("NotifySoundCupcakeOwner", function()
	surface.PlaySound(visionSuccessCake)
end)

net.Receive("SF_cantout", function()
	surface.PlaySound("sfreddyerror.wav")
end)

net.Receive("NotifyCupcakeVictim", function()
	surface.PlaySound(visionAffectedCake)
end)

net.Receive("fh_yoursmine_bonnie_snd", function()
	surface.PlaySound('bonnie_ability_bonnie.wav')
end)

net.Receive("fh_yoursmine_target_snd", function()
	surface.PlaySound('bonnie_ability_target.wav')
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
		drawHighlightTimer()
		surface.PlaySound(visionAffectedSound)
	end
end)

local mySound
local isPlaying = false

local function UpdateSound()
    if mySound and isPlaying then
        mySound:ChangeVolume(1, 0)
    end
end

net.Receive("fh_stalk_sound_play", function()
	local ply = LocalPlayer()
	
    if mySound then
        mySound:Stop()
    end
    mySound = CreateSound(ply, "freddy_stalking.wav")
    mySound:SetSoundLevel(0)
    mySound:Play()
	
    isPlaying = true
    timer.Create("UpdateMySoundTimer", 0.1, 0, UpdateSound)
end)

net.Receive("fh_stalk_sound_stop", function()
    if mySound then
        mySound:Stop()
        mySound = nil
        isPlaying = false

        timer.Remove("UpdateMySoundTimer")
    end
end)

net.Receive("PlayHighlightSounds", function()
    local isAffected = net.ReadBool()
    if isAffected then
		surface.PlaySound(visionAffectedSound)
		drawHighlightTimer()
    else
		surface.PlaySound(visionUnaffectedSound)
    end
end)

function drawHighlightTimer()
	hook.Add("HUDPaint", "fh_hl_overlay_draw", drawHighlight)
	
	if timer.Exists('fh_hud_hl_overlay') then
		timer.Remove('fh_hud_hl_overlay')
	end
	
	timer.Create( "fh_hud_hl_overlay", conVars.halo_time:GetFloat(), 1, function()
		hook.Remove("HUDPaint", "fh_hl_overlay_draw")
	end)
end

function drawHighlight()
    surface.SetDrawColor(255, 255, 255, 23)
    
    surface.SetMaterial(Material("vgui/highlightOverlay.png"))
    
    surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
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
	halo.Add(affectedPlayers, Color(255, 0, 0, 255), 0.5, 0.5, 1, true, true)
	halo.Add(animatronics, Color(255, 155, 0, 255), 0.5, 0.5, 1, true, true)
	halo.Add(teammates, Color(0, 255, 0, 255), 0.5, 0.5, 1, true, true)
end)

hook.Add("HUDPaint", "PlayerDrawAnywhere", function()
    cam.Start3D()
        for k,v in pairs(affectedPlayers) do
            if v ~= LocalPlayer() and v:IsValid() and v:Health() > 0 then
                v:DrawModel()
            end
        end
    cam.End3D()
end)

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
end)

net.Receive("fh_start_yoursmine_view", function()
    local target = net.ReadEntity()
    LocalPlayer().fh_target_player = target
    LocalPlayer().fh_start_time = CurTime()
    LocalPlayer().fh_initial_phase_duration = 5
    LocalPlayer().fh_rotation_duration = 0.7
    LocalPlayer().fh_total_duration = LocalPlayer().fh_initial_phase_duration + LocalPlayer().fh_rotation_duration
	
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
	
	local ent = pk_pills.getMappedEnt(LocalPlayer())
	
	if IsValid(ent) and table.HasValue(animatronics, ent) then
		table.RemoveByValue(animatronics, ent)
	end
end)