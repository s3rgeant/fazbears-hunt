if not fh then fh = fh or {} end

local round_music = {
	[0] = "music/first_minute.wav"
}

if IsChristmas() then
	round_music[0] = "music/christmas_timer.wav"
end

function fh.AddRoundMusic(num, music)
	if !round_music[num] then
		round_music[num] = music
	end
end

function fh.GetRoundMusic(num)
	if round_music[num] then
		return round_music[num]
	end
	return round_music[0]
end

fh.RoundTypes = fh.RoundTypes or {}
fh.RoundTypeNameToID = fh.RoundTypeNameToID or {}
fh.RoundTypeIDToName = fh.RoundTypeIDToName or {}
fh.RoundTypeIDCounter = 0

function fh.RegisterRoundType(name, id, func, weight, minPlayers, maxPlayers)
    assert(name, "Round type name is required")
    assert(func, "Round type function is required")

    if isstring(id) then
        id = tonumber(util.CRC(id)) % 100000
    elseif not isnumber(id) then
        fh.RoundTypeIDCounter = fh.RoundTypeIDCounter + 1
        id = fh.RoundTypeIDCounter
    end
	
	if fh.RoundTypes[id] then 
		print("[FH] Failed to register new round type with ID: " .. id .. ". Such ID is already in use!")
		return nil
	end

    fh.RoundTypes[id] = {
        name = name,
        id = id,
        func = func,
        weight = weight or 1,
        minPlayers = minPlayers,
        maxPlayers = maxPlayers
    }

    fh.RoundTypeNameToID[name] = id
    fh.RoundTypeIDToName[id] = name
	
	return id, name
end

function fh.SetRoundTypeBlocked(id, block)
	if !fh.RoundTypes[id] then return end
	if !isbool(block) then return end
	
	fh.RoundTypes[id].blocked = block
end

local forceAuto = {
	"fh_force_roundtype 0",
	"fh_force_roundtype 1",
	"fh_force_roundtype 2",
	"fh_force_roundtype 3",
}

if CLIENT then function registerNewRound() end end

concommand.Add( "fh_force_roundtype", function( ply, cmd, args )
	if IsValid(ply) and !ply:IsSuperAdmin() then return end
	local round = tonumber(args[1]) or 0
	registerNewRound(round)
end,

function( cmd, args )
	return forceAuto
	
end)

function fh.SelectRoundType(forcedID)
    local selected
    local playerCount = player.GetCount()

    if forcedID then
        selected = fh.RoundTypes[forcedID]
		
		if selected.blocked then
			print("Forcing a round type that is blocked!")
		end
    else
        local pool = {}
        for id, data in pairs(fh.RoundTypes) do
			if data.blocked then continue end
		
            local minOK = not data.minPlayers or playerCount >= data.minPlayers
            local maxOK = not data.maxPlayers or playerCount <= data.maxPlayers

            if minOK and maxOK then
                local entries = math.max(1, data.weight or 1)
                for _ = 1, entries do
                    table.insert(pool, data)
                end
            end
        end

        if #pool == 0 then
            ErrorNoHalt("[fh] what have you done? Seems like there is no round types that support this ( "..playerCount.." ) player count.\n")
            return
        end

        selected = pool[math.random(#pool)]
    end

    if selected then
        fh.SetRoundType(selected.id)
        selected.func()
		return selected.id
    else
        ErrorNoHalt("[fh] Couldn't select round type!\n")
		return -1
    end
end

function fh.GetRoundTypes()
    local types = {}
    for id, _ in pairs(fh.RoundTypes) do
        table.insert(types, id)
    end
    return types
end

function fh.GetRoundTypeByName(name)
    return fh.RoundTypeNameToID[name]
end

function fh.GetRoundTypeNameByNumber(id)
    return fh.RoundTypeIDToName[id]
end

fh.RegisterRoundType("regular", 0, function()
	AssignKillers()
	freezeAnimatronics()
	RandomTaser()
end, 100)

include( "springtrap.lua" )
include( "bonnie_tag.lua" )
include( "bear5.lua" )
include( "custom_round.lua" )