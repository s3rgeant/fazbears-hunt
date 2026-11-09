AddCSLuaFile()

local tr_t = {}

local function isNotSolid(ply)
	local col = ply:GetCollisionGroup()
	local notSolid = ply:GetMoveType() == MOVETYPE_NOCLIP 
		or col == COLLISION_GROUP_WORLD
		or col == COLLISION_GROUP_DEBRIS
		or col == COLLISION_GROUP_PASSABLE_DOOR
	return notSolid
end

hook.Add("SetupMove", "fh_outtheway", function(ply, mv, cmd)
	if not ply:Alive() then return end
	
	local notSolid = isNotSolid(ply)
	if notSolid then return end

	local vel = mv:GetVelocity()
	local vellen = vel:Length()
	if (vellen > ply:GetRunSpeed() * .85 or (ply:IsSprinting() and not ply:Crouching())) and vel.z > -300 then
		local origin = mv:GetOrigin()
		
		local dir = vel:GetNormalized()
		local fwd, rt = dir, Vector(dir.y, -dir.x, dir.z)
		
		local mins, maxs
		if ply:Crouching() then
			mins, maxs = ply:GetHullDuck()
		else
			mins, maxs = ply:GetHull()
		end
		
		local stepsize = 18
		
		if not ply:OnGround() then
			stepsize = 0
		end

		tr_t.start = origin
		tr_t.endpos = origin + fwd * 80
		tr_t.mins = Vector(mins.x, mins.y, stepsize)
		tr_t.maxs = maxs
		tr_t.collisiongroup = nil
		tr_t.filter = ply
		
		tr = util.TraceHull(tr_t)
		
		local target = tr.Entity
		
		if target:IsPlayer() and target:Team() == ply:Team() then
		
			local notSolid = isNotSolid(target)
			if notSolid then return end
		
			tr_t.endpos = origin + fwd * 120
			tr_t.filter = {ply, target}
			tr_t.collisiongroup = COLLISION_GROUP_PASSABLE_DOOR
			tr2 = util.TraceHull(tr_t)
			
			if tr2.Hit then return end
			
			local targvel = target:GetVelocity():Length()
			local dif = math.abs(vellen - targvel)
			if dif > 5 then
				ply:NoPlayerCollide(.5)
				
				local dir = (target:EyePos() - ply:EyePos()):Angle()
				
				local diff = math.AngleDifference(dir.y, ply:EyeAngles().y)
				diff = math.Clamp(diff, .5, -.5)
				ply:ViewPunch(Angle(0, diff, 0))
			end
		end
	end
end)

if SERVER then return end

local PLAYER = FindMetaTable("Player")
function PLAYER:NoPlayerCollide(duration)
	if !IsValid(self) then return end
	
	self:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
	self:CollisionRulesChanged()
end