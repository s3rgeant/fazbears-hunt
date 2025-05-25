
include( "player_class/player_sandbox.lua" )
include( "editor_player.lua" )

GM.Name = "Fazbear's Hunt"
GM.Author = "sergeant"
GM.Email = "N/A"
GM.Website = "N/A"

conVars = {
	halo_radius = CreateConVar( "halo_radius", 2000, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Halo radius." ),
	halo_time = CreateConVar( "halo_time", 10, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Time for halo to dissolve." ),
	halo_cooldown = CreateConVar( "halo_cooldown", 120, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Cooldown for halo." ),
	
	
	--[[
		ADMIN PANEL: EXPERIMENTS
	]]
	fh_gifts_spawning = CreateConVar( "fh_gifts_spawning", 0, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Toggle gifts spawning" ),
	fh_animatronic_immortal = CreateConVar( "fh_animatronic_immortal", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Toggle immortality for animatronic team" ),
	fh_less_steps = CreateConVar( "fh_less_steps", 0, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Toggle PVS adding for animatronics (makes footsteps silent when they're not rendered)" ),
	fh_max_cupcakes = CreateConVar( "fh_max_cupcakes", 3, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Maximum amount of cupcakes Chica can spawn" ),
	
	fh_discord_url_webhook = CreateConVar( "fh_discord_url_webhook", "none", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Discord Integration webhook." )
	--fh_discord_url_avatar = CreateConVar( "fh_discord_url_avatar", "none", {FCVAR_ARCHIVE, FCVAR_SERVER_CAN_EXECUTE}, "Discord Integration avatar." )
}

local colors = {
    Gray = Color(200, 200, 200),
    Freddy = Color(139, 69, 19),
    Bonnie = Color(50, 40, 255),
    Endo = Color(255, 255, 255),
    Chica = Color(255, 255, 0),
    Foxy = Color(255, 0, 0),
    Shadow = Color(105, 0, 255), 
    Clown = Color(216, 93, 244),
    Springtrap = Color(105, 150, 70)
}

killerData = {
    ["pill_wfreddy2"] = {name = "freddy", fullname = "fazhunt.animatronics.freddy", color = colors.Freddy},
    ["pill_wbonnie2"] = {name = "bonnie", fullname = "fazhunt.animatronics.bonnie", color = colors.Bonnie},
    ["pill_wchica2"] = {name = "chica", fullname = "fazhunt.animatronics.chica", color = colors.Chica},
    ["pill_wfoxy2"] = {name = "foxy", fullname = "fazhunt.animatronics.foxy", color = colors.Foxy},
    ["pill_endo02"] = {name = "endo", fullname = "fazhunt.animatronics.endo", color = colors.Endo},
    ["pill_sfreddy2"] = {name = "sfreddy", fullname = "fazhunt.animatronics.sfreddy", color = colors.Shadow},
    ["pill_wgfreddy2"] = {name = "sfreddy", fullname = "fazhunt.animatronics.gfreddy", color = colors.Gray},
    ["pill_clown"] = {name = "clown", fullname = "fazhunt.animatronics.clown", color = colors.Clown},
    ["pill_springtrap"] = {name = "springtrap", fullname = "fazhunt.animatronics.springtrap", color = colors.Springtrap},
    ["pill_plushtrap"] = {name = "plushtrap", fullname = "fazhunt.animatronics.plushtrap", color = colors.Springtrap}
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

local dontPrefer = {"pill_springtrap", "pill_plushtrap", "pill_wgfreddy2"}

-- по умолчанию нельзя выбирать этих аниматроников, пишем их в файлик, чтобы файликом можно было управлять
if !file.Exists("fh_preferables.txt", "DATA") then
	file.Write("fh_preferables.txt", table.concat(dontPrefer, "\n"))
end

function pill_makeSecondary(anim, bool)
	bool = bool or true
	if istable(anim) then
		for k, v in pairs( anim ) do
			killerData[v].secondary = bool
		end
	else
		killerData[anim].secondary = bool
	end
end

pill_makeSecondary( {"pill_endo02", "pill_sfreddy2", "pill_wgfreddy2"} )

function pill_makePreferable(anim, bool)
	bool = bool or false
	if istable(anim) then
		for k, v in pairs( anim ) do
			killerData[v].preferable = bool
		end
	else
		killerData[anim].preferable = bool
	end
end

pill_makePreferable(table.GetKeys(killerData), true)

if file.Exists("fh_preferables.txt", "DATA") then
    local data = file.Read("fh_preferables.txt", "DATA") or ""
	
	if data != "" then 
		local lines = string.Split(data, "\n")
		
		pill_makePreferable( lines )
	end
end

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

function getTeam(team)
	local teamname = 'Выжившие'
	
	if team == 2701 or string.find(team, 'animatronic') then
		teamname = 'Аниматроники'
	elseif team == TEAM_SPECTATOR or string.find(team, 'kill') then 
		teamname = ' '
	end
	return teamname
end

function formatTime(secs)
	if !secs then return nil end
    local minutes = math.floor(secs / 60)
    local secs = math.floor(secs % 60)
    return string.format("%02d:%02d", minutes, secs)
end

teamColors = {
	[2701] = Color(255, 25, 25),
	[TEAM_SPECTATOR] = Color(117, 117, 130),
	[TEAM_UNASSIGNED] = Color(84, 163, 255)
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