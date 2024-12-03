local meta = FindMetaTable("Player")

if not meta then return end

deathRagdolls = {}
function meta:CreateRagdoll()
	if !(self || self:IsValid() || self:IsPlayer()) then return end

	self.DeathRagdoll = self.DeathRagdoll or false

	if self.DeathRagdoll then
		if self.DeathRagdoll:IsValid() then
			self.DeathRagdoll:Remove()
		end
	end

	local ply_pos = self:GetPos()
	local ply_ang = self:GetAngles()
	local ply_mdl = self:GetModel()
	local ply_skn = self:GetSkin()
	local ply_col = self:GetColor()
	local ply_mat = self:GetMaterial()
	
	local playerModelIsRagdoll = self:GetBoneCount() > 1

	local ent
	if playerModelIsRagdoll then
		ent = ents.Create("prop_ragdoll")
	else
		ent = ents.Create("prop_physics")
	end

	ent:SetPos(ply_pos)
	ent:SetAngles(ply_ang - Angle(ply_ang.p,0,0))
	ent:SetModel(ply_mdl)
	ent:SetSkin(ply_skn)
	ent:SetColor(ply_col)
	ent:SetMaterial(ply_mat)
	ent:SetCreator(self)
	for k, v in ipairs(self:GetBodyGroups()) do
		ent:SetBodygroup( v.id, self:GetBodygroup(v.id) )
	end
	ent:Spawn()
	
	local phys = ent:GetPhysicsObject()
	if phys:IsValid() then
		phys:SetMass(phys:GetMass())
	end
	
	self.DeathRagdoll = ent
	deathRagdolls[self] = ent
	
	if !ent:IsValid() then return end
	
	local plyvel = self:GetVelocity()

	if playerModelIsRagdoll then
		for i = 0, ent:GetPhysicsObjectCount() - 1 do
			local bone = ent:GetPhysicsObjectNum(i)
			
			if bone and bone:IsValid() then
				local bonepos, boneang = self:GetBonePosition(ent:TranslatePhysBoneToBone(i))
				
				bone:SetPos(bonepos)
				bone:SetAngles(boneang)
				bone:SetVelocity(plyvel)
			end
		end
	else
		phys:SetVelocity(plyvel)
	end

	ent.SetOwner(self)
	
	if self:IsOnFire() then ent:Ignite(math.Rand(6, 8), 0) end
	
	ent:SetCollisionGroup(COLLISION_GROUP_WEAPON)

	self:SpectateEntity(ent)
	self:Spectate(OBS_MODE_CHASE)
end


hook.Add("PlayerSpawn", "fh_delete_ragdolls", function( victim, inflictor, attacker )
	for k,v in ipairs(ents.FindByClass('prop_ragdoll')) do
		v:Remove()
	end
end)