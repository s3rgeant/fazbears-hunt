AddCSLuaFile()

ENT.PrintName = "Scrap Baby Claw"
ENT.Base = "base_anim"
ENT.Type = "anim"

ENT.Editable = false
ENT.Spawnable = false
ENT.AdminOnly = false

ENT.HopTime = 0.4

function ENT:Initialize()
	if ( CLIENT ) then return end

	self:SetModel( "models/torres/ffps/salvage/sbaby_claw.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	self:SetModelScale(3, .000001)
	--self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	self:SetTrigger(true)
	
	local phys = self:GetPhysicsObject()
	if phys:IsValid() then
		phys:Wake()
	end
end

function ENT:Touch(ent)
	if ent:IsPlayer() then
		self:SetTrigger(false)
	
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMass( 5000 )
			phys:EnableGravity( true )
			phys:EnableDrag( true )
			phys:SetAngleDragCoefficient( 5000 )
		end
		
		self:ProccessHit(ent)
	end
end

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "GoHome")
    self:NetworkVar("Float", 0, "HopThink")
    self:NetworkVar("Entity", 0, "Sucker")
end

function ENT:PhysicsSimulate( phys, deltatime )
end

function ENT:Think()
	local ply = self:GetOwner()
	if CLIENT and (self:GetGoHome() or self:GetSucker():IsValid()) then
		local direction = self:GetPos() - (ply:EyePos() - Vector(0,0,16))
		direction:Normalize()
		
		self:SetAngles(direction:Angle())
	end
	
	if SERVER and self:GetGoHome() then
		if IsValid(ply) then
			if ply:EyePos():Distance(self:GetPos()) < 100 then
				if self:GetSucker():IsValid() then
					self:GetSucker():SetNWEntity("_ScrapBabyHooker", NULL)
				end
				self:Remove()
				return
			end
		end
		if CurTime() > self:GetHopThink() and not self:GetSucker():IsValid() then
			if IsValid(ply) then
				local direction = self:GetPos() - (ply:EyePos() - Vector(0,0,16))
				direction:Normalize()
				
				--self:SetAngles(direction:Angle())
				
				local phys = self:GetPhysicsObject()
				
				if IsValid(phys) then
					phys:SetVelocity(direction * -600 + Vector(0,0,100))
				end
				
				self:SetHopThink(CurTime() + self.HopTime)
				self.HopTime = math.max(0.1, self.HopTime - 0.01)
			end
		end
	end

	self:NextThink( CurTime() )
	return true
end

function ENT:ProccessHit(target)
	local ply = self:GetOwner()
	
	if !IsValid(ply) then return end
	
	local wep = ply:GetActiveWeapon()
	
	if IsValid(wep) then
		if wep.ClawHit then -- проверяю наличие одной функции и похуй
			wep:ClawHit(target)
		end
	end
end

function ENT:OnRemove()
	local ply = self:GetOwner()
	
	if !IsValid(ply) then return end
	
	local wep = ply:GetActiveWeapon()
	
	if IsValid(wep) then
		if wep.ClawBack then -- проверяю наличие одной функции и похуй
			wep:ClawBack()
		end
	end
end

function ENT:PhysicsCollide( data, physobj )
	if ( CLIENT ) then return end
	
	if self:GetGoHome() then 
		return 
	end
	
	local ply = data.HitEntity
	
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass( 5000 )
		phys:EnableGravity( true )
		phys:EnableDrag( true )
		phys:SetAngleDragCoefficient( 5000 )
	end
	
	self:ProccessHit(ply)
end

if SERVER then return end

function ENT:Draw()
    self:DrawModel()
end