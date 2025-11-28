
include( "player_class/player_sandbox.lua" )
include( "utils/editor_player.lua" )

GM.Name = "Fazbear's Hunt"
GM.Author = "sergeant"
GM.Email = "N/A"
GM.Website = "N/A"

local fh_version = "3.2.0"

function fh.GetVersion()
    return fh_version
end

--DeriveGamemode("sandbox")

TEAM_SURVIVOR = 2700
TEAM_PILLS = 2701
TEAM_ADMIN = 2702
TEAM_EDITOR = 2703

team.SetUp(TEAM_SURVIVOR, "Survivors", Color(84, 163, 255))
team.SetColor( TEAM_SPECTATOR, Color(117, 117, 130) )

function IsHalloween()
    return os.date("%B") == "October"
end

conVars = {
	halo_radius = CreateConVar( "halo_radius", 2000, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Halo radius." ),
	halo_time = CreateConVar( "halo_time", 10, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Time for halo to dissolve." ),
	halo_cooldown = CreateConVar( "halo_cooldown", 120, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Cooldown for halo." ),
	
	fh_automatic_highlight = CreateConVar( "fh_automatic_highlight", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Automatic highlight map settings." ),
	
	fh_round_duration = CreateConVar( "fh_round_duration", 10, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Round duration in minutes." ),
	
	--[[
		ADMIN PANEL: EVENT
	]]
	fh_gifts_spawning = CreateConVar( "fh_gifts_spawning", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Toggle gifts spawning." ),
	fh_goldenfreddy_spawning = CreateConVar( "fh_goldenfreddy_spawning", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Toggle Golden Freddy spawning." ),
	
	--[[
		ADMIN PANEL: EXPERIMENTS
	]]
	fh_animatronic_immortal = CreateConVar( "fh_animatronic_immortal", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Toggle immortality for animatronic team." ),
	
	fh_less_steps = CreateConVar( "fh_less_steps", 0, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Makes footsteps silent when they're not rendered." ),
	fh_less_steps_volume = CreateConVar( "fh_less_steps_volume", 0.3, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Footstep volume when quiet animatronics is on." ),
	
	fh_max_cupcakes = CreateConVar( "fh_max_cupcakes", 3, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Maximum amount of cupcakes Chica can spawn." ),
	fh_silent_highlight = CreateConVar( "fh_silent_highlight", 0, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Makes highlights fully mute, and removes its overlay." ),
	fh_respawn_dead_animatronics = CreateConVar( "fh_respawn_dead_animatronics", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Respawn animatronic if it died?" )
}

local colors = {
    Gray = Color(200, 200, 200),
    Freddy = !IsHalloween() and Color(114, 51, 5) or Color(67, 83, 50),
    Bonnie = !IsHalloween() and Color(50, 40, 255) or Color(79, 54, 104),
    Endo = Color(255, 255, 255),
    Chica = !IsHalloween() and Color(255, 201, 53) or Color(50, 62, 36),
    Foxy = !IsHalloween() and Color(255, 0, 0) or Color(57, 30, 11),
    Shadow = !IsHalloween() and Color(105, 0, 255) or Color(70, 100, 62), 
    Clown = Color(216, 93, 244),
    Springtrap = !IsHalloween() and Color(105, 150, 70) or Color(150, 129, 61),
    Plushtrap = Color(130, 119, 48),
	
    Golden = Color(255, 210, 0),
}

local killerData = killerData or {
    ["pill_wfreddy2"] = {name = "freddy", fullname = "fazhunt.animatronics.freddy", color = colors.Freddy},
    ["pill_wbonnie2"] = {name = "bonnie", fullname = "fazhunt.animatronics.bonnie", color = colors.Bonnie},
    ["pill_wchica2"] = {name = "chica", fullname = "fazhunt.animatronics.chica", color = colors.Chica},
    ["pill_wfoxy2"] = {name = "foxy", fullname = "fazhunt.animatronics.foxy", color = colors.Foxy},
    ["pill_endo02"] = {name = "endo", fullname = "fazhunt.animatronics.endo", color = colors.Endo},
    ["pill_sfreddy2"] = {name = "sfreddy", fullname = "fazhunt.animatronics.sfreddy", color = colors.Shadow},
    ["pill_wgfreddy2"] = {name = "gfreddy", fullname = "fazhunt.animatronics.gfreddy", color = colors.Golden},
    ["pill_clown"] = {name = "clown", fullname = "fazhunt.animatronics.clown", color = colors.Clown},
	
    ["pill_springtrap"] = {name = "springtrap", fullname = "fazhunt.animatronics.springtrap", color = colors.Springtrap},
    ["pill_plushtrap"] = {name = "plushtrap", fullname = "fazhunt.animatronics.plushtrap", color = colors.Plushtrap},
	
    ["pill_mangle"] = {name = "mangle", fullname = "fazhunt.animatronics.mangle", color = colors.Endo},
	
    ["pill_toychica"] = {name = "tchica", fullname = "Toy Chica", color = colors.Chica},
--	["bear5_main"] = {name = "bear5", fullname = "Bear 5", color = Color(73,104,255)},
}

killerAbilities = {
    freddy = {
        { name = 'kill', key = 'LMB', duration = 0, hidden = true },
        { name = 'stalk', key = 'RMB', duration = 0 },
        { name = 'highlight', key = 'R', duration = 0 }
    },
    bonnie = {
        { name = 'kill', key = 'LMB', duration = 0, hidden = true },
        { name = 'yoursmine', key = 'RMB', duration = 0 },
        { name = 'highlight', key = 'R', duration = 0 }
    },
    chica = {
        { name = 'kill', key = 'LMB', duration = 0, hidden = true },
        { name = 'mine', key = 'RMB', duration = 0 },
        { name = 'highlight', key = 'R', duration = 0 }
    },
    foxy = {
        { name = 'kill', key = 'LMB', duration = 0, hidden = true },
		{ name = 'charge', key = 'RMB', duration = 0, tokens = 5,
		condition = function()
            return foxyChargeCondition()
        end},
        { name = 'highlight', key = 'R', duration = 0 }
    },
    sfreddy = {
        { name = 'kill', key = 'LMB', duration = 0, hidden = true },
        { name = 'submerge', key = 'RMB', duration = 0, condition = function()
            return isNotStuck()
        end },
        { name = 'highlight', key = 'R', duration = 0 }
    },
    endo = {
        { name = 'kill', key = 'LMB', duration = 0, hidden = true },
        { name = 'grab', key = 'RMB', duration = 0 },
        { name = 'highlight', key = 'R', duration = 0 }
    },
    clown = {
        { name = 'attack', key = 'LMB', duration = 0 },
        { name = 'highlight', key = 'R', duration = 0 }
    },
    plushtrap = {
        { name = 'attack', key = 'LMB', duration = 0 },
        { name = 'lifetime', duration = 0, hidden = true }
    },
    springtrap = {
        { name = 'attack', key = 'LMB', duration = 0 },
        { name = 'summon', key = 'RMB', duration = 0 },
        { name = 'highlight', key = 'R', duration = 0 },
    },
    gfreddy = {
        { name = 'submerge', key = 'RMB', duration = 0 },
        { name = 'choose_target', key = 'R', duration = 0 }
    },
    mangle = {
        { name = 'kill', key = 'LMB', duration = 0, hidden = true },
        { name = 'lunge', key = 'RMB', duration = 0, condition = function()
            return CanMangleLunge()
        end },
        { name = 'highlight', key = 'R', duration = 0}
    },
    tchica = {
        { name = 'kill', key = 'LMB', duration = 0, hidden = true },
        { name = 'hold', key = 'RMB', duration = 0 },
        { name = 'highlight', key = 'R', duration = 0}
    },
}

killers = killers or {}

local killerAvatars = {}

local function precacheAvatar(pill, techname)
	local imagePath = "vgui/bars/" .. techname .. ".png"
	local animImage = nil
	
    if file.Exists("materials/" .. imagePath, "GAME") then
		animImage = Material(imagePath, "mips")
		if !animImage:IsError() then
			killerAvatars[pill] = animImage
		end
	end
end

for name,v in pairs(killerData) do
	precacheAvatar(name,v.name)
end

function killers.GetAvatar(killer)
	if killerAvatars[killer] then
		return killerAvatars[killer]
	end
	return nil
end

local killerPortraits = {}

local function precachePortrait(pill, techname)
	local imagePath = "vgui/animatronics_hud/heads/" .. techname .. ".png"
	local animImage = nil
	
    if file.Exists("materials/" .. imagePath, "GAME") then
		animImage = Material(imagePath, "mips")
		if !animImage:IsError() then
			killerPortraits[techname] = animImage
		end
	end
end

for name,v in pairs(killerData) do
	precachePortrait(name,v.name)
end

function killers.GetPortrait(killer)
	if killerPortraits[killer] then
		return killerPortraits[killer]
	end
	return nil
end

function killers.Register(pill, a_name, a_fullname, a_color)
    assert(pill, "[killers.Register] You need a pill to begin with!")
    assert(a_name, "[killers.Register] You need a name to begin with!")

    if killerData[pill] then
        print("Can't overwrite already existing animatronic!")
        return
    end

    a_fullname = a_fullname or a_name
    a_color = a_color or colors.Gray

    killerData[pill] = {name = a_name, fullname = a_fullname, color = a_color}
	
	precacheAvatar(pill, a_name)
	precachePortrait(pill,a_name)
end

function killers.SetAbilities(name, abilities)
    if not name or not abilities then return end
    
    if killerAbilities[name] then
        for _, ability in ipairs(abilities) do
            table.insert(killerAbilities[name], ability)
        end
    else
        killerAbilities[name] = abilities
    end
end

local function IsNavmesh()
	if CLIENT then
		return true
	end
	return navmesh.IsLoaded() and navmesh.GetNavAreaCount() >= 5
end

function killers.getAll()
	local tablo = table.Copy(killerData)
	return tablo
end

function killers.getAllSolos()
	local tablo = {}
	for k, v in pairs( killerData ) do
		if !killerData[k].secondary then
			tablo[k] = v
		end
	end
	return tablo
end

function killers.getAllPreferables(secondaries)
	secondaries = secondaries or false
	local tablo = {}
	for k, v in pairs( killerData ) do
		if !secondaries and killerData[k].secondary then continue end
		if killerData[k].navmesh and !IsNavmesh() then continue end -- золотой фредде)
		if killerData[k].preferable then
			tablo[k] = v
		end
	end
	return tablo
end

function killers.getAllNonPreferables()
	local tablo = {}
	for k, v in pairs( killerData ) do
		if !killerData[k].preferable then
			tablo[k] = v
		end
	end
	return tablo
end

local dontPrefer = {"pill_springtrap", "pill_plushtrap", "pill_wgfreddy2"}
--[[
-- по умолчанию нельзя выбирать этих аниматроников, пишем их в файлик, чтобы файликом можно было управлять
if !file.Exists("fh_dontprefer.txt", "DATA") then
	file.Write("fh_dontprefer.txt", table.concat(dontPrefer, "\n"))
end
]]--

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

function pill_SetInstakill(anim, bool)
	bool = bool or true
	if istable(anim) then
		for k, v in pairs( anim ) do
			if killerData[v] then
				killerData[v].instakill = bool
			end
		end
	else
		if killerData[anim] then
			killerData[anim].instakill = bool
		end
	end
end

function pill_SetDamageAttack(anim, bool)
	bool = bool or true
	if istable(anim) then
		for k, v in pairs( anim ) do
			if killerData[v] then
				killerData[v].damageAttack = bool
			end
		end
	else
		if killerData[anim] then
			killerData[anim].damageAttack = bool
		end
	end
end

function pill_RequiresNavmesh(anim, bool)
	bool = bool or true
	if istable(anim) then
		for k, v in pairs( anim ) do
			if killerData[v] then
				killerData[v].navmesh = bool
			end
		end
	else
		if killerData[anim] then
			killerData[anim].navmesh = bool
		end
	end
end

pill_RequiresNavmesh("pill_wgfreddy2")

pill_SetDamageAttack( {"pill_springtrap", "pill_plushtrap", "pill_clown"} )

pill_makeSecondary( {"pill_endo02", "pill_sfreddy2", "pill_wgfreddy2"} )

function save_dontPrefer(net)
	net = net or false

	local tablo = {}
	for k, v in pairs( killerData ) do
		tablo[k] = v.preferable or false
	end
	
	file.Write("fh_preferables.json", util.TableToJSON(tablo))
end

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

pill_makePreferable( dontPrefer )

hook.Add("Initialize", "fh_dontprefer", function()
	hook.Remove("PlayerTick", "TickWidgets") -- вроде слегка оптимизирует игру. спиздил с zombie-survival
	if CLIENT then return end
	
	-- СОВМЕСТИМОСТЬ СО СТАРЫМИ ВЕРСИЯМИ ФХ
	if file.Exists("fh_dontprefer.txt", "DATA") and !file.Exists("fh_preferables.json", "DATA") then
		local data = file.Read("fh_dontprefer.txt", "DATA") or ""
		
		if data != "" then 
			local lines = string.Split(data, "\n")
			local toJson = {}
			
			for k,v in pairs(killerData) do
				toJson[k] = v.preferable or false
			end
			
			for k,v in pairs(lines) do
				toJson[v] = false
			end
			
			pill_makePreferable( lines )
			
			file.Write("fh_preferables.json", util.TableToJSON(toJson) )
		end
	end
	
	if file.Exists("fh_preferables.json", "DATA") then
		local data = file.Read("fh_preferables.json", "DATA") or ""
		
		local datajson = util.JSONToTable( data ) or {}
		
		for k,v in pairs(datajson) do
			pill_makePreferable( k, v )
		end
	else
		local tosave = {}
		for k,v in pairs(killerData) do
			tosave[k] = v.preferable or false
			pill_makePreferable( k, v.preferable or false )
		end
			
		file.Write("fh_preferables.json", util.TableToJSON(tosave) )
	end
end)

function killers.getAllSecondaries()
	local tablo = {}
	for k, v in pairs( killerData ) do
		if killerData[k].secondary then
			tablo[k] = v
		end
	end
	return tablo
end

function killers.getAllDamageOnly()
	local tablo = {}
	for k, v in pairs( killerData ) do
		if killerData[k].damageAttack and !killerData[k].instakill then
			tablo[k] = v
		end
	end
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
	[TEAM_SURVIVOR] = Color(84, 163, 255)
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
	
	--plushtronc
	if class2 == "plushtrap" and isPlayer1 then
		return false
	elseif class1 == "plushtrap" and isPlayer2 then
		return false
	end
	
	if CLIENT then
		if isPlayer1 and ent1:GetNW2Entity("HeldEnt") == ent2 then
			return false
		elseif isPlayer2 and ent2:GetNW2Entity("HeldEnt") == ent1 then
			return false
		end
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
	
    if (cg1 == COLLISION_GROUP_PLAYER_MOVEMENT and isPlayer1 and isPlayer2)
        or (cg2 == COLLISION_GROUP_PLAYER_MOVEMENT and isPlayer2 and isPlayer1) then
        return false
    end

    -- Игроки с разными группами, один с PLAYER_MOVEMENT
    if cg1 == COLLISION_GROUP_PLAYER_MOVEMENT and isPlayer2 and cg2 ~= cg1 then
        return false
    elseif cg2 == COLLISION_GROUP_PLAYER_MOVEMENT and isPlayer1 and cg1 ~= cg2 then
        return false
    end
end)

-- это как по мне очень ненадёжный способ пиздить пилл паки в режим,
-- но делая эту хуйню мне как то гордо на душе

hook.Add("PreGamemodeLoaded", "FH_pk_pill_support", function()
	if pk_pills then
		if pk_pills.getPillTable and pk_pills.packStart then
			
			local toRegister = {}
		
			local name, packs = debug.getupvalue(pk_pills.packStart, 2)
			for _,pack in ipairs(packs) do
				if pack.name == "Fun" or pack.name == "Jake" or pack.name == "Half-Life 2" then
					continue
				end
				if pack.items then
					for _, item in pairs(pack.items) do
						if killerData[item.name] then continue end
						
						if !item.name then continue end
						toRegister[item.name] = {}
					end
				end
			end
		
			local name, forms = debug.getupvalue(pk_pills.getPillTable, 1)
			for name,data in pairs(forms) do
				
				if toRegister[name] then
					toRegister[name] = data
				end
			end
			
			for name, data in pairs(toRegister) do
				local betterName = name:lower()
				if file.Exists("materials/pills/" .. betterName .. ".png", "GAME") then
					local animImage = Material("pills/" .. betterName .. ".png", "mips")
					if !animImage:IsError() then
						killerAvatars[betterName] = animImage
					end
				end
			
				-- repairing various pill packs
				if data.HandleAnimEvent_gen then
					local olddata = data.HandleAnimEvent_gen
					
					data.animEvent = olddata
					data.HandleAnimEvent_gen = nil
				end
				if data.init then
					local olddata = data.init
					
					data.startFunction = olddata
					data.init = nil
				end
			
				pills.register(betterName, data)
			end
			
		end
	end
end)

local meta = FindMetaTable("Player")

if meta then

	function meta:IsSurvivor()
		return self:Alive() and self:Team() == TEAM_SURVIVOR and !IsValid(self:GetPill())
	end
	
	function meta:IsAnimatronic()
		return self:Team() == 2701 or IsValid(pills.getMappedEnt(self))
	end
end

local meta = FindMetaTable("Entity")

if meta then
	
	function meta:IsInvisible()
		return self:GetMaterial() == "models/null" or self:GetNoDraw()
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


if SERVER then

	concommand.Add("spawn_mori", function(ply)
		if not IsValid(ply) then return end
		if !ply:IsSuperAdmin() then return end
		
		local helper = ents.Create("mori_helper")
		helper:SetPos( ply:GetPos() )
		helper:Spawn()
		helper:SetOwner(ply)
		
		local b = ents.Create("mori_outfit")
		b:SetParent(helper)
		b:SetModel( ply:GetModel() )
		b:Spawn()
	end)
end