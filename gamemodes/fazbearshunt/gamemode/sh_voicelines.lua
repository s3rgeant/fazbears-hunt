--CONVAR gmod_language

local allowed_langs = {"ru", "en", "hu"}

local localized_voicelines_path = ""

local currentLanguage = GetConVar("gmod_language"):GetString()

if table.HasValue(allowed_langs, currentLanguage) then
	localized_voicelines_path = currentLanguage .. "/"
end

local function fileExistsInGame(path)
    return file.Exists(path, "GAME")
end

local function generateVoicelines(baseName, count)
    local lines = {}
    for i = 1, count do
        local localizedPath = "vo/" .. localized_voicelines_path .. baseName .. i .. ".mp3"
		
        if fileExistsInGame("sound/" .. localizedPath) then
            table.insert(lines, localizedPath)
        else
            local defaultPath = "vo/" .. baseName .. i .. ".mp3"
            if fileExistsInGame("sound/" .. defaultPath) then
                table.insert(lines, defaultPath)
            else
                table.insert(lines, localizedPath)
            end
        end
    end
    return lines
end

local voicelines = {
    freddy = {
        kill = generateVoicelines("freddy_kill", 5),
        lastkill = generateVoicelines("freddy_lastkill", 4),
        chase = generateVoicelines("freddy_chase", 6),
        focus = generateVoicelines("freddy_focus", 3),
        trip = generateVoicelines("freddy_trip", 4),
        negative = generateVoicelines("freddy_negative", 3),
        tasered = generateVoicelines("freddy_tasered", 4),
    },
    bonnie = {
        kill = generateVoicelines("bonnie_kill", 7),
        lastkill = generateVoicelines("bonnie_lastkill", 3),
        chase = generateVoicelines("bonnie_chase", 6),
        spotted = generateVoicelines("bonnie_spotted", 3),
        trip = generateVoicelines("bonnie_trip", 5),
        negative = generateVoicelines("bonnie_negative", 3),
        tasered = generateVoicelines("bonnie_tasered", 4),
    },
    chica = {
        kill = generateVoicelines("chica_kill", 6),
        lastkill = generateVoicelines("chica_lastkill", 5),
        chase = generateVoicelines("chica_chase", 5),
        plant = generateVoicelines("chica_placecake", 3),
        trip = generateVoicelines("chica_trip", 5),
        negative = generateVoicelines("chica_negative", 3),
        tasered = generateVoicelines("chica_tasered", 4),
    },
    foxy = {
        kill = generateVoicelines("foxy_kill", 3),
        lastkill = generateVoicelines("foxy_lastkill", 4),
        chase = generateVoicelines("foxy_chase", 3),
        trip = generateVoicelines("foxy_trip", 5),
        negative = generateVoicelines("foxy_negative", 3),
        tasered = generateVoicelines("foxy_tasered", 4),
        miss = generateVoicelines("foxy_miss", 1),
    },
    endo = {
        kill = generateVoicelines("endo_kill", 6),
        lastkill = generateVoicelines("endo_lastkill", 4),
        chase = generateVoicelines("endo_chase", 4),
        grab = generateVoicelines("endo_grab", 4),
        throw = generateVoicelines("endo_throw", 3),
        trip = generateVoicelines("endo_trip", 6),
        negative = generateVoicelines("endo_negative", 3),
        tasered = generateVoicelines("endo_tasered", 4),
    },
    sfreddy = {
        kill = generateVoicelines("sfreddy_kill", 6),
        chase = generateVoicelines("sfreddy_chase", 6),
    },
    clown = {
        kill = generateVoicelines("clown_kill", 3),
        lastkill = generateVoicelines("clown_lastkill", 1),
        chase = generateVoicelines("clown_chase", 2),
        tasered = generateVoicelines("clown_tasered", 4),
    },
    plushtrap = {
        kill = generateVoicelines("plushtrap_kill", 15),
        lastkill = generateVoicelines("plushtrap_lastkill", 7),
        chase = generateVoicelines("plushtrap_chase", 18),
        start = generateVoicelines("plushtrap_start", 13),
        trip = generateVoicelines("plushtrap_trip", 7),
        tasered = generateVoicelines("plushtrap_tasered", 4),
    },
    mangle = {
        kill = generateVoicelines("mangle_kill", 5),
        lastkill = generateVoicelines("mangle_lastkill", 1),
        chase = generateVoicelines("mangle_chase", 3),
        negative = generateVoicelines("mangle_negative", 3),
        positive = generateVoicelines("mangle_positive", 3),
        trip = generateVoicelines("mangle_trip", 3),
        tasered = generateVoicelines("mangle_tasered", 3),
    },
	tchica = {
        kill = generateVoicelines("tchica_kill", 3),
        lastkill = generateVoicelines("tchica_lastkill", 3),
        laugh = generateVoicelines("tchica_laugh", 7),
        negative = generateVoicelines("tchica_negative", 3),
        positive = generateVoicelines("tchica_positive", 3),
        grab = generateVoicelines("tchica_grab", 4),
        release = generateVoicelines("tchica_release", 3),
        tasered = generateVoicelines("tchica_tasered", 3),
    },
}

local function addVoiceline(v_name, voicelines)
    sound.Add({
        name = v_name,
        channel = CHAN_VOICE,
        volume = 1.0,
        sound = voicelines
    })
end

for character, types in pairs(voicelines) do
    for action, sounds in pairs(types) do
        addVoiceline(character .. "." .. action, sounds)
    end
end
