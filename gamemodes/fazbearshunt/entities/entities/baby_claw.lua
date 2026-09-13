AddCSLuaFile()

ENT.PrintName = "Scrap Baby Claw"
ENT.Base = "base_anim"
ENT.Type = "anim"

ENT.Editable = false
ENT.Spawnable = false
ENT.AdminOnly = false

ENT.HopTime = 0.2

ENT.Mins = Vector(-10, -10, -5)
ENT.Maxs = Vector(10, 10, 15)

function ENT:Initialize()
	if ( CLIENT ) then return end

	self:SetModel( "models/torres/ffps/salvage/sbaby_claw.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_BBOX )
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	self:SetModelScale(3, .000001)
	self:SetTrigger(true)
	--self:UseTriggerBounds(true, 0)
	
	self:AddEFlags(EFL_NO_WATER_VELOCITY_CHANGE) -- не тот эффект который я ожидал
	
	self:SetCollisionBounds(self.Mins, self.Maxs)
	self:NextThink( CurTime() )
	
	local phys = self:GetPhysicsObject()
	if phys:IsValid() then
		phys:Wake()
	end
end

function ENT:Touch(ent)
	if ent:IsPlayer() then
		local owner = self:GetOwner()
		if IsValid(owner) and ent == owner then
			return
		end
	
		self:ProccessHit(ent)
		
		self:SetTrigger(false)
	
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMass( 5000 )
			phys:EnableGravity( true )
			phys:EnableDrag( true )
			phys:SetAngleDragCoefficient( 5000 )
		end
	end
end

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "GoHome")
    self:NetworkVar("Float", 0, "HopThink")
    self:NetworkVar("Entity", 0, "Sucker")
end

function ENT:PhysicsSimulate( phys, deltatime )
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

function ENT:Think()
	local ply = self:GetOwner()
	
	if SERVER and not self:GetGoHome() then
		if IsValid(ply) then
			local phys = self:GetPhysicsObject()

			if IsValid(phys) then
				phys:SetVelocityInstantaneous(ply:EyeAngles():Forward() * 2500)
			end
		end
	end
	
	if CLIENT and (self:GetGoHome() or self:GetSucker():IsValid()) then
		local direction = self:GetPos() - (ply:EyePos() - Vector(0,0,16))
		direction:Normalize()
		
		self:SetAngles(direction:Angle())
	end
	
	if SERVER and self:GetGoHome() then
		if IsValid(ply) then
			local function checkDistance(pos)
				if pos:Distance(self:GetPos()) < 100 then
					if self:GetSucker():IsValid() then
						local sucker = self:GetSucker()
						sucker:SetNWEntity("_ScrapBabyHooker", NULL)
						timer.Remove("SmoothLookAt_" .. sucker:EntIndex())
						
						local ent = ply:GetPillCostume()
						if IsValid(ent) and ent.formTable.playerCatch then
							ent.formTable.playerCatch(ply, ent, self, sucker)
						end
					end
					self:Remove()
					return true
				end
				return false
			end
			
			if not checkDistance(ply:EyePos()) then checkDistance(ply:GetPos()) end
		end
		if CurTime() > self:GetHopThink() and not self:GetSucker():IsValid() then
			if IsValid(ply) then
				local direction = self:GetPos() - (ply:EyePos() - Vector(0,0,16))
				direction:Normalize()
				
				--self:SetAngles(direction:Angle())
				
				local phys = self:GetPhysicsObject()
				
				if IsValid(phys) then
					phys:SetVelocity(direction * -700 + Vector(0,0,25))
				end
				
				self:SetHopThink(CurTime() + self.HopTime)
				self.HopTime = math.max(0, self.HopTime - 0.01)
			end
		end
	end
	
	if false and SERVER then
		if IsValid(ply) and self:GetVelocity():Length() >= 100 then
			local tr = util.TraceLine({
				start = ply:GetPos() + Vector(0,0,16),
				endpos = self:GetPos(),
				filter = {self, ply, self:GetSucker()}
			})
			
			if not tr.HitWorld and tr.Hit and tr.Entity:IsPlayer() then
				if not tr.Entity:IsAnimatronic() then
					local target = tr.Entity
					target:EmitSound(")physics/flesh/flesh_impact_bullet3.wav")
					local armor = target:IsPlayer() and target:Armor() or 0
					
					local edata = EffectData()
					edata:SetOrigin(tr.HitPos)
					edata:SetEntity(target)
					util.Effect("BloodImpact", edata, true, true)
					
					target:SetVelocity(self:GetVelocity())
					
					target:TakeDamage(target:Health() + armor, ply)
				end
			end
		end
	end

	self:NextThink( CurTime() )
	return true
end

function ENT:ProccessHit(target)
	local ply = self:GetOwner()
	
	if not IsValid(ply) then return end
	
	local wep = ply:GetActiveWeapon()
	
	if not IsValid(wep) then return false end
	if not wep.ClawHit then return false end -- проверяю наличие одной функции и похуй
		
	return wep:ClawHit(target)
end

function ENT:OnRemove()
	local ply = self:GetOwner()
	
	if !IsValid(ply) then return end
	
	local wep = ply:GetActiveWeapon()
	
	if IsValid(wep) then
		if wep.ClawBack then -- проверяю наличие одной функции и похуй
			wep:ClawBack(true)
		end
	end
end

function ENT:PhysicsCollide( data, physobj )
	if CLIENT then return end
	
	if self:GetGoHome() then return end
	if self.NoCollide then return end
	self.NoCollide = true
	
	local ply = data.HitEntity
	local owner = self:GetOwner()
	
	if IsValid(owner) and ply == owner then
		return
	end
	
	local stopProcess = self:ProccessHit(ply)
	
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass( 5000 )
		phys:EnableGravity( true )
		phys:EnableDrag( true )
		phys:SetAngleDragCoefficient( 5000 )
	end
end

if SERVER then return end

function ENT:Draw()
    self:DrawModel()
end