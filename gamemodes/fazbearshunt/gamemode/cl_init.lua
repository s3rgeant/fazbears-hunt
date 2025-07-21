include( "shared.lua" )

pcall(require,"pills")

include( "cl_admin.lua" )
include( "cl_halo.lua" )
include( "cl_hud.lua" )
include( "cl_horror.lua" )
include( "cl_playerlist.lua" )
include( "cl_nightvision.lua" )
include( "cl_spechud.lua" )
include( "cl_sound.lua" )
include( "cl_timer.lua" )
include( "cl_optionmenu.lua" )

include( "terror_radius.lua" )

include( "mount/proximity.lua" )

include( "animsoundf2.lua" )
include( "voicelines.lua" )
include("pill_fnaf2.lua")
include("pill_fnaf3.lua")

function getTeam(team)
	local teamname = language.GetPhrase("fuppr.survivors_team")
	
	if team == 2701 or string.find(team, 'animatronic') then
		teamname = language.GetPhrase("fuppr.animatronics_team")
	elseif team == TEAM_SPECTATOR or string.find(team, 'kill') then 
		teamname = ' '
	end
	return teamname
end

hook.Add("HUDDrawTargetID", "HidePlayerNames", function()
	return false
end)

hook.Add("SetupMove", "CanMove", function(ply) -- иронично не работает)
	if ply:Team() == 2701 and ply:IsFlagSet(FL_FROZEN) then
		return true
	end
end)

hook.Add( "PlayerBindPress", "fh_flash_nv", function( ply, bind, pressed )
	if (ply:Team() == 2701 or ply:Team() == TEAM_SPECTATOR) and ( string.find( bind, "impulse 100" ) ) and pressed then
		ToggleNightVision()
		return true
	end
end )

