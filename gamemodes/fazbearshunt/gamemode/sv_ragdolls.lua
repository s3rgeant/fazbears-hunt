local meta = FindMetaTable("Player")

if not meta then return end

function meta:CreateRagdoll()
	if !(self || self:IsValid() || self:IsPlayer()) then return end
	
	if hook.Run("ShouldSpawnRagdoll", self) == false then return end

	self.DeathRagdoll = self.DeathRagdoll or false
	
	if self._suppressragdollspawn then
		self._suppressragdollspawn = nil
		return
	end

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
	ent:SetOwner(self)
	for k, v in ipairs(self:GetBodyGroups()) do
		ent:SetBodygroup( v.id, self:GetBodygroup(v.id) )
	end
	ent:Spawn()
	
	local phys = ent:GetPhysicsObject()
	if phys:IsValid() then
		phys:SetMass(12.775918006897)
	end
	
	self.DeathRagdoll = ent
	
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
		
		local ply_ragcol = self:GetPlayerColor()
		ent.RagColor = Vector(ply_ragcol.r, ply_ragcol.g, ply_ragcol.b)
		
		ent.GetPlayerColor = function() return Vector(ply_ragcol.r, ply_ragcol.g, ply_ragcol.b) end
	else
		phys:SetVelocity(plyvel)
	end
	
	if self:IsOnFire() then ent:Ignite(math.Rand(6, 8), 0) end
	
	ent:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	ent.ShouldNotCollide = function(ent, ent2)
		if ent:GetClass() == ent2:GetClass() then return true end
		if ent2:IsPlayer() then return true end
	end
	
	ent:SetCustomCollisionCheck( true )

	self:SpectateEntity(ent)
	self:Spectate(OBS_MODE_CHASE)
	
	hook.Run("fh_createragdoll", self, ent)
end

function meta:SuppressRagdollSpawn(bool)
	self._suppressragdollspawn = bool or true
end