AddCSLuaFile()

ENT.Base            = "base_nextbot"
ENT.PrintName       = "Plushtrap"

local PT_DEFAULT_SPEED = 540
local PT_BOOST_SPEED = 600

function ENT:Initialize()
    self:SetModel("models/tetTris/FNaF/HW/Plushtrap.mdl")
	self:SetModelScale(1.24)
	
	self.Active = false
    
	if SERVER then
		self:SetCollisionBounds( Vector( -8, -8, 0 ), Vector( 12, 8, 72 ) )
		self:SetSolid(SOLID_NONE)
		self:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
		self:SetHealth(100)
		
		self.loco:SetJumpHeight( 50 )
		self.loco:SetDesiredSpeed(PT_DEFAULT_SPEED)
		self.loco:SetAcceleration(900)
		self.loco:SetDeceleration(200)
	end
	
	self:PlaySequenceNoWait('summon')
	//self:SetMaterial("null")
	
	timer.Simple(0.5, function()
		if IsValid(self) then
			self:SetMaterial()
			self.Active = true
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
        else
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

    for _, ply in ipairs(player.GetAll()) do
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

    while path:IsValid() and IsValid(ply) do
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

function ENT:Think()
	if SERVER and self.Active then
		if self.NextAttackTime and CurTime() >= self.NextAttackTime then
			if !timer.Exists("pt_jump_delay".. self:EntIndex()) and self.Target and ((math.random(1,80) == 1 and self.Target:IsSprinting() and self:GetVelocity():LengthSqr() > 60) 
			or (self.Target:GetPos().z > self:GetPos().z and self:GetPos():Distance(self.Target:GetPos()) < 250)) then
				self.loco:Jump()
				self.loco:SetAcceleration(50)
				self.loco:SetDesiredSpeed(PT_BOOST_SPEED)
				
				timer.Create("pt_jump_delay".. self:EntIndex(), 2, 1, function() end)
			end
			for _, ply in ipairs(player.GetAll()) do
				if ply:Alive() and ply:Team() != 2701 and self:GetPos():DistToSqr(ply:GetPos()) <= (75 * 75) then
					local dmgInfo = DamageInfo()
					dmgInfo:SetDamage(self.AttackDamage)
					dmgInfo:SetAttacker(self)
					dmgInfo:SetInflictor(self)
					dmgInfo:SetDamageType(DMG_CLUB)
	
					ply:TakeDamageInfo(dmgInfo)
	
					self.NextAttackTime = CurTime() + self.AttackDelay
					
					self:PillGesture('bite'.. (math.random(1,2) == 1 and "1" or "2"), 1, 1, 0, 1)
					break
				end
			end
		end
	
		self:CheckDoorBreak()
		if self.Target then
			self:CheckStuck()
		end
		self:NextThink(CurTime())
		return true
	end
end

function ENT:CheckDoorBreak()
	local doors = ents.FindInSphere(self:GetPos(), 50)
	for _, door in ipairs(doors) do
		if door:GetClass() == "prop_door_rotating" or door:GetClass() == "func_door" or door:GetClass() == "func_door_rotating" then
			door:Fire("Open")
			door:TakeDamage(100, self, self)
		end
	end
end

function ENT:CheckStuck()
    if not self.LastPos then self.LastPos = self:GetPos() end
    if self.LastStuckCheck and CurTime() - self.LastStuckCheck < 2 then return end
    self.LastStuckCheck = CurTime()

    if self:GetPos():DistToSqr(self.LastPos) < 5 then
        local navArea = navmesh.GetNearestNavArea(self:GetPos(), true, 100)
        
        if IsValid(navArea) then
            local newPos = navArea:GetRandomPoint()
            if newPos then
                self:SetPos(newPos)
            end
        else
            local directions = {
                Vector(50, 0, 0), Vector(-50, 0, 0), 
                Vector(0, 50, 0), Vector(0, -50, 0), 
                Vector(0, 0, 50), Vector(0, 0, -50)
            }
            
            for _, dir in ipairs(directions) do
                local traceData = {
                    start = self:GetPos(),
                    endpos = self:GetPos() + dir,
                    filter = self
                }
                local trace = util.TraceLine(traceData)
                
                if trace.Hit then
                    self:SetPos(trace.HitPos + Vector(0, 0, 5))
                    break
                end
            end
            
            self:SetPos(self:GetPos() + Vector(math.random(-50, 50), math.random(-50, 50), 5))
        end
        
        self.loco:Jump()
    end
    
    self.LastPos = self:GetPos()
end

function ENT:OnLandOnGround( ent )
	self.loco:SetDesiredSpeed(PT_DEFAULT_SPEED)
	self.loco:SetAcceleration(900)
	
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