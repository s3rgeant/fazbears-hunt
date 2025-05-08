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
include( "cl_optionmenu.lua" )

include( "mount/proximity.lua" )

include( "animsoundf2.lua" )
include("pill_fnaf2.lua")

hook.Add("HUDDrawTargetID", "HidePlayerNames", function()
	return false
end)

hook.Add("ShouldCollide", "CustomPlayerCollision", function(ent1, ent2)
    if ent1:GetCollisionGroup() == COLLISION_GROUP_WORLD 
	or ent2:GetCollisionGroup() == COLLISION_GROUP_WORLD 
	or (ent1:GetCollisionGroup() == COLLISION_GROUP_DEBRIS and ent1:IsPlayer()) -- s freddy
	or (ent1:GetCollisionGroup() == COLLISION_GROUP_PASSABLE_DOOR and ent1:IsPlayer() and ent2:IsPlayer())
	or (ent2:GetCollisionGroup() == COLLISION_GROUP_PASSABLE_DOOR and ent2:IsPlayer() and ent1:IsPlayer())
	then
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

hook.Add("PlayerStartVoice", "HideVoicePanels", function(ply)
    if ply == LocalPlayer() and ply:Team() != 2701 then
        hook.Add("HUDPaint", "DrawLocalPlayerVoiceIcon", function()
            local x, y = (ScrW() / 2) - (64 / 2), ScrH() - 50 - (64 / 2)
			draw.RoundedBox(12, x, y, 64, 64, Color(0, 0, 0, 120))
			
            local x, y = (ScrW() / 2) - (48 / 2), ScrH() - 50 - (48 / 2)
            surface.SetMaterial(Material("voice/icntlk_pl.vtf"))
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawTexturedRect(x, y, 48, 48)
        end)
		return false
    end
	if (LocalPlayer():Team() == 2701 and ply:Team() != 2701) or (LocalPlayer():Team() == TEAM_SPECTATOR and ply:Team() != TEAM_SPECTATOR) then
		return false
	end
end)

hook.Add("PlayerEndVoice", "HideVoicePanels", function(ply)
    if ply == LocalPlayer() then
        hook.Remove("HUDPaint", "DrawLocalPlayerVoiceIcon")
    end
end)

hook.Add("InitPostEntity", "fh_player_fullconnect", function(ent)
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

net.Receive("ragColor", function(len)
	local rag = Entity(net.ReadInt(16))
	local col = net.ReadVector()

	rag.GetPlayerColor = function() return col end
end)

net.Receive("fh_set_calcview_entity", function(len)
	local entity = net.ReadEntity()
	
	print(entity)

	hook.Add("CalcView", "fh_override_entity_calcview", function(ply,pos,angles,fov)
		if !IsValid(entity) then
			hook.Remove("CalcView", "fh_override_entity_calcview")
			return
		end
		
		return {
			origin = entity:GetPos(),
			angles = entity:GetAngles(),
			fov = fov
		}
	end)
end)

local customViewPos = nil
local customViewAng = nil

local dynamic_firstperson = CreateClientConVar('fh_dynamic_firstperson', 1, true, false, 'Toggle dynamic firstperson (Animatronics only)')

hook.Add("CalcView", "fh_animatronic_head_bop", function(ply, pos, angles, fov)
	customViewPos = nil
    customViewAng = nil
	
    if !IsValid(ply) or !ply:Alive() or ply:GetMoveType() == MOVETYPE_NOCLIP or ply:GetCollisionGroup() == COLLISION_GROUP_DEBRIS or !dynamic_firstperson:GetBool() then return end
	
    local targetEnt = pk_pills.getMappedEnt(ply)

    if !IsValid(targetEnt) then return end

    local boneIndex = targetEnt:LookupBone("bip_head")
    if !boneIndex then return end

    local headPos = select(1, targetEnt:GetBonePosition(boneIndex))
    if !headPos then return end

    local adjustedHeadPos = Vector(pos.x, pos.y, headPos.z)
    local desiredPos = LerpVector(0.7, pos, adjustedHeadPos)

    local tr = util.TraceLine({
        start = ply:GetPos(),
        endpos = desiredPos,
        filter = ply,
        mask = MASK_SOLID_BRUSHONLY
    })

    local safePos = tr.Hit and tr.HitPos + tr.HitNormal * 4 or desiredPos

    customViewPos = safePos
    customViewAng = angles

    return {
        origin = safePos,
        angles = angles,
        fov = fov
    }
end)

local smoothedVM_Ang = nil
local smoothSpeed = 16

hook.Add("CalcViewModelView", "MatchViewModelToCustomView", function(wep, vm, oldPos, oldAng, pos, ang)
    if !dynamic_firstperson:GetBool() or not customViewPos or not customViewAng then return end

    if not smoothedVM_Ang then
        smoothedVM_Ang = Angle(customViewAng)
    end

    local angDiff = customViewAng - smoothedVM_Ang
    angDiff:Normalize()

    local delta = math.abs(angDiff.pitch) + math.abs(angDiff.yaw) + math.abs(angDiff.roll)

    local adaptiveSpeed = math.Clamp(8 + delta * 2, 8, 60)

    smoothedVM_Ang = LerpAngle(FrameTime() * adaptiveSpeed, smoothedVM_Ang, customViewAng)

    return customViewPos, smoothedVM_Ang
end)