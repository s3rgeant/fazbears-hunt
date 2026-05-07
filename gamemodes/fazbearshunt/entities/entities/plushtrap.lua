AddCSLuaFile()

ENT.Base            = "base_nextbot"
ENT.PrintName       = "Plushtrap"

local PT_DEFAULT_SPEED = 460
local PT_BOOST_SPEED = 600
local PT_ACCEL_SPEED = 1000

ENT.CurrentSpeed = PT_DEFAULT_SPEED

function ENT:Initialize()
    self:SetModel("models/tetTris/FNaF/HW/Plushtrap.mdl")
	self:SetModelScale(1.24)
	
	self.Active = false
	
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
	
	self:PlaySequenceNoWait('summon')
	self:SetMaterial("null")
	self:DrawShadow(false)
	
	timer.Simple(0.5, function()
		if IsValid(self) then
			self:SetMaterial()
			self:DrawShadow(true)
			timer.Simple(1.5, function()
				if IsValid(self) then
					self.Active = true
				end
			end)
		end
	end)

    self.AttackDamage  = 12
    self.AttackDelay   = 2
    self.NextAttackTime = 0
	
	self.usedLayers = {}
	self.Target = nil
	
	if CLIENT then
		if istable(animatronics) then
			animatronics[self] = true
		end
	end

    self.CrouchSpeed = 200
end
	
function ENT:UpdateTransmitState() 
	return TRANSMIT_ALWAYS
end

function ENT:OnRemove()
	if CLIENT then
		if istable(animatronics) then
			animatronics[self] = nil
		end
	end
end

function ENT:RunBehaviour()
    while (true) do
        local target = self:FindNearestPlayer()
		
		self.loco:SetDesiredSpeed( self.CurrentSpeed )
		
        if IsValid(target) and self.Active then
			self:PlaySequenceNoWait( 'run' )
			self:StartActivity( ACT_RUN )
			self.Target = target
            self:ChaseTarget(target)
        elseif self.Active then
			self:PlaySequenceNoWait( 'idle' )
			self.Target = nil
            coroutine.wait(1) 
        end

        coroutine.wait(0.2)
    end
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
		if path:GetAge() > 1 then
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
					self:EmitSound("fnaf3/plushtrap/plu_jump.mp3")
					self.CurrentSpeed = PT_BOOST_SPEED
				end
				
				timer.Create("pt_jump_delay".. self:EntIndex(), 2, 1, function() end)
			end
			for ply, _ in pairs(survivors) do
				if ply:Alive() and self:GetPos():DistToSqr(ply:GetPos()) <= (75 * 75) then
				
					local successHit = math.random(1,100) > 8
				
					local dmgInfo = DamageInfo()
					dmgInfo:SetDamage(self.AttackDamage)
					dmgInfo:SetAttacker(self)
					dmgInfo:SetInflictor(self)
					dmgInfo:SetDamageType(DMG_CLUB)
	
					if successHit then
						ply:TakeDamageInfo(dmgInfo)
						self:EmitSound("fnaf3/plushtrap/plu_attack_hit.mp3")
					else
						self:EmitSound("fnaf3/plushtrap/plu_attack_miss.mp3")
					end
	
					self.NextAttackTime = CurTime() + self.AttackDelay
					
					self:PillGesture('bite'.. (math.random(1,2) == 1 and "1" or "2"), 1, 1, 0, 1)
					break
				end
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
	self:EmitSound("fnaf3/plushtrap/plu_land.mp3")
	self:PillGesture('land', 2, 1, 0, 1)
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