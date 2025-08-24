AddCSLuaFile()

ENT.Base            = "base_nextbot"
ENT.PrintName       = "Plushtrap"

local PT_DEFAULT_SPEED = 540
local PT_BOOST_SPEED = 600
local PT_ACCEL_SPEED = 1000

function ENT:Initialize()
    self:SetModel("models/tetTris/FNaF/HW/Plushtrap.mdl")
	self:SetModelScale(1.24)
	
	self.Active = false
	
	self:SetCollisionBounds( Vector(-12,-12,0), Vector(12,12,32) )
    
	if SERVER then
		self:SetCollisionBounds( Vector( -8, -8, 0 ), Vector( 12, 8, 32 ) )
		--self:SetSolid(SOLID_NONE)
		self:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
		self:SetHealth(2000)
		
		self.loco:SetJumpHeight( 50 )
		self.loco:SetDesiredSpeed(PT_DEFAULT_SPEED)
		self.loco:SetAcceleration(PT_ACCEL_SPEED)
		self.loco:SetDeceleration(200)
	end
	
	self:PlaySequenceNoWait('summon')
	self:SetMaterial("null")
	
	timer.Simple(0.5, function()
		if IsValid(self) then
			self:SetMaterial()
			timer.Simple(1.5, function()
				self.Active = true
			end)
		end
	end)

    -- Время перезарядки удара и нанесение урона
    self.AttackDamage  = 10
    self.AttackDelay   = 2  -- секунды
    self.NextAttackTime = 0
	
	self.usedLayers = {}
	self.Target = nil

    self.CrouchSpeed = 200
end

function ENT:RunBehaviour()
    while (true) do
        local target = self:FindNearestPlayer()
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

-- Функция поиска ближайшего игрока
function ENT:FindNearestPlayer()
    local nearestPly
    local minDistSqr = math.huge

    for _, ply in player.Iterator() do
        if ply:Alive() and ply:Team() != TEAM_SPECTATOR and ply:Team() != 2701 then
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

    local stuckTime = CurTime()
    
    while path:IsValid() and IsValid(ply) and self.Active do
        if path:GetAge() > 0.2 then
            path:Compute(self, ply:GetPos())
        end

        path:Update(self)

        if self.loco:IsStuck() then
            self:HandleStuck()
            return
        end

        if CurTime() - stuckTime > 5 then
            self:HandleStuck()
            return
        end

        coroutine.yield()
    end
end

function ENT:HandleStuck()
    if not self.LastPos then self.LastPos = self:GetPos() end
    if self.LastStuckCheck and CurTime() - self.LastStuckCheck < 2 or not self.Active then return end
    self.LastStuckCheck = CurTime()

    if self:GetPos():DistToSqr(self.LastPos) < 10 then
        local navArea = navmesh.GetNearestNavArea(self:GetPos(), true, 100)
        if IsValid(navArea) then
            local newPos = navArea:GetRandomPoint()
            if newPos then
                self:SetPos(newPos)
            end
        else
            self:SetPos(self:GetPos() + Vector(math.random(-100, 100), math.random(-100, 100), 10))
        end

        if self:IsOnGround() then
            self.loco:Jump()
        end
    end

    self.LastPos = self:GetPos()
end

function ENT:Think()
	if SERVER and self.Active then
		if self.NextAttackTime and CurTime() >= self.NextAttackTime then
			if !timer.Exists("pt_jump_delay".. self:EntIndex()) and self.Target and ((math.random(1,80) == 1 and self.Target:IsSprinting() and self:GetVelocity():LengthSqr() > 60) 
			or self.Target and (self.Target:GetPos().z > self:GetPos().z and self:GetPos():Distance(self.Target:GetPos()) < 250)) then
				if self:IsOnGround() then
					self.loco:Jump()
					self.loco:SetAcceleration(50)
					self.loco:SetDesiredSpeed(PT_BOOST_SPEED)
				end
				
				timer.Create("pt_jump_delay".. self:EntIndex(), 2, 1, function() end)
			end
			for _, ply in player.Iterator() do
				if ply:Alive() and ply:Team() != 2701 and self:GetPos():DistToSqr(ply:GetPos()) <= (75 * 75) then
					local dmgInfo = DamageInfo()
					dmgInfo:SetDamage(self.AttackDamage)
					dmgInfo:SetAttacker(self)
					dmgInfo:SetInflictor(self)
					dmgInfo:SetDamageType(DMG_CLUB)
	
					ply:TakeDamageInfo(dmgInfo)
	
					self.NextAttackTime = CurTime() + self.AttackDelay
					
					self:PillGesture('bite'.. (math.random(1,2) == 1 and "1" or "2"), 1, 1, 0, 1)
					self:EmitSound("fnaf3/spr_punch_hit.wav")
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
	self.loco:SetDesiredSpeed(PT_DEFAULT_SPEED)
	self.loco:SetAcceleration(PT_ACCEL_SPEED)
	
	if self.Target then
		self:StartActivity( ACT_RUN )
	else
		self:StartActivity( ACT_IDLE )
	end
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