
include( "player_class/player_sandbox.lua" )

GM.Name = "Fazbear's Hunt"
GM.Author = "sergeant"
GM.Email = "N/A"
GM.Website = "N/A"

conVars = {
	halo_radius = CreateConVar( "halo_radius", 2000, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Halo radius." ),
	halo_time = CreateConVar( "halo_time", 10, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Time for halo to dissolve." ),
	halo_cooldown = CreateConVar( "halo_cooldown", 120, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Cooldown for halo." )
}

local colors = {
    Gray = Color(200, 200, 200),
    Freddy = Color(139, 69, 19),
    Bonnie = Color(50, 40, 255),
    Endo = Color(255, 255, 255),
    Chica = Color(255, 255, 0),
    Foxy = Color(255, 0, 0),
    Shadow = Color(105, 0, 255), 
    Clown = Color(105, 150, 70)
}

killerInfo = {
    ["pill_wfreddy2"] = {name = "Фредди", color = colors.Freddy},
    ["pill_wbonnie2"] = {name = "Бонни", color = colors.Bonnie},
    ["pill_endo02"] = {name = "Эндоскелет", color = colors.Endo},
    ["pill_wchica2"] = {name = "Чика", color = colors.Chica},
    ["pill_wfoxy2"] = {name = "Фокси", color = colors.Foxy}
}

duoKillerInfo = {
    ["pill_sfreddy2"] = {name = "Шедоу Фредди", color = colors.Shadow},
    ["pill_springtrap"] = {name = "Клоун", color = colors.Clown}
}

function getAllKillers()
	local solos = table.Copy(killerInfo)
	local duos = table.Copy(duoKillerInfo)
	return table.Merge(solos, duos)
end