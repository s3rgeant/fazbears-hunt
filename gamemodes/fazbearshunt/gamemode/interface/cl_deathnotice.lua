
local hud_deathnotice_time = GetConVar( "hud_deathnotice_time" )
local cl_drawhud = GetConVar( "cl_drawhud" )

surface.CreateFont("FHKillicon", { 
	font = "Share Tech Mono", 
	size = 22, 
	shadow = true,
	extended = true, 
	weight = 500, 
	antialias = true, 
	--	bold = true 
	}
)

-- These are our kill icons
local Color_Icon = Color( 255, 80, 0, 255 )
local NPC_Color_Enemy = Color( 250, 50, 50, 255 )
local NPC_Color_Friendly = Color( 50, 200, 50, 255 )

killicon.AddAlias( "prop_physics_multiplayer", "prop_physics" )

local function HandleAchievements( victimType )

	-- Try to find by name
	for id, tab in pairs( list.Get( "NPC" ) ) do
		if ( tab.Name == victimType ) then
			victimType = tab.Class
		end
	end
	-- If fails, try to omit the translation system #
	if ( victimType:StartsWith( "#" ) ) then
		victimType = victimType:sub( 2 )
	end

	local bIsEnemy = IsEnemyEntityName( victimType )
	local bIsFriend = IsFriendEntityName( victimType )

	if ( bIsEnemy ) then
		achievements.IncBaddies()
	end

	if ( bIsFriend ) then
		achievements.IncGoodies()
	end

	if ( !bIsFriend && !bIsEnemy ) then
		achievements.IncBystander()
	end

end

-- Backwards compatiblity for addons
net.Receive( "PlayerKilledByPlayer", function()

	local victim	= net.ReadEntity()
	local inflictor	= net.ReadString()
	local attacker	= net.ReadEntity()

	if ( !IsValid( attacker ) ) then return end
	if ( !IsValid( victim ) ) then return end

	hook.Run( "AddDeathNotice", attacker:Name(), attacker:Team(), inflictor, victim:Name(), victim:Team(), 0 )

end )

net.Receive( "PlayerKilledSelf", function()

	local victim = net.ReadEntity()
	if ( !IsValid( victim ) ) then return end

	hook.Run( "AddDeathNotice", nil, 0, "suicide", victim:Name(), victim:Team(), 0 )

end )

net.Receive( "PlayerKilled", function()

	local victim = net.ReadEntity()
	if ( !IsValid( victim ) ) then return end

	local inflictor = net.ReadString()
	local attacker = net.ReadString()

	hook.Run( "AddDeathNotice", "#" .. attacker, -1, inflictor, victim:Name(), victim:Team(), 0 )

end )

net.Receive( "PlayerKilledNPC", function()

	local victimtype = net.ReadString()
	local inflictor = net.ReadString()
	local attacker = net.ReadEntity()

	--
	-- For some reason the killer isn't known to us, so don't proceed.
	--
	if ( !IsValid( attacker ) ) then return end

	hook.Run( "AddDeathNotice", attacker:Name(), attacker:Team(), inflictor, "#" .. victimtype, -1, 0 )

	local bIsLocalPlayer = ( IsValid( attacker ) && attacker == LocalPlayer() )
	if ( bIsLocalPlayer ) then
		HandleAchievements( victimtype )
	end

end )

net.Receive( "NPCKilledNPC", function()

	local victim	= "#" .. net.ReadString()
	local inflictor	= net.ReadString()
	local attacker	= "#" .. net.ReadString()

	hook.Run( "AddDeathNotice", attacker, -1, inflictor, victim, -1, 0 )

end )

