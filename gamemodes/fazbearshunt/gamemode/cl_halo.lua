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

net.Receive("NotifySoundCupcakeOwner", function()
	surface.PlaySound(visionSuccessCake)
end)

net.Receive("SF_cantout", function()
	surface.PlaySound("sfreddyerror.wav")
end)

net.Receive("NotifyCupcakeVictim", function()
	surface.PlaySound(visionAffectedCake)
end)

net.Receive("RemoveAffectedPlayer", function()
    targetPlayer = net.ReadEntity()
	if table.HasValue(affectedPlayers, targetPlayer) then
		table.RemoveByValue(affectedPlayers, targetPlayer)
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