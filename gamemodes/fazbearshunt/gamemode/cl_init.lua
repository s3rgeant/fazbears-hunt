fh = fh or {}

include( "shared.lua" )

pcall(require,"pills")

local function recursive_include(path)
	local files, folders = file.Find(path .. "*", "LUA")
	
	for _, file_name in ipairs(files) do
		if file_name == "cl_init.lua" then continue end
		local full_path = path .. file_name
		
		if file_name:StartWith("sh_") or file_name:StartWith("cl_") then
			include(full_path)
		end
	end
end

recursive_include("fazbearshunt/gamemode/utils/")
recursive_include("fazbearshunt/gamemode/")
recursive_include("fazbearshunt/gamemode/interface/")
recursive_include("fazbearshunt/gamemode/mount/")
recursive_include("fazbearshunt/gamemode/events/")
recursive_include("fazbearshunt/gamemode/support/")
recursive_include("fazbearshunt/gamemode/rounds/")

function getTeam(team)
	local teamname = language.GetPhrase("fazhunt.survivors_team")
	
	if team == 2701 or team == 27 or string.find(team, 'animatronic') then
		teamname = language.GetPhrase("fazhunt.animatronics_team")
	elseif team == TEAM_SPECTATOR or string.find(team, 'kill') then 
		teamname = ' '
	end
	return teamname
end

do
    local old_upper = string.upper

    local utf8_lc_uc = {
        ["а"]="А", ["б"]="Б", ["в"]="В", ["г"]="Г", ["д"]="Д", ["е"]="Е", ["ё"]="Ё",
        ["ж"]="Ж", ["з"]="З", ["и"]="И", ["й"]="Й", ["к"]="К", ["л"]="Л", ["м"]="М",
        ["н"]="Н", ["о"]="О", ["п"]="П", ["р"]="Р", ["с"]="С", ["т"]="Т", ["у"]="У",
        ["ф"]="Ф", ["х"]="Х", ["ц"]="Ц", ["ч"]="Ч", ["ш"]="Ш", ["щ"]="Щ", ["ъ"]="Ъ",
        ["ы"]="Ы", ["ь"]="Ь", ["э"]="Э", ["ю"]="Ю", ["я"]="Я",
    }

    string.upper = function(str)
        return (str:gsub("[%z\1-\127\194-\244][\128-\191]*", function(c)
            return utf8_lc_uc[c] or old_upper(c)
        end))
    end
end

killicon.AddAlias( "prop_physics_multiplayer", "prop_physics" )

hook.Add("HUDDrawTargetID", "HidePlayerNames", function()
	local lp = LocalPlayer()
	
	if IsValid(lp) and !lp:IsSuperAdmin() then return false end
	
	if !input.IsButtonDown( KEY_LALT ) or !input.IsButtonDown( KEY_E ) then
		return false
	end
end)

hook.Add( "StartCommand", "fh_cantattack", function( ply, cmd )
	if ply:IsAnimatronic() and !GetGlobal2Bool("roundActive") and GetGlobal2Bool("gameOn") then
		cmd:ClearMovement()
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_ATTACK2)
		cmd:RemoveKey(IN_RELOAD)
		cmd:RemoveKey(IN_JUMP)
	end
end)

hook.Add("InitPostEntity", "fh_player_fullconnect", function(ent)
	net.Start('fh_initpostentity')
	net.SendToServer()
end)

net.Receive("KillerPicked", function()
    local playerName = net.ReadString()
    local animatronicName = net.ReadString()
    local color = net.ReadColor()
    
    chat.AddText(
        Color(255, 15, 15), playerName, " ", Color(255,255,255), language.GetPhrase("fazhunt.round.became"), " ", color, language.GetPhrase(animatronicName)
    )
end)

net.Receive("AnimatronicsWin", function()
    local VIP = net.ReadString()
    local timeleft = net.ReadInt(16)
			
	chat:AddText(" ")
	chat:AddText(Color( 228, 0, 70 ), language.GetPhrase("fazhunt.chat.animatronicwin") .. "!")
	chat:AddText(" ")
	chat:AddText(Color( 0, 225, 100 ), language.GetPhrase("fazhunt.stats.last_standing"), ": ", Color(255, 255, 255), '- ', VIP)
	chat:AddText(" ")
	chat:AddText(Color( 0, 140, 190 ), language.GetPhrase("fazhunt.stats.round_time"), ": ", Color(255, 255, 255), formatTime(timeleft))
	chat:AddText(" ")
end)