-- The new way
DEATH_NOTICE_FRIENDLY_VICTIM = 1
DEATH_NOTICE_FRIENDLY_ATTACKER = 2
--DEATH_NOTICE_HEADSHOT = 4
--DEATH_NOTICE_PENETRATION = 8
net.Receive( "DeathNoticeEvent", function()
	
	local team_a = -1
	local team_v = -1
	local team_ass = -1

	local attacker = nil
	local attackerType = net.ReadUInt( 2 )
	if ( attackerType == 1 ) then
		attacker = net.ReadString()
	elseif ( attackerType == 2 ) then
		attacker = net.ReadEntity()
	elseif ( attackerType == 3 ) then
		attacker = net.ReadEntity()
		team_a = net.ReadUInt( 12 )
	end

	local inflictor	= net.ReadString()

	local victim = nil
	local victimType = net.ReadUInt( 2 )
	if ( victimType == 1 ) then
		victim = net.ReadString()
	elseif ( victimType == 2 ) then
		victim = net.ReadEntity()
	elseif ( victimType == 3 ) then
		victim = net.ReadEntity()
		team_v = net.ReadUInt( 12 )
	end

	local flags = net.ReadUInt( 8 )

	local assistant = nil
	local assistantType = net.ReadUInt( 2 )
	if ( assistantType == 1 ) then
		assistant = net.ReadString()
	elseif ( assistantType == 2 ) then
		assistant = net.ReadEntity()
	elseif ( assistantType == 3 ) then
		assistant = net.ReadEntity()
		team_ass = net.ReadUInt( 12 )
	end

	local bIsLocalPlayer = ( isentity( attacker ) && IsValid( attacker ) && attacker == LocalPlayer() )
	if ( bIsLocalPlayer && isstring( victim ) ) then
		HandleAchievements( victim )
	end

	if ( bit.band( flags, DEATH_NOTICE_FRIENDLY_VICTIM ) != 0 ) then team_v = -2 end
	if ( bit.band( flags, DEATH_NOTICE_FRIENDLY_ATTACKER ) != 0 ) then team_a = -2 end

	-- Handle player entities
	if ( isentity( attacker ) and attacker:IsValid() and attacker:IsPlayer() ) then 
		attacker = attacker:Name() 
	end
	if ( isentity( victim ) and victim:IsValid() and victim:IsPlayer() ) then 
		victim = victim:Name() 
	end
	if ( isentity( assistant ) and assistant:IsValid() and assistant:IsPlayer() ) then 
		assistant = assistant:Name() 
	end

	-- Handle other entities
	if ( isentity( attacker ) and attacker:IsValid() ) then attacker = attacker:GetClass() end
	if ( isentity( victim ) and victim:IsValid() ) then victim = victim:GetClass() end
	if ( isentity( assistant ) and assistant:IsValid() ) then assistant = assistant:GetClass() end

	hook.Run( "AddDeathNotice", attacker, team_a, inflictor, victim, team_v, flags, assistant, team_ass )

end )

local Deaths = {}

local function getDeathColor( teamID, target )

	if ( teamID == -1 ) then
		return table.Copy( NPC_Color_Enemy )
	end

	if ( teamID == -2 ) then
		return table.Copy( NPC_Color_Friendly )
	end

	return table.Copy( team.GetColor( teamID ) )

end

function GM:AddDeathNotice( attacker, team1, inflictor, victim, team2, flags, assistant, team3 )

	if ( inflictor == "suicide" ) then attacker = nil end

	local Death = {}
	Death.time		= CurTime()

	Death.left		= attacker
	Death.right		= victim
	Death.icon		= inflictor
	Death.flags		= flags
	Death.assistant = assistant

	Death.color1	= getDeathColor( team1, Death.left )
	Death.color2	= getDeathColor( team2, Death.right )
	Death.color3	= getDeathColor( team3, Death.left )

	table.insert( Deaths, Death )

end

local function DrawDeath( x, y, death, time )

	local w, h = killicon.GetSize( death.icon )
	if ( !w or !h ) then return end

	local fadeout = ( death.time + time ) - CurTime()

	local alpha = math.Clamp( fadeout * 255, 0, 255 )
	death.color1.a = alpha
	death.color2.a = alpha
	death.color3.a = alpha
	
	local killiconX =  x - w / 2

	-- Draw Icon
	killicon.Render( killiconX, y, death.icon, alpha )
	
	local assistantLeft
	if ( death.assistant ) then
		assistantLeft = death.assistant .. " + "
	end

	-- Draw KILLER
	if ( death.left ) then
		local leftW, leftH = draw.SimpleText( death.left, "FHKillicon", x - ( w / 2 ) - 16, y + h / 2, death.color1, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
		
		if assistantLeft then
			draw.SimpleText( assistantLeft, "FHKillicon", x - ( w / 2 ) - 16 - leftW, y + h / 2, death.color3, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
		end
	end

	-- Draw VICTIM
	draw.SimpleText( death.right, "FHKillicon", x + ( w / 2 ) + 16, y + h / 2, death.color2, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )

	return math.ceil( y + h * 0.75 )

	-- Font killicons are too high when height corrected, and changing that is not backwards compatible
	--return math.ceil( y + math.max( h, 28 ) )

end

function GM:DrawDeathNotice( x, y )

	if ( cl_drawhud:GetInt() == 0 ) then return end

	local time = hud_deathnotice_time:GetFloat()
	local reset = Deaths[1] != nil -- Don't reset it if there's nothing in it

	x = x * ScrW()
	y = y * ScrH()

	-- Draw
	for k, Death in ipairs( Deaths ) do

		if ( Death.time + time > CurTime() ) then

			if ( Death.lerp ) then
				x = x * 0.3 + Death.lerp.x * 0.7
				y = y * 0.3 + Death.lerp.y * 0.7
			end

			Death.lerp = Death.lerp or {}
			Death.lerp.x = x
			Death.lerp.y = y

			y = DrawDeath( math.floor( x ), math.floor( y ), Death, time )
			reset = false

		end

	end

	-- We want to maintain the order of the table so instead of removing
	-- expired entries one by one we will just clear the entire table
	-- once everything is expired.
	if ( reset ) then
		Deaths = {}
	end

end