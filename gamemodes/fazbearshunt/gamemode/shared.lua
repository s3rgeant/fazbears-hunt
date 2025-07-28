
include( "player_class/player_sandbox.lua" )
include( "editor_player.lua" )

GM.Name = "Fazbear's Hunt"
GM.Author = "sergeant"
GM.Email = "N/A"
GM.Website = "N/A"

--[[
if GetConVar("fh_mountsandbox"):GetBool() then
	DeriveGamemode("sandbox")
end
]]--

conVars = {
	halo_radius = CreateConVar( "halo_radius", 2000, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Halo radius." ),
	halo_time = CreateConVar( "halo_time", 10, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Time for halo to dissolve." ),
	halo_cooldown = CreateConVar( "halo_cooldown", 120, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Cooldown for halo." ),
	
	fh_automatic_highlight = CreateConVar( "fh_automatic_highlight", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Cooldown for halo." ),
	
	
	--[[
		ADMIN PANEL: EXPERIMENTS
	]]
	fh_gifts_spawning = CreateConVar( "fh_gifts_spawning", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Toggle gifts spawning" ),
	fh_animatronic_immortal = CreateConVar( "fh_animatronic_immortal", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Toggle immortality for animatronic team" ),
	fh_less_steps = CreateConVar( "fh_less_steps", 0, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Toggle PVS adding for animatronics (makes footsteps silent when they're not rendered)" ),
	fh_max_cupcakes = CreateConVar( "fh_max_cupcakes", 3, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Maximum amount of cupcakes Chica can spawn." ),
	fh_silent_highlight = CreateConVar( "fh_silent_highlight", 0, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Makes highlights fully mute, and removes its overlay." ),
	fh_respawn_dead_animatronics = CreateConVar( "fh_respawn_dead_animatronics", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Respawn animatronic if it died?" ),
	
	fh_discord_url_webhook = CreateConVar( "fh_discord_url_webhook", "none", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Discord Integration webhook." )
	--fh_discord_url_avatar = CreateConVar( "fh_discord_url_avatar", "none", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Discord Integration avatar." )
}

local colors = {
    Gray = Color(200, 200, 200),
    Freddy = Color(114, 51, 5),
    Bonnie = Color(50, 40, 255),
    Endo = Color(255, 255, 255),
    Chica = Color(255, 201, 53),
    Foxy = Color(255, 0, 0),
    Shadow = Color(105, 0, 255), 
    Clown = Color(216, 93, 244),
    Springtrap = Color(105, 150, 70),
    Golden = Color(255, 210, 0)
}

killerData = killerData or {
    ["pill_wfreddy2"] = {name = "freddy", fullname = "fazhunt.animatronics.freddy", color = colors.Freddy},
    ["pill_wbonnie2"] = {name = "bonnie", fullname = "fazhunt.animatronics.bonnie", color = colors.Bonnie},
    ["pill_wchica2"] = {name = "chica", fullname = "fazhunt.animatronics.chica", color = colors.Chica},
    ["pill_wfoxy2"] = {name = "foxy", fullname = "fazhunt.animatronics.foxy", color = colors.Foxy},
    ["pill_endo02"] = {name = "endo", fullname = "fazhunt.animatronics.endo", color = colors.Endo},
    ["pill_sfreddy2"] = {name = "sfreddy", fullname = "fazhunt.animatronics.sfreddy", color = colors.Shadow},
    ["pill_wgfreddy2"] = {name = "gfreddy", fullname = "fazhunt.animatronics.gfreddy", color = colors.Golden},
    ["pill_clown"] = {name = "clown", fullname = "fazhunt.animatronics.clown", color = colors.Clown},
    ["pill_springtrap"] = {name = "springtrap", fullname = "fazhunt.animatronics.springtrap", color = colors.Springtrap},
    ["pill_plushtrap"] = {name = "plushtrap", fullname = "fazhunt.animatronics.plushtrap", color = colors.Springtrap}
}

killerAbilities = {
    freddy = {
        { name = 'kill', key = 'LMB', duration = 0, keyboard = false, hidden = true },
        { name = 'stalk', key = 'RMB', duration = 0 },
        { name = 'highlight', key = 'R', duration = 0, keyboard = true, hidden = false }
    },
    bonnie = {
        { name = 'kill', key = 'LMB', duration = 0, keyboard = false, hidden = true },
        { name = 'yoursmine', key = 'RMB', duration = 0 },
        { name = 'highlight', key = 'R', duration = 0, keyboard = true, hidden = false }
    },
    chica = {
        { name = 'kill', key = 'LMB', duration = 0, keyboard = false, hidden = true },
        { name = 'mine', key = 'RMB', duration = 0 },
        { name = 'highlight', key = 'R', duration = 0, keyboard = true, hidden = false }
    },
    foxy = {
        { name = 'kill', key = 'LMB', duration = 0, keyboard = false, hidden = true },
		{ name = 'charge', key = 'RMB', duration = 0, keyboard = false, tokens = 5 },
        { name = 'highlight', key = 'R', duration = 0, keyboard = true, hidden = false }
    },
    sfreddy = {
        { name = 'kill', key = 'LMB', duration = 0, keyboard = false, hidden = true },
        { name = 'submerge', key = 'RMB', duration = 0, condition = function()
            return isNotStuck()
        end },
        { name = 'highlight', key = 'R', duration = 0, keyboard = true, hidden = false }
    },
    endo = {
        { name = 'kill', key = 'LMB', duration = 0, keyboard = false, hidden = true },
        { name = 'grab', key = 'RMB', duration = 0 },
        { name = 'highlight', key = 'R', duration = 0, keyboard = true, hidden = false }
    },
    clown = {
        { name = 'attack', key = 'LMB', duration = 0, keyboard = false, hidden = false },
        { name = 'highlight', key = 'R', duration = 0, keyboard = true, hidden = false }
    },
    plushtrap = {
        { name = 'attack', key = 'LMB', duration = 0, keyboard = false, hidden = false },
        { name = 'lifetime', duration = 0, hidden = true }
    },
    springtrap = {
        { name = 'attack', key = 'LMB', duration = 0, keyboard = false, hidden = false },
        { name = 'summon', key = 'RMB', duration = 0 },
        { name = 'highlight', key = 'R', duration = 0, keyboard = true, hidden = false },
        { name = 'plushtrap', duration = 0, hidden = true }
    },
    gfreddy = {
        { name = 'submerge', key = 'RMB', duration = 0 },
        { name = 'choose_target', key = 'R', duration = 0, keyboard = true, hidden = false }
    }
}

function getAllSolos()
	local tablo = {}
	for k, v in pairs( killerData ) do
		if !killerData[k].secondary then
			tablo[k] = v
		end
	end
	return tablo
end

function getAllPreferables(secondaries)
	secondaries = secondaries or false
	local tablo = {}
	for k, v in pairs( killerData ) do
		if !secondaries and killerData[k].secondary then continue end
		if killerData[k].preferable then
			tablo[k] = v
		end
	end
	return tablo
end

function getAllNonPreferables()
	local tablo = {}
	for k, v in pairs( killerData ) do
		if !killerData[k].preferable then
			tablo[k] = v
		end
	end
	return tablo
end

local dontPrefer = {"pill_springtrap", "pill_plushtrap", "pill_wgfreddy2"}

-- по умолчанию нельзя выбирать этих аниматроников, пишем их в файлик, чтобы файликом можно было управлять
if !file.Exists("fh_dontprefer.txt", "DATA") then
	file.Write("fh_dontprefer.txt", table.concat(dontPrefer, "\n"))
end

function pill_makeSecondary(anim, bool)
	bool = bool or true
	if istable(anim) then
		for k, v in pairs( anim ) do
			if killerData[v] then
				killerData[v].secondary = bool
			end
		end
	else
		if killerData[anim] then
			killerData[anim].secondary = bool
		end
	end
end

function save_dontPrefer(net)
	net = net or false

	local tablo = {}
	for k, v in pairs ( getAllNonPreferables() ) do
		table.insert(tablo, k)
	end
	file.Write("fh_dontprefer.txt", table.concat(tablo, "\n"))
end

pill_makeSecondary( {"pill_endo02", "pill_sfreddy2", "pill_wgfreddy2"} )

function pill_makePreferable(anim, bool)
	bool = bool or false
	
	if istable(anim) then
		for k, v in pairs( anim ) do
			if killerData[v] then
				killerData[v].preferable = bool
			end
		end
	else
		if killerData[anim] then
			killerData[anim].preferable = bool
		end
	end
end

if SERVER then
	pill_makePreferable(table.GetKeys(killerData), true)
end

hook.Add("Initialize", "fh_dontprefer", function()
	if CLIENT then return end
	
	print(file.Exists("fh_dontprefer.txt", "DATA"), "zzz")
	
	if file.Exists("fh_dontprefer.txt", "DATA") then
		local data = file.Read("fh_dontprefer.txt", "DATA") or ""
		
		if data != "" then 
			local lines = string.Split(data, "\n")
			
			pill_makePreferable( lines )
		end
	end
end)

function getAllSecondaries()
	local tablo = {}
	for k, v in pairs( killerData ) do
		if killerData[k].secondary then
			tablo[k] = v
		end
	end
	return tablo
end

function getAllKillers()
	local tablo = table.Copy(killerData)
	return tablo
end

function formatTime(secs)
	if !secs then return nil end
    local minutes = math.floor(secs / 60)
    local secs = math.floor(secs % 60)
    return string.format("%02d:%02d", minutes, secs)
end

teamColors = {
	[2701] = Color(255, 25, 25),
	[27] = Color(255, 25, 25),
	[TEAM_SPECTATOR] = Color(117, 117, 130),
	[TEAM_UNASSIGNED] = Color(84, 163, 255)
}

function GetScaledPlayerValue(countMin, countMax, valueMin, valueMax)
    local count = player.GetCount()

    if count <= countMin then
        return valueMin
    elseif count >= countMax then
        return valueMax
    else
        local ratio = (count - countMin) / (countMax - countMin)
        return valueMin + ratio * (valueMax - valueMin)
    end
end

utf8.sub = function(str, startChar, endChar)
    local startByte = utf8.offset(str, startChar)
    local endByte = utf8.offset(str, endChar + 1) and (utf8.offset(str, endChar + 1) - 1) or #str
    if startByte and endByte then
        return string.sub(str, startByte, endByte)
    else
        return ""
    end
end

--[[
hook.Add("PlayerFootstep", "fh_footsteps", function(ply, pos, foot, sound, volume, filter)
	local foot_sound = foot == 1 and "NPC_CombineS.FootstepLeft" or "NPC_CombineS.FootstepRight"
	ply:EmitSound(foot_sound)
	return true
end)
]]--

hook.Add("SetupMove", "CustomNoClipSpeedControl", function(ply, mv, cmd)
    if ply:GetMoveType() == MOVETYPE_NOCLIP then
        if ply:GetMoveType() == MOVETYPE_OBSERVER then
			mv:SetMaxSpeed( 60 )
            mv:SetMaxClientSpeed( 60 )
        else
			mv:SetMaxSpeed( 20 )
            mv:SetMaxClientSpeed( 20 )
        end
    end
end)


hook.Add("ShouldCollide", "fh_collisions", function(ent1, ent2)
    local cg1, cg2 = ent1:GetCollisionGroup(), ent2:GetCollisionGroup()
    local class1, class2 = ent1:GetClass(), ent2:GetClass()
    local isPlayer1, isPlayer2 = ent1:IsPlayer(), ent2:IsPlayer()

	if class1 == "prop_ragdoll" and class2 == "prop_ragdoll" then
		return false
	end
	
	if class2 == "prop_ragdoll" and isPlayer1 then
		return false
	elseif class1 == "prop_ragdoll" and isPlayer2 then
		return false
	end

    -- Отключаем столкновения с миром
    if cg1 == COLLISION_GROUP_WORLD or cg2 == COLLISION_GROUP_WORLD then
        return false
    end

    -- Shadow + Golden Freddy
    if cg1 == COLLISION_GROUP_DEBRIS and isPlayer1 then
        if class2 ~= "prop_dynamic" and class2 ~= "func_train" and class2 ~= "func_tracktrain" then
            return false
        end
    elseif cg2 == COLLISION_GROUP_DEBRIS and isPlayer2 then
        if class1 ~= "prop_dynamic" and class1 ~= "func_train" and class1 ~= "func_tracktrain" then
            return false
        end
    end

    -- Два игрока и один из них имеет PASSABLE_DOOR
    if (cg1 == COLLISION_GROUP_PASSABLE_DOOR and isPlayer1 and isPlayer2)
        or (cg2 == COLLISION_GROUP_PASSABLE_DOOR and isPlayer2 and isPlayer1) then
        return false
    end

    -- Игроки с разными группами, один с PLAYER_MOVEMENT
    if cg1 == COLLISION_GROUP_PLAYER_MOVEMENT and isPlayer2 and cg2 ~= cg1 then
        return false
    elseif cg2 == COLLISION_GROUP_PLAYER_MOVEMENT and isPlayer1 and cg1 ~= cg2 then
        return false
    end
end)

local meta = FindMetaTable("Player")

if meta then

	function meta:IsSurvivor()
		return self:Alive() and self:Team() == TEAM_UNASSIGNED and !IsValid(pills.getMappedEnt(self))
	end
	
	function meta:IsAnimatronic()
		return self:Team() == 2701 or IsValid(pills.getMappedEnt(self))
	end
end

if CLIENT then
	net.Receive("fh_change_notprefered", function()
		local killer = net.ReadString()
		local bool = net.ReadBool()
	
		pill_makePreferable(killer, bool)
		--save_dontPrefer()

		-- синхронизируем изменение со всеми у кого включена админ панель
		if IsValid(fh_admin_panel) then
			createListAnimatronics()
		end
	end)
	
	net.Receive("fh_share_notprefered", function()
		local killers = net.ReadTable()
	
		for k,v in pairs(killers) do
			pill_makePreferable(k, true)
		end

		if IsValid(fh_admin_panel) then
			createListAnimatronics()
		end
	end)
end

--[[
if SERVER then
    util.AddNetworkString("SpawnClientClone")

    concommand.Add("spawn_client_clone", function(ply)
		if !ply:IsSuperAdmin() then return end
        if not IsValid(ply) then return end
        net.Start("SpawnClientClone")
        net.Send(ply)
    end)
end

if CLIENT then
    local baseModel, clone, hookName, endTime

    net.Receive("SpawnClientClone", function()
		local ply = LocalPlayer()
        if IsValid(baseModel) then
            baseModel:Remove()
        end
        if IsValid(clone) then
            clone:Remove()
        end
        if hookName then
            hook.Remove("Think", hookName)
        end

        baseModel = ClientsideModel("models/humans/group01/male_mori_helper.mdl", RENDERGROUP_OPAQUE)
        baseModel:SetPos(ply:GetPos() + Vector(100, 0, 0))
        baseModel:SetAngles(Angle(0, 0, 0))
        baseModel:ResetSequence("test01")
        baseModel:SetCycle(0)
		baseModel:SetNoDraw(true)
        baseModel:SetPlaybackRate(1)
        baseModel:Spawn()

        local seqDur = baseModel:SequenceDuration()
        local startTime = CurTime()
        endTime = startTime + seqDur

        clone = ClientsideModel(ply:GetModel(), RENDERGROUP_OPAQUE)
        clone:SetPos(baseModel:GetPos())
        clone:SetAngles(baseModel:GetAngles())
        clone:SetParent(baseModel)
        clone:AddEffects(EF_BONEMERGE)
        clone:Spawn()

        -- Имя хука уникальное, чтобы можно было удалить позже
        hookName = "AnimateBaseModel_" .. baseModel:EntIndex()

        hook.Add("Think", hookName, function()
            if not IsValid(baseModel) or not IsValid(clone) then
                hook.Remove("Think", hookName)
                return
            end

            local elapsed = CurTime() - startTime
            local cycle = (elapsed / seqDur) % 1
            baseModel:SetCycle(cycle)

            -- Камера на аттачмент "camera"
            local attId = baseModel:LookupAttachment("camera")
            if attId and attId > 0 then
                local att = baseModel:GetAttachment(attId)
                if att and att.Pos and att.Ang then
                    -- Меняем камеру игрока на позицию аттачмента
                    local view = {
                        origin = att.Pos,
                        angles = att.Ang,
                        fov = 30,
                        drawviewer = true,
                    }
                    hook.Add("CalcView", "CustomView_" .. baseModel:EntIndex(), function()
                        return view
                    end)
                end
            end

            -- Если анимация закончилась — удаляем модели и снимаем камеру
            if CurTime() >= endTime then
                baseModel:Remove()
                clone:Remove()
                hook.Remove("Think", hookName)
                hook.Remove("CalcView", "CustomView_" .. baseModel:EntIndex())
            end
        end)
    end)
end
]]--