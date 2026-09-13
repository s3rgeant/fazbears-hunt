local PLAYER = FindMetaTable("Player")

if not PLAYER then return end

function PLAYER:SetAssistant(attacker)
	self._Assistant = attacker
	self._AssistantTime = CurTime()
end

function PLAYER:GetAssistant(duration)
	if not self._Assistant then
		return nil
	end

	if duration and CurTime() - self._AssistantTime > duration then
		self._Assistant = nil
		self._AssistantTime = nil

		return nil
	end

	return self._Assistant
end

function PLAYER:ClearAssistant()
	self._Assistant = nil
	self._AssistantTime = nil
end

function GM:PlayerDeath( ply, inflictor, attacker )

	-- Don't spawn for at least 2 seconds
	ply.NextSpawnTime = CurTime() + 2
	ply.DeathTime = CurTime()

end

hook.Add( "PostEntityTakeDamage", "FH_LastAssistantSet", function( ent, dmgInfo, wasDamageTaken )
	if ( ent:IsPlayer() or ent:IsNPC() ) and wasDamageTaken then
		local attacker = dmgInfo:GetAttacker()
		
		if ent ~= attacker and not attacker:IsWeapon() then
			ent:SetAssistant(attacker)
		end
	end
end)

function GM:DoPlayerDeath( ply, attacker, dmginfo )

	if ( !dmginfo:IsDamageType( DMG_REMOVENORAGDOLL ) ) then
		ply:CreateRagdoll()
	end

	ply:AddDeaths( 1 )

	if ( attacker:IsValid() && attacker:IsPlayer() ) then

		if ( attacker == ply ) then
			attacker:AddFrags( -1 )
		else
			attacker:AddFrags( 1 )
		end

	end

	-- Don't spawn for at least 2 seconds
	ply.NextSpawnTime = CurTime() + 2
	ply.DeathTime = CurTime()
	
	local inflictor = dmginfo:GetInflictor()

	if ( IsValid( attacker ) && attacker:GetClass() == "trigger_hurt" ) then attacker = ply end

	if ( IsValid( attacker ) && attacker:IsVehicle() && IsValid( attacker:GetDriver() ) ) then
		attacker = attacker:GetDriver()
	end

	if ( !IsValid( inflictor ) && IsValid( attacker ) ) then
		inflictor = attacker
	end

	-- Convert the inflictor to the weapon that they're holding if we can.
	-- This can be right or wrong with NPCs since combine can be holding a
	-- pistol but kill you by hitting you with their arm.
	if ( IsValid( inflictor ) && inflictor == attacker && ( inflictor:IsPlayer() || inflictor:IsNPC() ) ) then

		inflictor = inflictor:GetActiveWeapon()
		if ( !IsValid( inflictor ) ) then inflictor = attacker end

	end
	
	local assistant = ply:GetAssistant(11)
	
	if IsValid( assistant ) && assistant == attacker then
		assistant = nil
	end

	player_manager.RunClass( ply, "Death", inflictor, attacker )

	if ( attacker == ply ) then

		self:SendDeathNotice( nil, "suicide", ply, 0 )

		MsgAll( attacker:Nick() .. " suicided!\n" )

		return
	end

	if ( attacker:IsPlayer() ) then

		self:SendDeathNotice( attacker, inflictor:GetClass(), ply, 0, assistant )

		if IsValid(assistant) then
			MsgAll( attacker:Nick() .. " killed " .. ply:Nick() .. " using " .. inflictor:GetClass() .. " with assistance of " .. assistant:Name() .. "\n" )
		else
			MsgAll( attacker:Nick() .. " killed " .. ply:Nick() .. " using " .. inflictor:GetClass() .. "\n" )
		end

		return
	end

	if ( !IsValid( attacker ) ) then attacker = game.GetWorld() end
	if ( !IsValid( inflictor ) ) then inflictor = attacker end

	local flags = 0
	if ( attacker:IsNPC() and attacker:Disposition( ply ) == D_LI ) then flags = flags + DEATH_NOTICE_FRIENDLY_ATTACKER end

	self:SendDeathNotice( self:GetDeathNoticeEntityName( attacker ), inflictor:GetClass(), ply, flags, assistant )

	MsgAll( ply:Nick() .. " was killed by " .. attacker:GetClass() .. "\n" )

end

DEATH_NOTICE_FRIENDLY_VICTIM = 1
DEATH_NOTICE_FRIENDLY_ATTACKER = 2
function GM:SendDeathNotice( attacker, inflictor, victim, flags, assistant )

	net.Start( "DeathNoticeEvent" )

		if ( isstring( attacker ) ) then
			net.WriteUInt( 1, 2 )
			net.WriteString( attacker:sub( 0, 512 ) )
		elseif ( IsValid( attacker ) ) then
			if not attacker:IsPlayer() then
				net.WriteUInt( 2, 2 )
				net.WriteEntity( attacker )
			else
				net.WriteUInt( 3, 2 )
				net.WriteEntity( attacker )
				net.WriteUInt( attacker:Team(), 12)
			end
		else
			-- TODO: game.GetWorld will be "written" here, because its not IsValid. Make it write a separate type?
			net.WriteUInt( 0, 2 )
		end

		if ( isstring( inflictor ) ) then
			net.WriteString( inflictor:sub( 0, 512 ) )
		else
			-- Should never really reach here..
			net.WriteString( "" )
		end

		if ( isstring( victim ) ) then
			net.WriteUInt( 1, 2 )
			net.WriteString( victim:sub( 0, 512 ) )
		elseif ( IsValid( victim ) ) then
			if not victim:IsPlayer() then
				net.WriteUInt( 2, 2 )
				net.WriteEntity( victim )
			else
				net.WriteUInt( 3, 2 )
				net.WriteEntity( victim )
				net.WriteUInt( victim:Team(), 12)
			end
		else
			net.WriteUInt( 0, 2 )
		end

		net.WriteUInt( flags, 8 )

		if ( isstring( assistant ) ) then
			net.WriteUInt( 1, 2 )
			net.WriteString( assistant:sub( 0, 512 ) )
		elseif ( IsValid( assistant ) ) then
			if not assistant:IsPlayer() then
				net.WriteUInt( 2, 2 )
				net.WriteEntity( assistant )
			else
				net.WriteUInt( 3, 2 )
				net.WriteEntity( assistant )
				net.WriteUInt( assistant:Team(), 12)
			end
		else
			net.WriteUInt( 0, 2 )
		end

	net.Broadcast()

end