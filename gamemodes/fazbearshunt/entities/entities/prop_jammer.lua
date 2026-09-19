--hey guys
--I did everything in a hurry, so I'll finish the addon and fix the bugs later

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.PrintName = "#weapon_jammer"
ENT.Author = "sergeant"
ENT.Information = ""

ENT.Editable = false
ENT.Spawnable = false
ENT.AdminOnly = false

function ENT:Initialize()

	if ( CLIENT ) then return end

	self:SetModel( "models/fh/weapons/w_jammer.mdl" )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)
	
	local phys = self:GetPhysicsObject()
	if phys:IsValid() then
		phys:Wake()
	end
end

function ENT:OnRemove()
	if ( CLIENT ) then return end
	
	local pos = self:GetPos()
	
	local effectdata = EffectData()
	effectdata:SetStart( pos )
	effectdata:SetOrigin( pos )
	effectdata:SetScale( 2 )
	util.Effect( "GlassImpact", effectdata )
	self:EmitSound("SolidMetal.BulletImpact")
	
end

function ENT:PhysicsCollide( data, physobj )
	if ( CLIENT ) then return end
	
	if self.Activated then return end
	
	local HitEnt = data.HitEntity
	if not HitEnt:IsPlayer() then
		self:Remove()
		return
	end
	
	local owner = self:GetOwner()
	
	if data.Speed > 400 then
		if HitEnt:IsPlayer() then
			if SERVER and HitEnt:IsAnimatronic() then
				local pos = self:GetPos()
				
				local d = DamageInfo()
				d:SetDamage( 15 )
				d:SetAttacker( owner )
				d:SetInflictor( self )
				HitEnt:TakeDamageInfo( d )
				
				local pill = HitEnt:GetPillCostume()
				
				if pill:IsValid() then
					JammerStunAnimatronic( HitEnt, pill, owner, self )
					
					self.Activated = true
				end
				self:Remove()
			end
			--self:Remove()
		elseif data.HitNormal.x > 0 or data.HitNormal.x < 0 or data.HitNormal.y > 0 or data.HitNormal.y < 0 or data.HitNormal.z > 0 or data.HitNormal.z then
			self:Remove()
		end
	elseif data.Speed > 400 then
		self:Remove()
	end
end

function ENT:Think()
	if CLIENT then return end
	if self:WaterLevel() > 0 then 
		if !timer.Exists( "timerSnowballDestroy"..self:EntIndex() ) then
			timer.Create( "timerSnowballDestroy"..self:EntIndex(), 1, 1, function()
				if !self:IsValid() then return end
				self:Remove()
			end )
			self:Extinguish()
		end
	end
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end
end

local data = {}
function JammerStunAnimatronic(ply, ent, attacker, jammer)
	if !IsValid(ent) then return end
	
	if hook.Run("FH_HandleJammerHit", ply, ent, taserer) == false then return end
	
	local formtbl = ent.formTable
	
	if !formtbl then return end
	
	if SERVER then
		ply.jammered = true
		ply:DropToFloor()
		
		if IsValid(ent) then
			ent:SetNW2Bool("Jammered", true)
			local stunTimer = "JammerStun" .. ply:EntIndex()
			
			data.timerName = stunTimer
			data.attacker = attacker
			
			local jammerHandler = ent:Func("jammerStun", ply, ent, data)
			
			if not jammerHandler ~= false then
				ent:PillGesture("jammerstun", 5)
				ent:PillGesture("damaged1", 5)
				ent:GodEffects(8)
				ply:SetSpeedSlowdown(5)
				
				timer.Create(stunTimer, 5, 1, function()
					if IsValid(ply) then
						ply.jammered = false
					end
					if IsValid(ent) then
						ent:SetNW2Bool("Jammered", false)
					end
				end)
				playVoiceline(killers.GetName(formtbl.name), 'tasered', ply, 0.05)
			end
			ent:EmitSound('weapons/jammer_stun.mp3')
		end
	
		net.Start("StunEffect_Shake")
		net.Send(ply)
	
		ply:ScreenFade(SCREENFADE.IN, Color(255, 255, 255, 20), 2, 2)
	end
	
	if !IsValid(ent) then
		ent = ply
	end
	
	local fx = EffectData()
	fx:SetOrigin(ply:GetPos() + Vector(0, 0, 40))
	fx:SetStart(ply:GetPos())
	fx:SetMagnitude(10)
	fx:SetEntity(ent)
	util.Effect("teslaHitBoxes", fx, true, true)
	
	hook.Run("SuccessJammerHit", ply, ent, attacker, jammer)
end