include( "shared.lua" )

pcall(require,"pk_pills")

include( "cl_admin.lua" )
include( "cl_halo.lua" )
include( "cl_playerlist.lua" )
include( "cl_hud.lua" )
include( "cl_nightvision.lua" )
include( "cl_spechud.lua" )
include( "cl_horror.lua" )
include( "cl_timer.lua" )

include( "animsoundf2.lua" )
include("pill_fnaf2.lua")

hook.Add("HUDDrawTargetID", "HidePlayerNames", function()
	return false
end)

hook.Add("ShouldCollide", "CustomPlayerCollision", function(ent1, ent2)
    if ent1:GetCollisionGroup() == COLLISION_GROUP_WORLD or ent2:GetCollisionGroup() == COLLISION_GROUP_WORLD then
        return false
    end
    return true
end)

hook.Add( "PlayerBindPress", "fh_flash_nv", function( ply, bind, pressed )
	if (ply:Team() == 2701 or ply:Team() == TEAM_SPECTATOR) and ( string.find( bind, "impulse 100" ) ) and pressed then
		ToggleNightVision()
		return true
	end
end )

hook.Add("InitPostEntity", "fh_player_fullconnect", function()
	net.Start('fh_initpostentity')
	net.SendToServer()
end)

net.Receive("fh_chat_message", function()
	local nick = net.ReadString()
	local text = net.ReadString()
	local dead = net.ReadBool()
	local color = net.ReadColor()
	local bTeam = net.ReadBool()
	local teamInt = net.ReadFloat()

	if !dead then
		if !bTeam then
			chat.AddText(color, nick, Color(255, 255, 255), ': ', text)
		elseif LocalPlayer():Team() == teamInt then
			chat.AddText(Color(25, 160, 35), '(TEAM) ', color, nick, Color(255, 255, 255), ': ', text)
		end
	elseif LocalPlayer():Team() == teamInt then
		chat.AddText(Color(255,0,0), '*DEAD* ', color, nick, Color(255, 255, 255), ': ', text)
	end
end)

net.Receive("KillerPicked", function()
    local num = net.ReadUInt(8)
    local playerName = net.ReadString()
    local animatronicName = net.ReadString()
    local color = net.ReadColor()
    
    chat.AddText(
        color, "(" .. num .. ") - ", playerName, " - ", language.GetPhrase("fuppr.round.became"), " ", animatronicName
    )
end)

net.Receive("AnimatronicsWin", function()
    local VIP = net.ReadString()
			
	chat:AddText(" ")
	chat:AddText(Color( 228, 0, 70 ), "#### ПОБЕДА АНИМАТРОНИКОВ ####")
	chat:AddText(Color( 255, 225, 25 ), language.GetPhrase("fuppr.results_mvp"), " ", Color(255, 255, 255), '- ', VIP)
	chat:AddText(" ")
end)

net.Receive("SurvivorsWin", function()
	local players = net.ReadTable()
	
	chat:AddText(" ")
	chat:AddText(Color( 0, 182, 255 ), "#### ПОБЕДА ВЫЖИВШИХ ####")
	chat:AddText(Color( 255, 225, 25 ), language.GetPhrase("fuppr.results_survivors"), " ", Color(255, 255, 255), '- ', table.concat(players, ", "))
	chat:AddText(" ")
end)
	
net.Receive("JumpscareLight", function()
	local ply = LocalPlayer()
	local light = DynamicLight(ply:EntIndex())
	if light then
		light.pos = ply:LocalToWorld(ply:OBBCenter())
		light.r = 255
		light.g = 255
		light.b = 255
		light.brightness = 1.3
		light.Decay = 20
		light.Size = 128
		light.DieTime = CurTime() + 1.6
	end
end)
	
net.Receive("SetKillerAngle", function()
	local ply = LocalPlayer()
	local ent = net.ReadEntity()
	if IsValid(ent) then
		timer.Create('fh_rotatekiller', 0.1, 5, function()
			if IsValid(ent) then
				ent:ResetAngle()
			end
		end)
	end
end)