net.Receive("SurvivorsWin", function()
	local players = net.ReadTable()
	
	chat:AddText(" ")
	chat:AddText(Color( 0, 182, 255 ), language.GetPhrase("fazhunt.chat.survivalswin") .. "!")
	chat:AddText(" ")
	chat:AddText(Color( 0, 225, 100 ), language.GetPhrase("fazhunt.survivors_team"), ": ", Color(255, 255, 255), '- ', table.concat(players, ", "))
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

hook.Add( "OnEntityCreated", "fh_RagdollColor", function( ent )
	if ent:GetClass() == "prop_ragdoll" then
		local ply = ent:GetOwner()
		if IsValid(ply) and ply:IsPlayer() then
			local color = ply:GetPlayerColor()
			ent.GetPlayerColor = function() return color end
		end
	end
end )

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
	local myself = LocalPlayer()
	if not IsValid(myself) then return end
	
	local imya = net.ReadString()

	myself:ChatPrint(string.format(language.GetPhrase('fazhunt.chat.animleave'), imya ))
end)

local jawBones = { "bip_jaw", "Jaw", "Jaw_Bn", "Jaw_jnt", "JawInner", "bip_lowerEndoJaw" }
local jawAngle = Angle(0,0,0)
function GM:MouthMoveAnimation(ply)
    local weight = ply:IsSpeaking() and math.Clamp(ply:VoiceVolume() * 2, 0, 2) or 0

    local pillEnt = ply:GetPill()

	if IsValid(pillEnt) then
		local mp = 1
		
		local talkie = pillEnt:Get("talk")
		
		if talkie and talkie.jawbone then
			local boneID = pillEnt:LookupBone(talkie.jawbone)
			local scale = talkie.scale or 1
			if talkie.reversed then mp = -1 end
			
            if boneID then
				jawAngle.r = -weight * (25 * scale) * mp
                local angle = ply:IsSpeaking() and jawAngle or angle_zero
                pillEnt:ManipulateBoneAngles(boneID, angle)
				return
            end
		end

        for _, boneName in ipairs(jawBones) do
            local boneID = pillEnt:LookupBone(boneName)
			if boneName == "Jaw_Bn" or boneName == "bip_lowerEndoJaw" then mp = -1 end
            if boneID then
				jawAngle.r = -weight * 25 * mp
                local angle = ply:IsSpeaking() and jawAngle or angle_zero
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

hook.Add("OnPlayerChat", "fh_chat_message", function(ply, text, p_team, dead)
    if not IsValid(ply) then return end
	
	local clr = team.GetColor( ply:Team() ) or Color(90, 90, 90)
	
	local notDead = (p_team and ply:Team() ~= TEAM_SPECTATOR)
	local dead = (p_team and ply:Team() == TEAM_SPECTATOR or !ply:Alive())
	
	local team_txt = notDead and "(TEAM) " or dead and "*DEAD* " or ""
	local team_clr = notDead and Color(0, 190, 0) or dead and Color(255,0,0)

    chat.AddText(
        team_clr, team_txt,
        clr, ply:Nick(),
        Color(255, 255, 255), ": ",
        Color(255, 255, 255), text
    )

    return true
end)

local halloweenColorCorrection = {
	["$pp_colour_addr"] = 8 * 0.02,
	["$pp_colour_addg"] = 5 * 0.02,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = -0.15,
	["$pp_colour_contrast"] = 1.01,
	["$pp_colour_colour"] = 1.0,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0
}

local fh_halloween_cc = CreateClientConVar("fh_halloween_cc", "1", true, true, "Toggle Halloween Themed Color Correction", 0, 1)

hook.Add("RenderScreenspaceEffects", "Halloween_Effect", function()
	if fh_halloween_cc:GetBool() and IsHalloween() then
		DrawColorModify(halloweenColorCorrection)
	end
end)

hook.Add("EntityNetworkedVarChanged","fh_gamestatus_update", function(entity, name, old, new)
    if entity == game.GetWorld() then
        if name == 'gameOn' then
            if new == true then
                hook.Run("fh_prestartgame")
            end
        end
        if name == 'roundActive' then
            if new == true then
                hook.Run("fh_poststartgame")
            end
        end
        if name == 'roundEnding' then
            if new == true then
                hook.Run("fh_postendgame")
            end
        end
    end
	
	if name == "HeldEnt" then
		if entity:GetClass() == "prop_physics" then
			hook.Run("HeldObjectStateChanged", entity, new)
		end
	end
    if entity:IsPlayer() then
        if name == 'KillerObsessed' then
            if new == true then
                hook.Run("FH_KillerObsessed", entity)
            elseif new == false then
                hook.Run("FH_KillerLostObsession", entity)
            end
        end
    end
end)

local myself

hook.Add("PreDrawViewModel", "fix_flying_viewmodels", function(vm, ply, weapon)
	myself = myself or LocalPlayer()
	local mode = myself:GetObserverMode()
	
	-- если я наблюдатель
	if mode ~= OBS_MODE_NONE then
		if ply ~= myself then
			return true
		end
	-- если я живот
	elseif mode == OBS_MODE_NONE then
		if ply ~= myself then
			return true
		end
	end
end)