hook.Add("PlayerStartVoice", "HideVoicePanels", function(ply)
    local listener = LocalPlayer()
    if ply == LocalPlayer() and listener:Team() != 2701 and listener:Team() != TEAM_SPECTATOR then
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
	if !IsValid(ply) then return end
	
    local listenerTeam = listener:Team()
    local speakerTeam = ply:Team() or TEAM_UNASSIGNED
	
    if listenerTeam == TEAM_SPECTATOR and speakerTeam == TEAM_SPECTATOR then
        return
    end

    if listenerTeam == 2701 and speakerTeam == 2701 then
        return
    end

    return false
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

net.Receive("KillerPicked", function()
    local num = net.ReadUInt(8)
    local playerName = net.ReadString()
    local animatronicName = net.ReadString()
    local color = net.ReadColor()
    
    chat.AddText(
        Color(255, 15, 15), playerName, " ", Color(255,255,255), language.GetPhrase("fuppr.round.became"), " ", color, language.GetPhrase(animatronicName)
    )
end)

net.Receive("AnimatronicsWin", function()
    local VIP = net.ReadString()
			
	chat:AddText(" ")
	chat:AddText(Color( 228, 0, 70 ), language.GetPhrase("fazhunt.chat.animatronicwin") .. "!")
	chat:AddText(" ")
	chat:AddText(Color( 0, 225, 100 ), language.GetPhrase("fazhunt.stats.last_standing"), ": ", Color(255, 255, 255), '- ', VIP)
	chat:AddText(" ")
end)

net.Receive("SurvivorsWin", function()
	local players = net.ReadTable()
	
	chat:AddText(" ")
	chat:AddText(Color( 0, 182, 255 ), language.GetPhrase("fazhunt.chat.survivalswin") .. "!")
	chat:AddText(" ")
	chat:AddText(Color( 0, 225, 100 ), language.GetPhrase("fuppr.survivors_team"), ": ", Color(255, 255, 255), '- ', table.concat(players, ", "))
	chat:AddText(" ")
end)

net.Receive("fh_top_stats", function()
    local count = net.ReadUInt(8)

    for i = 1, count do
        local formatStr = language.GetPhrase("fazhunt.stats." .. net.ReadString())
        local nick = net.ReadString()
        local value = net.ReadUInt(32)

        chat.AddText(
            Color(255, 255, 0), nick,
            color_white, " " .. string.format(formatStr, value)
        )
    end
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

net.Receive("fh_animatronic_left_chatmessage", function()
	local imya = net.ReadString()

	LocalPlayer():ChatPrint(string.format(language.GetPhrase('fazhunt.chat.animleave'), imya ))
end)

local customViewPos = nil
local customViewAng = nil

local dynamic_firstperson = CreateClientConVar('fh_dynamic_firstperson', 1, true, false, 'Toggle dynamic firstperson (Animatronics only)')

hook.Add("CalcView", "fh_animatronic_head_bop", function(ply, pos, angles, fov)
	customViewPos = nil
    customViewAng = nil
	
    if !IsValid(ply) or !ply:Alive() or ply:GetMoveType() == MOVETYPE_NOCLIP or ply:GetCollisionGroup() == COLLISION_GROUP_DEBRIS or !dynamic_firstperson:GetBool() then return end
	
    local targetEnt = pills.getMappedEnt(ply)

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
    if !dynamic_firstperson:GetBool() or not customViewPos then return end

    return customViewPos, oldAng
end)


function GM:MouthMoveAnimation(ply)
    local weight = ply:IsSpeaking() and math.Clamp(ply:VoiceVolume() * 2, 0, 2) or 0

    local pillEnt = pills and pills.getMappedEnt and pills.getMappedEnt(ply)

	if IsValid(pillEnt) then
        local jawBones = { "bip_jaw", "Jaw", "Jaw_Bn", "Jaw_jnt", "JawInner" }
		local mp = 1

        for _, boneName in ipairs(jawBones) do
            local boneID = pillEnt:LookupBone(boneName)
			if boneName == "Jaw_Bn" then mp = -1 end
            if boneID then
                local angle = ply:IsSpeaking() and Angle(0, 0, -weight * 25 * mp) or Angle(0, 0, 0)
                pillEnt:ManipulateBoneAngles(boneID, angle)
            end
        end
    else
        local flexes = {
            ply:GetFlexIDByName("jaw_drop"),
            ply:GetFlexIDByName("left_part"),
            ply:GetFlexIDByName("right_part"),
            ply:GetFlexIDByName("left_mouth_drop"),
            ply:GetFlexIDByName("right_mouth_drop")
        }

        for _, v in ipairs(flexes) do
            if v and v >= 0 then
                ply:SetFlexWeight(v, weight)
            end
        end
    end
end

local history = {}
hook.Add("OnPlayerChat", "fh_chat_message", function(ply, text, team, dead)
    if not IsValid(ply) then return end
	
	local clr = teamColors[ ply:Team() ] or Color(90, 90, 90)
	
	local team_txt = (team and ply:Team() ~= TEAM_SPECTATOR) and "[TEAM] " or ""

    chat.AddText(
        Color(0, 190, 0), team_txt,
        clr, ply:Nick(),
        Color(255, 255, 255), ": ",
        Color(255, 255, 255), text
    )

    return true
end)

net.Receive("fh_chat_message", function()
	local nick = net.ReadString()
	local text = net.ReadString()
	local dead = net.ReadBool()
	local color = net.ReadColor()
	local bTeam = net.ReadBool()
	local teamInt = net.ReadFloat()
	
	local localply = LocalPlayer()
	
	if nick == localply:Nick() then
		table.insert(history, text)
		current_pos = table.Count(history)
	end

	if !dead then
		if !bTeam then
			chat.AddText(color, nick, Color(255, 255, 255), ': ', text)
		elseif localply:Team() == teamInt then
			chat.AddText(Color(25, 160, 35), '(TEAM) ', color, nick, Color(255, 255, 255), ': ', text)
		end
	elseif localply:Team() == teamInt then
		chat.AddText(Color(255,0,0), '*DEAD* ', color, nick, Color(255, 255, 255), ': ', text)
	end
end)

local current_pos = 0

hook.Remove("OnChatTab", "ULXPP.Autocomplete") -- в любом случае какая то хуета

hook.Add( "FinishChat", "qolchat_finish", function()
	current_pos = table.Count(history)
end )

hook.Add( "OnChatTab", "qolchat_tab", function( text )
	if table.IsEmpty(history) then return end
	
	if current_pos <= 0 then
		current_pos = table.Count(history)
	end
	
	local ret = history[current_pos]
	
	current_pos = current_pos - 1
	
	return ret
end )