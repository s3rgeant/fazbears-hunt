AddCSLuaFile()

ENT.Base            = "base_nextbot"
ENT.PrintName       = "Bearling"

local PT_DEFAULT_SPEED = 475
local PT_BOOST_SPEED = 600
local PT_ACCEL_SPEED = 1000

ENT.CurrentSpeed = PT_DEFAULT_SPEED

function ENT:Initialize()
    self:SetModel("models/fh/animatronics/bear5.mdl")
	self:SetModelScale(0.7)
	
	self:SetCollisionBounds( Vector(-12,-12,0), Vector(12,12,32) )
	self:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
    
	if SERVER then
		self:SetHealth(2000)
		self.loco:SetStepHeight(35)
		self.loco:SetClimbAllowed(true)
		
		self.loco:SetJumpHeight( 50 )
		self.loco:SetDesiredSpeed(self.CurrentSpeed)
		self.loco:SetAcceleration(PT_ACCEL_SPEED)
		self.loco:SetDeceleration(PT_ACCEL_SPEED/4)
	end
	
	self.boneMorphs={
		["bip_eye_R"] = {scale = Vector(0.5,0.5,0.5)},
		["bip_eye_L"] = {scale = Vector(0.5,0.5,0.5)},
		["bip_EyeLid_0_R"] = {scale = Vector(0,0,0)},
		["bip_EyeLid_1_R"] = {scale = Vector(0,0,0)},
		["bip_EyeLid_0_L"] = {scale = Vector(0,0,0)},
		["bip_EyeLid_1_L"] = {scale = Vector(0,0,0)},
	}

	for k, v in pairs(self.boneMorphs) do
		local b = self:LookupBone(k)

		if b then
			if v.pos then
				self:ManipulateBonePosition(b, v.pos)
			end

			if v.rot then
				self:ManipulateBoneAngles(b, v.rot)
			end

			if v.scale then
				self:ManipulateBoneScale(b, v.scale)
			end
		end
	end
	
	self.Active = true

    self.AttackDamage  = 2
    self.AttackDelay   = 0.5
    self.NextAttackTime = 0
	
	self.usedLayers = {}
	self.Target = nil

    self.CrouchSpeed = 200
end

function ENT:RunBehaviour()
    while (true) do
		self.loco:SetDesiredSpeed( self.CurrentSpeed )
		
		target = IsValid(self.Target) and self.Target:Alive() and self.Target or nil
		
		if self.Active then
			if IsValid(target) then
				self:PlaySequenceNoWait( 'run' )
				self:StartActivity( ACT_RUN )
				self.Target = target
				self:ChaseTarget(target)
			else
				self:PlaySequenceNoWait( 'idle' )
				self.Target = nil
				coroutine.wait(1) 
			end
		end

        coroutine.wait(0.2)
    end
end

function ENT:SetTarget(target)
	self.Target = target
end

function ENT:FindNearestPlayer()
    local nearestPly
    local minDistSqr = math.huge

    for _, ply in player.Iterator() do
        if ply:Alive() and ply:IsSurvivor() and !ply:IsInvisible() then
            local distSqr = self:GetPos():DistToSqr(ply:GetPos())
            if distSqr < minDistSqr then
                minDistSqr = distSqr
                nearestPly = ply
            end
        end
    end

    return nearestPly
end

function ENT:ChaseTarget(ply)
	local path = Path("Follow")
	path:SetMinLookAheadDistance(300)
	path:SetGoalTolerance(20)
	
	path:Compute(self, ply:GetPos())
	if not path:IsValid() then return end
	
	while path:IsValid() and IsValid(ply) and self.Active do
		if path:GetAge() > 0.2 then
			path:Compute(self, ply:GetPos())
		end
	
		path:Update(self)
	
		if self.loco:IsStuck() then
			self:HandleStuck()
			return
		end
	
		coroutine.yield()
	end
end

function ENT:HandleStuck()
    self.loco:ClearStuck()
    local nav = navmesh.GetNearestNavArea(self:GetPos(), false, 150, false, true)
    if IsValid(nav) then
        self:SetPos(nav:GetCenter() + Vector(0,0,5))
    end
end

function ENT:Think()
	if SERVER and self.Active then
		if self.NextAttackTime and CurTime() >= self.NextAttackTime then
			if !timer.Exists("pt_jump_delay".. self:EntIndex()) and self.Target and ((math.random(1,80) == 1 and self.Target:IsSprinting() and self:GetVelocity():LengthSqr() > 60) 
			or self.Target and (self.Target:GetPos().z > self:GetPos().z and self:GetPos():Distance(self.Target:GetPos()) < 250)) then
				if self:IsOnGround() then
					self.loco:Jump()
					self.CurrentSpeed = PT_BOOST_SPEED
				end
				
				timer.Create("pt_jump_delay".. self:EntIndex(), 2, 1, function() end)
			end
			
			local ply = self.Target
			
			if IsValid(ply) and ply:Alive() and ply:IsPlayer() and ply:IsSurvivor() and self:GetPos():DistToSqr(ply:GetPos()) <= (100 * 100) then
			
				local successHit = math.random(1,100) > 15
			
				local dmgInfo = DamageInfo()
				dmgInfo:SetDamage(self.AttackDamage)
				dmgInfo:SetAttacker(self)
				dmgInfo:SetInflictor(self)
				dmgInfo:SetDamageType(DMG_CLUB)

				if successHit then
					ply:TakeDamageInfo(dmgInfo)
					self:EmitSound("bear/bear_knife_hit" .. math.random(1,3) .. ".mp3")
				else
					self:EmitSound("fnaf3/hit-miss.mp3")
				end

				self.NextAttackTime = CurTime() + self.AttackDelay
				
				self:PillGesture('attack', 1, 1, 0, 1)
			end
		end
	
		self:CheckDoorBreak()
		self:NextThink(CurTime())
		return true
	end
end

function ENT:CheckDoorBreak()
	local doors = ents.FindInSphere(self:GetPos(), 50)
	for _, door in ipairs(doors) do
		local class = door:GetClass()
		if class == "prop_door_rotating" or class == "func_door" or class == "func_door_rotating" then
			local canUse = door:HasSpawnFlags(8192)
			
			if !canUse then continue end

			door:Fire("Open")
			door:TakeDamage(100, self, self)
		end
	end
end

function ENT:OnLandOnGround( ent )
	self.CurrentSpeed = PT_DEFAULT_SPEED
	
	if self.Target then
		self:StartActivity( ACT_RUN )
	else
		self:StartActivity( ACT_IDLE )
	end
end

function ENT:PlaySequenceNoWait( name, speed )
	speed = speed or 1
	
	local seq = self:LookupSequence( name )
	if self:GetSequence() != seq then
		self:SetSequence( name )
		
		self:ResetSequenceInfo()
		self:SetCycle( 0 )
		self:SetPlaybackRate( speed )
	end
end
	
function ENT:PillGesture(name, priority, rate, blendin, out, start)
    if not IsValid(self) then return end
	local seq = self:LookupSequence(name)
	local id = nil
	
	if self.usedLayers[seq] then
		id = self.usedLayers[seq]
	end
	
	if !id then
		id = self:AddLayeredSequence(seq, priority or 1)
		self.usedLayers[seq] = id
	else
		self:SetLayerSequence(id, seq)
	end
	self:SetLayerPlaybackRate(id, (rate or 1) / 2)
	self:SetLayerCycle(id, start or 0)
	
	self:SetLayerWeight(id, 1)
	self:SetLayerBlendIn(id, blendin or 0.1)
	self:SetLayerBlendOut(id, out or 0.1)
	
end