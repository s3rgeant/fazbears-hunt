
AddCSLuaFile()
DEFINE_BASECLASS( "player_fh" )
local PLAYER = {}

function PLAYER:SetupDataTables()

	self.Player:NetworkVar( "Bool", "FoxyRushing" )
	self.Player:NetworkVar( "Bool", "FoxyBouncing" )
	self.Player:NetworkVar( "Bool", "FoxySession" )
	self.Player:NetworkVar( "Bool", "FoxyBlockM1" )
	self.Player:NetworkVar( "Float", "FoxyRushEnd" )
	self.Player:NetworkVar( "Int", "FoxyTokens" )
	BaseClass.SetupDataTables( self )

end


function PLAYER:Loadout()

	self.Player:SwitchToDefaultWeapon()

end

function PLAYER:Death()
	local ply = self.Player
	ply:SetFoxyRushing(false)
	ply:SetFoxyBouncing(false)
	ply:SetFoxyBlockM1(false)
end

function PLAYER:Spawn()
	local ply = self.Player
	ply:SetFoxyRushing(false)
	ply:SetFoxyBouncing(false)
	ply:SetFoxyBlockM1(false)
end

local function BlightCheckCollision(ply, mv, velocity)
	velocity = Vector(velocity.x, velocity.y, 0)

	local eyeDir = mv:GetAngles():Forward()
	eyeDir.z = 0
	eyeDir:Normalize()

	local speedDir = velocity:GetNormalized()

	local startPos = mv:GetOrigin() + Vector(0, 0, ply:GetStepSize())
	local traceDist = 30
	local hullSize = 8
	
	local tr = util.TraceLine( {
		start = startPos,
		endpos = startPos + eyeDir * traceDist,
		filter = {"snowball", ply}
	} )
	tr.startPos = startPos
	
	--debugoverlay.Line( startPos, startPos + speedDir * traceDist )
	
	if tr.Hit then return tr end

	local tr = util.TraceHull({
		start = startPos,
		endpos = startPos + speedDir * traceDist,
		mins = Vector(-hullSize, -hullSize, 0),
		maxs = Vector(hullSize, hullSize, ply:OBBMaxs().z * 0.7),
		mask = MASK_PLAYERSOLID,
		filter = {"snowball", ply}
	})
	
	--debugoverlay.Box( startPos + speedDir * traceDist, Vector(-hullSize, -hullSize, 0), Vector(hullSize, hullSize, ply:OBBMaxs().z * 0.8), 3, tr.Hit and Color(0, 255, 0) or Color(255,0,0))

	tr.startPos = startPos
	return tr
end

function PLAYER:Move( mv )
	BaseClass.Move( self, mv )

	local ply = self.Player
	local prevVel = mv:GetVelocity()

	local rushing = ply:GetFoxyRushing()

	if not rushing then return end
	
	if !ply:OnGround() then return end
	
	if CurTime() > ply:GetFoxyRushEnd() or ply:WaterLevel() >= 2 or ply:Crouching() then
		foxy.EndCharge(ply) 
		return
	end

	local dir = mv:GetMoveAngles():Forward()
	dir.z = 0
	dir:Normalize()
	
	mv:SetVelocity(dir * 900)

	if IsFirstTimePredicted() then
		local vm = ply:GetViewModel(0)
		if IsValid(vm) and not vm.IsCharging then
			vm:SetPlaybackRate(1.3)
		end
	end
	
	if mv:KeyDown(IN_ATTACK) then return end

	local tr = BlightCheckCollision(ply, mv, prevVel)
	if not tr.Hit then return end
	
	local hitEnt = tr.Entity
	
	if IsValid(hitEnt) and hitEnt:IsPlayer() and not hitEnt:IsAnimatronic() then return end
	
	if CLIENT and hitEnt ~= game.GetWorld() and !hitEnt:IsPlayer() then
		return
	end
	
	if IsValid(hitEnt) and !hitEnt:IsPlayer() then
	
		local target = hitEnt
		local physobj = target:GetPhysicsObject()
		if IsValid(physobj) and target:Health() > 0 then
			local wep = ply:GetActiveWeapon()
			
			local dmginfo = DamageInfo()
			dmginfo:SetAttacker(ply)
			dmginfo:SetInflictor(IsValid(wep) and wep or ply)
			dmginfo:SetDamage(100)
		
			SuppressHostEvents(NULL)
			target:TakeDamageInfo(dmginfo)
			SuppressHostEvents(ply)
			
			return
		end
		
		if hitEnt:GetClass() == "prop_door_rotating" then
			breakBustDoor(ply, hitEnt, 45)
			return
		end
	end
	
	local bounceDir = Vector(tr.HitNormal.x, tr.HitNormal.y, 0)
	if bounceDir:LengthSqr() < 0.0001 then
		bounceDir = -dir
	end
	bounceDir:Normalize()

	ply:SetFoxyRushing(false)
	ply:SetFoxyBouncing(true)

	mv:SetVelocity(bounceDir * 1500)

	local ent = ply:GetPillCostume()

	if IsFirstTimePredicted() then
		if SERVER then
			
			local rf = RecipientFilter()
			rf:AddAllPlayers()
			rf:RemovePlayer(ply)
			
			ply:EmitSound(")blight/impact.wav", nil, nil, 1, nil, 0, 1, rf)
		else
			ply:EmitSound(")blight/impact.wav")
		end

		if CLIENT and ply:GetFoxyTokens() > 0 then
			RMBHint(2)
		end
	end

	if SERVER and IsValid(ent) then
		ent:PillGesture("chargestun", 1, 0.8, 0.1, 0.3)
	end
	
	if IsValid(ent) and ply:GetFoxyTokens() == 0 then
		foxy.EndCharge(ply)
		return
	end
	
	if CLIENT then return end

	ply.blightTimeoutTimer = "BlightTimeout_" .. ply:SteamID()
	timer.Create(ply.blightTimeoutTimer, 2, 1, function()
		if not IsValid(ply) then return end
		ply.blightTimeoutTimer = nil
	
		foxy.Stun(ply)

		timer.Simple(5, function()
			if IsValid(ply) then
				receiveTokensBack(ply, ent)
			end
		end)
	end)
end


function PLAYER:SetModel()

end

player_manager.RegisterClass( "player_foxy", PLAYER, "player_fh" )
