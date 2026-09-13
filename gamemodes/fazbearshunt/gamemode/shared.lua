
include( "player_class/player_sandbox.lua" )
include( "utils/editor_player.lua" )

GM.Name = "Fazbear's Hunt"
GM.Author = "sergeant"
GM.Email = "N/A"
GM.Website = "N/A"

local fh_version = "4.1.2"

function fh.GetVersion()
    return fh_version
end

DEVELOPER_MODE = true

--DeriveGamemode("sandbox")

TEAM_SURVIVOR = 2700
TEAM_PILLS = 2701
TEAM_SECRET_PILLS = 27
TEAM_ADMIN = 2702
TEAM_EDITOR = 2703

team.SetUp(TEAM_SURVIVOR, "Survivors", Color(84, 163, 255))
team.SetColor( TEAM_SPECTATOR, Color(117, 117, 130) )

local osdateB = os.date("%B")
local osdatem = os.date("%m")

function IsHalloween() return osdateB == "October" end
function IsChristmas() local d = tonumber(osdatem) return (d == 1 or d == 12) end

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
	fh_animatronic_ff = CreateConVar( "fh_animatronic_ff", 0, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Toggle friendly fire for animatronic team." ),
	
	fh_less_steps = CreateConVar( "fh_less_steps", 0, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Makes footsteps silent when they're not rendered." ),
	fh_less_steps_volume = CreateConVar( "fh_less_steps_volume", 0.3, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Footstep volume when quiet animatronics is on." ),
	
	fh_max_cupcakes = CreateConVar( "fh_max_cupcakes", 3, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Maximum amount of cupcakes Chica can spawn." ),
	fh_silent_highlight = CreateConVar( "fh_silent_highlight", 0, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Makes highlights fully mute, and removes its overlay." ),
	fh_respawn_dead_animatronics = CreateConVar( "fh_respawn_dead_animatronics", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Respawn animatronic if it died?" ),
	
	fh_bear5_killermask_last = CreateConVar( "fh_bear5_killermask_last", 0, {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Give Killer's Mask to last survivor during Bear5 round?." ),
	fh_fast_roundrestart = CreateConVar( "fh_fast_roundrestart", "0", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Make round restarts be faster?" ),
	
	fh_banana_ragdollize = CreateConVar( "fh_banana_ragdollize", "0", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Should animatronics go ragdoll when slipping on bananas while sprinting?" ),

	opt_out_anim = CreateConVar("fh_opt_out_anim", 0, { FCVAR_ARCHIVE,FCVAR_CLIENTDLL,FCVAR_USERINFO }, "Do you wannna opt out of Animatronics?", 0, 1),
	
	fair_hl = CreateConVar( "fh_fair_highlight", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Force player highlight if he was not highlighted 3 times in a row?" )
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
	ToyChica = Color(255, 201, 53)
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
	
	["pill_toychica"] = {name = "tchica", fullname = "fazhunt.animatronics.toychica", color = colors.ToyChica},
}

killerAbilities = {
	freddy = {
		[1] = { name = 'kill', key = 'LMB', hidden = true },
		[2] = { name = 'blindrage', key = 'RMB' },
		[3] = { name = 'highlight', key = 'R' }
	},
	bonnie = {
		[1] = { name = 'kill', key = 'LMB', hidden = true },
		[2] = { name = 'yoursmine', key = 'RMB' },
		[3] = { name = 'highlight', key = 'R' }
	},
	chica = {
		[1] = { name = 'kill', key = 'LMB', hidden = true },
		[2] = { name = 'mine', key = 'RMB' },
		[3] = { name = 'highlight', key = 'R' }
	},
	foxy = {
		[1] = { name = 'kill', key = 'LMB', hidden = true },
		[2] = { name = 'charge', key = 'RMB', tokens = 5,
		condition = function()
			return foxyChargeCondition()
		end},
		[3] = { name = 'highlight', key = 'R' }
	},
	sfreddy = {
		[1] = { name = 'kill', key = 'LMB', hidden = true },
		[2] = { name = 'submerge', key = 'RMB', condition = function()
			return isNotStuck()
		end },
		[3] = { name = 'highlight', key = 'R' }
	},
	endo = {
		[1] = { name = 'kill', key = 'LMB', hidden = true },
		[2] = { name = 'pretense', key = 'RMB' },
		[3] = { name = 'highlight', key = 'R' }
	},
	clown = {
		[1] = { name = 'attack', key = 'LMB' },
		[2] = { name = 'highlight', key = 'R' }
	},
	plushtrap = {
		[1] = { name = 'attack', key = 'LMB' },
		[2] = { name = 'lifetime', hidden = true },
		[2] = { name = 'hitch', key = "RMB" }
	},
	springtrap = {
		[1] = { name = 'attack', key = 'LMB' },
		[2] = { name = 'summon', key = 'RMB' },
		[3] = { name = 'highlight', key = 'R' },
	},
	gfreddy = {
		[1] = { name = 'submerge', key = 'RMB' },
		[2] = { name = 'choose_target', key = 'R' }
	},
	mangle = {
		[1] = { name = 'kill', key = 'LMB', hidden = true },
		[2] = { name = 'lunge', key = 'RMB', condition = function()
			return CanMangleLunge()
		end },
		[3] = { name = 'highlight', key = 'R'}
	},
	tchica = {
		[1] = { name = 'kill', key = 'LMB', hidden = true },
		[2] = { name = 'hold', key = 'RMB' },
		[3] = { name = 'highlight', key = 'R' }
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

function killers.Register(pill, a_name, a_fullname, a_color, category)
    assert(pill, "[killers.Register] You need a pill to begin with!")
    assert(a_name, "[killers.Register] You need a name to begin with!")

    if killerData[pill] then
        print("Can't overwrite already existing animatronic!")
        return
    end

    a_fullname = a_fullname or a_name
    a_color = a_color or colors.Gray

    killerData[pill] = {name = a_name, fullname = a_fullname, color = a_color}
	
	if category then
		killerData[pill].category = category
	end
	
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

function killers.GetName(pill)
    if killerData[pill] then
		return killerData[pill].name
	end
	return ""
end

function killers.GetFullName(pill)
    if killerData[pill] then
		return killerData[pill].fullname
	end
	return ""
end

local function IsNavmesh()
	if CLIENT then
		return true
	end
	return navmesh.IsLoaded() and navmesh.GetNavAreaCount() >= 5
end

function killers.getAll()
	return table.Copy(killerData)
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

pill_makeSecondary( {"pill_sfreddy2", "pill_wgfreddy2", "pill_toychica"} )

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

function killers.getColor(killer)
	local color = Color(255,255,255)
	local data = killerData[killer]
	if data and data.color then
		return data.color
	end
	return color
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

utf8.sub = function(str, startChar, endChar)
    local startByte = utf8.offset(str, startChar)
    local endByte = utf8.offset(str, endChar + 1) and (utf8.offset(str, endChar + 1) - 1) or #str
    if startByte and endByte then
        return string.sub(str, startByte, endByte)
    else
        return ""
    end
end

hook.Add("ShouldCollide", "fh_collisions", function(ent1, ent2)
    local snca = ent1.ShouldNotCollide
    if snca and snca( ent1, ent2 ) then return ( false ) end

    local sncb = ent2.ShouldNotCollide
    if sncb and sncb( ent2, ent1 ) then return ( false ) end
	
    local isPlayer1, isPlayer2 = ent1:IsPlayer(), ent2:IsPlayer()
	
	if CLIENT then
		if isPlayer1 and ent1:GetNW2Entity("HeldEnt") == ent2 then
			return false
		elseif isPlayer2 and ent2:GetNW2Entity("HeldEnt") == ent1 then
			return false
		end
	end
	
    local cg1, cg2 = ent1:GetCollisionGroup(), ent2:GetCollisionGroup()
    local class1, class2 = ent1:GetClass(), ent2:GetClass()

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

    -- игрок плюштрап может проходить через игроков
    if cg2 == COLLISION_GROUP_PASSABLE_DOOR and isPlayer1 and cg1 ~= cg2 then
        return false
    end
end)

local meta = FindMetaTable("Player")

if meta then
	if SERVER then
		function meta:IsSurvivor()
			return self:Alive() and self:Team() == TEAM_SURVIVOR and not pills.hasMappedEnt(self)
		end
		
		function meta:IsAnimatronic()
			return self:Team() == 2701 or pills.hasMappedEnt(self) ~= nil
		end
	else
		function meta:IsSurvivor()
			return self:Alive() and self:Team() == TEAM_SURVIVOR and not IsValid(pills.getMappedEnt(self))
		end
		
		function meta:IsAnimatronic()
			return self:Team() == 2701 or IsValid(pills.getMappedEnt(self))
		end
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