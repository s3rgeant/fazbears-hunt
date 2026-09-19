AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.PrintName = "FH Dummy"
ENT.Author = "sergeant"

ENT.AutomaticFrameAdvance = true

local mins = Vector(-16, -16, 0)
local maxs = Vector(16, 16, 72)
local maxs_cr = Vector(16, 16, 36)

ENT.Poses = {
	"dummy_land",
	"dummy_crouch_land"
}
ENT.CurrentPose = 1

ENT.NextPoseChange = 0

function ENT:Initialize()
    self:SetModel("models/fh/entities/male_dummy.mdl")
		
	self:PhysicsInitBox(mins, maxs)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
    
    if SERVER then
		self:PrecacheGibs()
		self:SetUseType( SIMPLE_USE )
		
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:Wake()
			phys:SetInertia(Vector(1e9, 1e9, 1e9)) 
			phys:SetMass(800)
		end
	end
		
	self:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
	self:EnableCustomCollisions(true)
    
    self:ResetSequence( self.Poses[self.CurrentPose] )
    self:SetHealth(10)
    
    local owner = self:GetOwner()
    if IsValid(owner) then
        owner._FHDummy = self
        local ground = owner:GetGroundEntity()
        if IsValid(ground) and ground:GetClass() == "func_tracktrain" then
            self:SetParent(ground)
        end
		
		if CLIENT then
			local color = owner:GetPlayerColor()
			self.GetPlayerColor = function() return color end
		end
    end
end

function ENT:Draw()
	--self:FrameAdvance()
	self:DrawModel()
end

if SERVER then
	function ENT:OnRemove()
		local owner = self:GetOwner()
		if IsValid(owner) then
			owner._FHDummy = nil
		end
	end
end

local PLAYER = FindMetaTable("Player")

if PLAYER then
	function PLAYER:GetDummy()
		return self._FHDummy
	end
end
	
function ENT:OnTakeDamage(dmginfo)
	local attacker = dmginfo:GetAttacker()
	local owner = self:GetOwner()
	
	local isOwner = attacker == owner
	
	if attacker:IsPlayer() and attacker:IsSurvivor() and attacker ~= owner then return 0 end

	if not isOwner then
		self:TakePhysicsDamage(dmginfo)
		
		local health = self:Health()
		health = health - dmginfo:GetDamage()
		self:SetHealth(health)
	else
		local phys = self:GetPhysicsObject()
		if phys:IsValid() then
			phys:SetVelocity(dmginfo:GetDamageForce() * 35)
		end
	end

	if self:Health() <= 0 then
		local force = (self:GetPos() - attacker:GetPos())
		force:Normalize()
		
		local pos = self:WorldSpaceCenter()
		
		local effectData = EffectData()
		effectData:SetOrigin(pos)
		effectData:SetScale(2)
		
		util.Effect("GlassImpact", effectData)
		
		effectData:SetOrigin(pos + Vector(0,0,30))
		effectData:SetScale(2)
		
		util.Effect("GlassImpact", effectData)
		
		self:GibBreakClient(force * 150)
		self:Remove()
	end
end

function ENT:FHGravGunPunt()
	return false
end

function ENT:GravGunPunt(ply)
	local owner = self:GetOwner()
	
	return ply == owner
end

function ENT:DragHandle(wep, ent, dragger)
	local ply = self:GetOwner()
	
	return ply == dragger
end

function ENT:DragFunc(wep, Phys, dragger, Pos, Aim)
	local Pos2 = Pos + Aim * 28
	local OffPos = self:LocalToWorld(wep.Drag.OffPos)
	local Dif = Pos2 - OffPos
	
	local len = Dif:Length()
	
	local Nom = Dif:GetNormalized() * 6 * len
	Phys:SetVelocity(Nom, OffPos)
end

function ENT:OutlineOnUse(ply)
	local owner = self:GetOwner()
	return owner == ply
end

function ENT:ChangeCollisions(mins, maxs)
	self:SetCollisionBounds(mins, maxs)

	self:PhysicsInitBox(mins, maxs)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
		
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
		phys:SetInertia(Vector(1e9, 1e9, 1e9)) 
		phys:SetMass(800)
	end
end

local trT
function ENT:Use( ply )
	if ply:IsPlayer() and ply:IsSurvivor() then 
		local owner = self:GetOwner()
		
		if not IsValid(owner) or ply == owner then
		
			if CurTime() < self.NextPoseChange then return end
			local curPos = self.CurrentPose
			local nextPose = curPos + 1
			
			if nextPose > #self.Poses then
				nextPose = 1
			end
			
			local sequencePose = self.Poses[nextPose]
			
			local crouchPose = sequencePose == "dummy_crouch_land"
			
			if not crouchPose then
				if not trT then
					trT = {}
				
					trT.collisiongroup = COLLISION_GROUP_PASSABLE_DOOR
					trT.mins = mins
					trT.maxs = maxs
				end
				
				trT.filter = self
				trT.start = self:GetPos()
				trT.endpos = self:GetPos()
			
				local tr = util.TraceEntity(trT, self)

				if tr.Hit then return end
			end
			
			if crouchPose then
				self:ChangeCollisions(mins, maxs_cr)
			else
				self:ChangeCollisions(mins, maxs)
			end
		
			self:SetSequence( sequencePose )
			self.CurrentPose = nextPose
			self:SetCycle(0)
			
			self:EmitSound("AI_BaseNPC.BodyDrop_Light")
			
			self.NextPoseChange = CurTime() + .2
		end
	end
end

hook.Add( "StartCommand", "fh_dummy_dragging", function( ply, cmd )
	if !ply:Alive() then return end

	local wep = ply:GetActiveWeapon()
	
	if not IsValid(wep) then return end
	
	if wep:GetClass() ~= "weapon_empty_hands" then return end
	
	if wep.Drag then
		local dragEntity = wep.Drag.Entity

		if not IsValid(dragEntity) then return end

		if dragEntity:GetClass() == "fh_dummy" then
			cmd:RemoveKey(IN_SPEED)
		end
	end
end)