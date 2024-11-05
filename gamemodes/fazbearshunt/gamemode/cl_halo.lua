local highlightEnabled = false

local visionSuccessSound = "vision_success.wav"
local visionUnsuccessSound = "vision_unsuccess.wav"
local visionAffectedSound = "vision_affected.wav"
local visionUnaffectedSound = "vision_unaffected.wav"

local visionSuccessCake = "vision_success_cake.wav"
local visionAffectedCake = "vision_affected_cake.wav"

local affectedPlayers = {}

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

net.Receive("PlayHighlightSounds", function()
    local isAffected = net.ReadBool()
    if isAffected then
		surface.PlaySound(visionAffectedSound)
    else
		surface.PlaySound(visionUnaffectedSound)
    end
end)

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