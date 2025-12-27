--hey guys
--I did everything in a hurry, so I'll finish the addon and fix the bugs later

AddCSLuaFile()

DEFINE_BASECLASS( "base_anim" )

ENT.PrintName = "Snowball"
ENT.Author = "ESSTX"
ENT.Information = ""

ENT.Editable = false
ENT.Spawnable = false
ENT.AdminOnly = false
ENT.counter = 0
if SERVER then ENT.W = false end
if CLIENT then ENT.EmitTime = 0 end

game.AddDecal( "SnowImpact", "decals/winterland/snow_impact" )
DMG_SNOWBALL = 257

ENT.ImpactSounds = {
	"impact/snow_impact1.wav","impact/snow_impact2.wav","impact/snow_impact3.wav","impact/snow_impact4.wav"
}

function ENT:Initialize()

	if ( CLIENT ) then return end

	self:SetModel( "models/fh/weapons/w_snowball.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)
	local phys = self:GetPhysicsObject()
	if (phys:IsValid()) then
		phys:Wake()
	end
end

function ENT:SpawnFunction(ply, tr)
	ent:SetOwner(ply)
end


function ENT:PhysicsSimulate( phys, deltatime )
end

function ENT:OnRemove()

	if ( CLIENT ) then return end
	local pos = self:GetPos()
	local effectdata = EffectData()
	effectdata:SetStart( pos )
	effectdata:SetOrigin( pos )
	effectdata:SetScale( 6 )
	util.Effect( "GlassImpact", effectdata )
	self:EmitSound(self.ImpactSounds[math.random( 1, 4 )])
	
end

if SERVER then
	util.AddNetworkString( "SSIE" )
end

function ENT:PhysicsCollide( data, physobj )
	if ( CLIENT ) then return end
	self.counter = self.counter + 1
	if(self.counter>6)then

		util.Decal("SnowImpact", data.HitPos + data.HitNormal, data.HitPos - data.HitNormal)
		self:Remove()
	end
	
	local HitEnt = data.HitEntity
	
	if data.Speed > 400 then
		if HitEnt:IsPlayer() then
			if ( SERVER ) then
				local pos = self.Entity:GetPos()
				local d = DamageInfo()
				d:SetDamage( 15 )
				d:SetAttacker( self:GetOwner() )
				d:SetDamageCustom( DMG_SNOWBALL )
				--d:SetInflictor( weapon_snowball )
				HitEnt:TakeDamageInfo( d )
				
				--HitEnt:SetVelocity( self:GetForward() * 450  )
			
				net.Start( "SSIE" )
				net.Send( HitEnt )
			end
			util.Decal("SnowImpact", data.HitPos + data.HitNormal, data.HitPos - data.HitNormal*10)
			self:Remove()
		elseif HitEnt:IsNPC() then
			HitEnt:TakeDamage( 40, self:GetOwner(), self:GetOwner() )
			HitEnt:SetVelocity( self:GetForward() * 200  )
			util.Decal("SnowImpact", data.HitPos + data.HitNormal, data.HitPos - data.HitNormal*10)
			self:Remove()
		elseif(data.HitNormal.x > 0 or data.HitNormal.x < 0 or data.HitNormal.y > 0 or data.HitNormal.y < 0 or data.HitNormal.z > 0 or data.HitNormal.z)then
			util.Decal("SnowImpact", data.HitPos + data.HitNormal, data.HitPos - data.HitNormal)

			self:Remove()
		end
	elseif data.Speed > 400 then
		util.Decal("SnowImpact", data.HitPos + data.HitNormal, data.HitPos - data.HitNormal)
		self:Remove()
	end
end

function ENT:Think()
	if CLIENT then return end
	if self:WaterLevel()>0 then 
		if !timer.Exists( "timerSnowballDestroy"..self:EntIndex() ) then
			timer.Create( "timerSnowballDestroy"..self:EntIndex(), 1, 1, function()
				if !self:IsValid() then return end
				self:Remove()
			end )
			self:Extinguish()
			self.W = true
		end
	end
end

if SERVER then return end

function ENT:Draw()
    self:DrawModel()

	if(self.Entity:GetVelocity():LengthSqr() < 300)then return end
	if(CurTime() > self.EmitTime)then
		local pos = self.Entity:GetPos()
		local emitter = ParticleEmitter( pos )
		local part = emitter:Add( "effects/splash4", pos )
		if ( part ) then
			part:SetDieTime( 2 )
			part:SetStartAlpha( 255 )
			part:SetEndAlpha( 0 )
			part:SetStartSize( math.random(1, 3) )
			part:SetEndSize( 1 )
			part:SetGravity( Vector( 0, 0, -12 ) )
			part:SetAngles( Angle( math.random(0, 360), math.random(0, 360), math.random(0, 360) ) )
			part:SetVelocity( VectorRand() * 3 )
		end
		for i = 1, math.random(3, 6) do
			local part = emitter:Add( "effects/splash4", pos )
			if ( part ) then
				part:SetDieTime( 2 )
				part:SetStartAlpha( 255 )
				part:SetEndAlpha( 0 )
				part:SetStartSize( math.random(0.6, 1) )
				part:SetEndSize( 0 )
				part:SetGravity( Vector( 0, 0, -24 ) )
				part:SetAngles( Angle( math.random(0, 360), math.random(0, 360), math.random(0, 360) ) )
				part:SetVelocity( VectorRand() * 2 )
			end
		end
		emitter:Finish()
		self.EmitTime = CurTime() + math.random(0.02, 0.05)
	end
end

if CLIENT then
	local s_ = 0
	hook.Add( "RenderScreenspaceEffects", "SnowImpactEffect", function()
		if(s_>0)then
			s_ = s_ - 0.0001
			DrawMaterialOverlay( "effect/snow_overlay_bump", s_ )
		end
	end )
	net.Receive( "SSIE", function()
		s_ = 0.1
	end )
end