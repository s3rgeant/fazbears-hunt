
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
	
	fh_gifts_spawning = CreateConVar( "fh_gifts_spawning", 0, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Toggle gifts spawning" ),
	fh_animatronic_immortal = CreateConVar( "fh_animatronic_immortal", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Toggle immortality for animatronic team" ),
	fh_less_steps = CreateConVar( "fh_less_steps", 0, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Toggle PVS adding for animatronics (makes footsteps silent when they're not rendered)" ),
	
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

-- Одиночные аниматроники. Могут вывезти в соло
killerInfo = {
    ["pill_wfreddy2"] = {name = "Фредди", color = colors.Freddy},
    ["pill_wbonnie2"] = {name = "Бонни", color = colors.Bonnie},
    ["pill_wchica2"] = {name = "Чика", color = colors.Chica},
    ["pill_wfoxy2"] = {name = "Фокси", color = colors.Foxy},
    ["pill_clown"] = {name = "Клоун", color = colors.Clown}
}

-- Классы поддержки. В одиночку за них сложнее играть.
duoKillerInfo = {
    ["pill_endo02"] = {name = "Эндоскелет", color = colors.Endo},
    ["pill_sfreddy2"] = {name = "Шедоу Фредди", color = colors.Shadow}
}

-- ХЗ. Спрингтрап
springtrapInfo = {
    ["pill_springtrap"] = {name = "Спрингтрап", color = colors.Springtrap},
    ["pill_plushtrap"] = {name = "Плюштрап", color = colors.Springtrap}
}

killerData = {
    ["pill_wfreddy2"] = {name = "freddy"},
    ["pill_wbonnie2"] = {name = "bonnie"},
    ["pill_endo02"] = {name = "endo"},
    ["pill_wchica2"] = {name = "chica"},
    ["pill_wfoxy2"] = {name = "foxy"},
    ["pill_wgfreddy2"] = {name = "sfreddy"},
    ["pill_sfreddy2"] = {name = "sfreddy"},
    ["pill_clown"] = {name = "clown"},
    ["pill_springtrap"] = {name = "springtrap"},
    ["pill_plushtrap"] = {name = "plushtrap"}
}

function getAllKillers()
	local solos = table.Copy(killerInfo)
	local duos = table.Copy(duoKillerInfo)
	return table.Merge(solos, duos)
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