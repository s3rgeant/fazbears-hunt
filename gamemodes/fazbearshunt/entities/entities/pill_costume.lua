AddCSLuaFile()
ENT.Base = "base_anim"
ENT.Type = "anim"
ENT.AutomaticFrameAdvance = true

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "PillForm")
    self:NetworkVar("Entity", 0, "PillUser")
    self:NetworkVar("Entity", 1, "PrevPillUser")
	
    self:NetworkVar("Float", 0, "ChargeTime")
    self:NetworkVar("Angle", 0, "ChargeAngs")
    self:NetworkVar("Float", 1, "CloakLeft")
	
    self:NetworkVar("Bool", false, "UseForceAngles")
    self:NetworkVar("Angle", 1, "ForceAngles")
	
    self:NetworkVar("Angle", 2, "LookAngles")
	
	self:NetworkVar( "Bool", false, "Frozen" )
	
	self:NetworkVar( "Float", 1, "NextAnimThink" )
end

local fh_pill_update_rate = CreateConVar( "fh_pill_update_rate", 0, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Increasing this will result in better performance with a lot of pill_costume running. (Animation errors might occure)" )

ENT.FadeOutLayers = {}
ENT.FadeInLayers = {}

function ENT:Initialize()
	self.formTable = pills.getPillTable(self:GetPillForm())
	local ply = self:GetPillUser()
	
	if CLIENT and not IsValid(ply) then
		ply = self:GetOwner()
	end
	
	if (not self.formTable or !IsValid(ply)) and SERVER then
		self:Remove()
		return
	end
	self.formTable.initMoveSpeed = table.Copy(self.formTable.moveSpeed)
	self.formTable.initJumpPower = self.formTable.jumpPower
	
	local scaleHull = 1
	if self.formTable.modelScale then
		scaleHull = self.formTable.modelScale
	end

	local hull = (self.formTable.hull or Vector(32, 32, 72)) / scaleHull
	
	local renderHull 
	if self.formTable.renderHull then
		renderHull = self.formTable.renderHull
	end
	
	local duckBy = (self.formTable.duckBy or (self.formTable.hull and 0 or 36)) / scaleHull
	ply:SetHull(-Vector(hull.x * .5, hull.y * .5, 0), Vector(hull.x * .5, hull.y * .5, hull.z))
	ply:SetHullDuck(-Vector(hull.x * .5, hull.y * .5, 0), Vector(hull.x * .5, hull.y * .5, hull.z - duckBy or 0))
	
	ply:SetMaterial("models/null")
	ply:DrawShadow(false)
		
	hook.Run("PillApply", ply, self)
	
	self.justSpawned = true
	
	if CLIENT then
		if renderHull then
			self:SetRenderBounds(-Vector(renderHull.x, renderHull.y, 0), Vector(renderHull.x, renderHull.y, renderHull.z))
		else
			ply:SetRenderBounds(-Vector(hull.x * .5, hull.y * .5, 0), Vector(hull.x * .5, hull.y * .5, hull.z + 25))
		end
		
		local speed = self.formTable.moveSpeed or {}
		ply:SetWalkSpeed(speed.walk or 200)
		ply:SetSlowWalkSpeed(speed.walk or 200)
		ply:SetRunSpeed(speed.run or speed.walk or 500)
		
		--local normal = self:GetUp()
		--local position = normal:Dot( self:GetPos() )
		--self:SetRenderClipPlaneEnabled( true )
		--self:SetRenderClipPlane( normal, position )
	end
	--self:UseClientSideAnimation(true)
	
	self:ResetAngle()
	if SERVER then
		self:SetModel("models/Combine_Helicopter/helicopter_bomb01.mdl")
		self:SetPos(ply:GetPos())
		self:SetRenderMode(RENDERMODE_NORMAL)
		self:SetParent(ply)
		self:SetIK(true)
		ply:StripWeapons()
		ply:RemoveAllAmmo()
	
		if self.formTable.flies then
			ply:SetMoveType(MOVETYPE_FLY)
		else
			ply:SetMoveType(MOVETYPE_WALK)
		end
		
		if self.formTable.viewmodel and self.formTable.viewmodel.weapon then
			ply:SetSuppressPickupNotices(true)
			ply:Give(self.formTable.viewmodel.weapon)
			ply:SelectWeapon(self.formTable.viewmodel.weapon)
			ply:SetSuppressPickupNotices(false)
			
			if self.formTable.viewmodel.skin then
				local wep = ply:GetActiveWeapon()
				if IsValid(wep) then
					ply:GetViewModel():SetSkin(self.formTable.viewmodel.skin or 0)
				end
			end
			
			if self.formTable.viewmodel.bodyGroup then
				local wep = ply:GetActiveWeapon()
				timer.Simple(0, function()
					if IsValid(wep) then
						local vmodel = ply:GetViewModel()
						vmodel:SetBodygroup( vmodel:FindBodygroupByName( self.formTable.viewmodel.bodyGroup ), 1 )
					end
				end)
			end
			
			if self.formTable.viewmodel.func then
				local wep = ply:GetActiveWeapon()
				if IsValid(wep) then
					self.formTable.viewmodel.func(wep, ply, self)
				end
			end
		else
			ply:DrawViewModel(false)
		end
		
		if self.formTable.collisionGroup then
			ply:SetCollisionGroup(self.formTable.collisionGroup)
		else
			ply:SetCollisionGroup(5)
		end
		self:CollisionRulesChanged()
	
		if ply:FlashlightIsOn() then
			ply:Flashlight(false)
		end
	
		ply:SetNotSolid(false)
		--ply:DrawWorldModel(false)
		local camOffset = self.formTable.camera and self.formTable.camera.offset or Vector(0, 0, 64)
		--clside this?
		ply:SetStepSize((self.formTable.stepSize or (hull.z / 4)) * scaleHull)
		ply:SetViewOffset(camOffset)
		ply:SetViewOffsetDucked(camOffset - Vector(0, 0, duckBy * scaleHull))
		local speed = self.formTable.moveSpeed or {}
		ply:SetWalkSpeed(speed.walk or 200)
		ply:SetSlowWalkSpeed(speed.walk or 200)
		ply:SetRunSpeed(speed.run or speed.walk or 500)
	
		if speed.ducked then
			ply:SetCrouchedWalkSpeed(speed.ducked / (speed.walk or 200))
		elseif duckBy == 0 then
			ply:SetCrouchedWalkSpeed(1)
		else
			ply:SetCrouchedWalkSpeed(.3)
		end
		
		if !speed.maxwalk then
			speed.maxwalk = 40
		end
	
		ply:SetJumpPower(self.formTable.jumpPower or 200)
		self.loopingSounds = {}
	
		if self.formTable.sounds then
			for k, v in pairs(self.formTable.sounds) do
				if string.sub(k, 1, 5) == "loop_" then
					self.loopingSounds[string.sub(k, 6)] = CreateSound(self, v)
				elseif string.sub(k, 1, 5) == "auto_" and isstring(v) then
					local func
	
					func = function()
						if IsValid(self) then
							local f = self.formTable.sounds[k .. "_func"]
							if not f then return end
							local play, time = f(ply, self)
	
							if play then
								self:PillSound(k)
							end
	
							timer.Simple(time, func)
						end
					end
	
					func()
				end
			end
	
			if self.loopingSounds.move then
				self:PillLoopSound("move")
			end
		end
		
		local bloodType = self.formTable.bloodType or BLOOD_COLOR_RED
		
		ply:SetBloodColor( bloodType )
	
		if self.formTable.health then
			ply:SetHealth(self.formTable.health)
			ply:SetMaxHealth(self.formTable.health)
		else
			ply:GodEnable()
		end
	
		ply:SetArmor(0)
		ply:DropToFloor(MASK_ALL)
	
		if self.formTable.loadout then
			for _, v in pairs(self.formTable.loadout) do
				ply:Give(v)
			end
		end
	
		if self.formTable.ammo then
			for k, v in pairs(self.formTable.ammo) do
				ply:SetAmmo(v, k)
			end
		end
	
		local model = self.formTable.model
		local skin = self.formTable.skin
		local attachments = self.formTable.attachments
		local bodyGroups = self.formTable.bodyGroups
	
		if self.formTable.options then
			local options = self.formTable.options()
	
			if self.formTable.option and options[self.formTable.option] then
				local pickedOption = options[self.formTable.option]
	
				if pickedOption.model then
					model = pickedOption.model
				end
	
				if pickedOption.skin then
					skin = pickedOption.skin
				end
	
				if pickedOption.attachments then
					attachments = pickedOption.attachments
				end
	
				if pickedOption.bodyGroups then
					bodyGroups = pickedOption.bodyGroups
				end
			else
				local pickedOption = table.Random(options)
	
				if not model then
					model = pickedOption.model
				end
	
				if not skin then
					skin = pickedOption.skin
				end
	
				if not attachments then
					attachments = pickedOption.attachments
				end
	
				if not bodyGroups then
					bodyGroups = pickedOption.bodyGroups
				end
			end
		end
	
		self:SetModel(model or "models/Humans/corpse1.mdl")
		FixSetModel()
		ply:SetModel(model or "models/Humans/corpse1.mdl")
	
		if skin then
			self:SetSkin(skin)
		end
	
		if self.formTable.visColor then
			self:SetColor(self.formTable.visColor)
		elseif self.formTable.visColorRandom then
			self:SetColor(HSVToColor(math.Rand(0, 360), 1, 1))
		end
	
		if self.formTable.visMat then
			self:SetMaterial(self.formTable.visMat)
		end
	
		if bodyGroups and istable(bodyGroups) then
			for k, v in pairs(bodyGroups) do
				if isnumber(k) then
					self:SetBodygroup(k, v)
				elseif isstring(k) then
					local id = self:FindBodygroupByName(k)
					if id >= 0 then
						self:SetBodygroup(id, v)
					end
				elseif isnumber(v) then
					self:SetBodygroup(v, 1)
				end
			end
		end
	
		if self.formTable.boneMorphs then
			for k, v in pairs(self.formTable.boneMorphs) do
				local b = self:LookupBone(k)
	
				if b then
					if v.pos then
						self:ManipulateBonePosition(b, v.pos)
					end
	
					if v.rot then
						self:ManipulateBoneAngles(b, v.rot)
					end
	
					if v.scale then
						self:ManipulateBoneScale(b, v.scale)
					end
				end
			end
		end
	
		if self.formTable.cloak then
			self:SetCloakLeft(self.formTable.cloak.max)
		end
		
		if self.formTable.startFunction then
			self.formTable.startFunction(ply, self)
		end
		
		if self.formTable.initialize then
			self.formTable.initialize(ply, self)
		end
	else
		if self.formTable.initialize_client then
			self.formTable.initialize_client(ply, self)
		end
	end
	
	if self.formTable.modelScale then
		self:SetModelScale(self.formTable.modelScale, 0)
	end
	ply:SetModelScale(self.formTable.modelScale or 1, 0)
	
	hook.Run("PillCreated", ply, self)
end

function ENT:OnRemove()
	local ply = self:GetPillUser()
	
	-- compatibility
	if self.formTable.onRemove then
		if CLIENT and ply == LocalPlayer() then
			self.formTable.onRemove(ply, self)
		end
	end
	
	if self.formTable.restore then
		if CLIENT and ply == LocalPlayer() then
			self.formTable.restore(ply, self, self.formTable)
		end
	end
	
	if SERVER then
		self:PillLoopStopAll()
	end
	
	if CLIENT and IsValid(ply) then
		ply:SetModelScale(1)
	end
	
	local newType, newName = pills.unmapEnt(ply, self)
	
	if newType ~= "ply" and IsValid(ply) then
		ply:ResetHull()
	end
	hook.Run("PillRestore", ply, self)
end

function ENT:Think()
	local ply = self:GetPillUser()
	local ct = CurTime()
	if not IsValid(self) or not IsValid(ply) then 
		self:NextThink(ct + fh_pill_update_rate:GetFloat())
		return true
	end
	
	local vel = ply:GetVelocity():Length()
	
	if self.formTable.preThink then
		self.formTable.preThink(ply, self, vel)
	end
	
	if SERVER then
		local anims = self.formTable.anims["default"] or {}
	
		if not self.anim or not anims[self.anim] then
			self.animFreeze, self.ignoreFreeze, self.animStart = nil, nil, nil
		end
	
		if not self.animFreeze and self:GetFrozen() then
			self:ResetSpeed(ply)
		end
	
		if self.anim == "jump" and ply:OnGround() then
			self.anim, self.animCycle = nil, nil
		end
		
		local anim, overrideRate
		
		if ct > self:GetNextAnimThink() then
			if self.anim and anims[self.anim] then
				anim, overrideRate = anims[self.anim], anims[self.anim .. "_rate"] or 1
				local cycle = self:GetCycle()
	
				if not self.animStart then
					local wrongSeq = (cycle == 1 or (self.animCycle and self.animCycle > cycle) 
									or string.lower(anim) ~= string.lower(self:GetSequenceName(self:GetSequence())))
					if wrongSeq then
						if not self.animLoop and not anims[self.anim .. "_loop"] then
							if self.formTable.animStopped then
								self.formTable.animStopped(ply, self, anim)
							end
							self.anim, self.animCycle, self.animFreeze, self.ignoreFreeze = nil, nil, nil, nil
						elseif anims[self.anim .. "_loop"] then
							anim = anims[self.anim .. "_loop"]
						end
					else
						self.animCycle = cycle
					end
				end
			elseif self.burrowed then
				anim = anims["burrow_loop"]
			elseif ply:GetMoveType() == MOVETYPE_NOCLIP then
				anim = anims["noclip"] or anims["glide"] or anims["idle"]
			elseif ply:WaterLevel() > 2 then
				anim = anims["swim"] or anims["glide"] or anims["idle"]
			elseif ply:OnGround() then
				if ply:Crouching() then
					anim = (vel > ply:GetCrouchedWalkSpeed() / 4) 
						and (anims["crouch_walk"] or anims["crouch"] or anims["walk"]) 
						or (anims["crouch"] or anims["idle"])
				else
					if vel > (ply:GetWalkSpeed() + ply:GetRunSpeed()) / 2 and ply:GetWalkSpeed() ~= ply:GetRunSpeed() then
						anim = anims["run"] or anims["walk"] or anims["idle"]
					elseif vel > 20 then
						anim = anims["walk"] or anims["idle"]
					else
						anim = anims["idle"]
					end
				end
			else
				anim = anims["glide"] or anims["idle"]
			end
	
			if anim == anims["idle"] or anim == anims["crouch"] then
				overrideRate = 1
			end
			self:PlayAnim(anim)
			
			self:SetNextAnimThink(ct + 0.1)
		end
		
		self.justSpawned = false
		
		local speedCap = self.formTable.anims.speedCap
		if speedCap then
			if speedCap.run and anim == anims["run"] then
				if vel > speedCap.run then
					self:SetPlaybackRate(math.Clamp(vel / speedCap.run, -4, 12))
				else
					self:SetPlaybackRate(1)
				end
			elseif speedCap.walk and anim == anims["walk"] then
				self:SetPlaybackRate(math.Clamp(vel / speedCap.walk, -4, 12))
			elseif speedCap.ducked and anim == anims["crouch_walk"] and vel > speedCap.ducked then
				self:SetPlaybackRate(math.Clamp(vel / speedCap.ducked, -4, 12))
			end
		end
	
		if not ply:IsOnGround() and ply:WaterLevel() == 0 and self.formTable.glideThink then
			self.formTable.glideThink(ply, self)
		end
		
		if self.formTable.movePoseMode == "xy" then
			if not overrideRate then
				local velocity, pillspeed = ply:GetVelocity(), self.formTable.moveSpeed or {}
				local plyAngs = ply:GetAngles()
				plyAngs.p = 0
				local fwd, right = plyAngs:Forward(), plyAngs:Right()
	
				local moveX = fwd:Dot(velocity)
				local moveY = right:Dot(velocity)
	
				local maxSpeed = math.max(pillspeed.maxwalk or 80, ply:GetWalkSpeed())
					--maxSpeed = ply:GetRunSpeed()
				if ply:Crouching() then maxSpeed = maxSpeed * 0.5 end
	
				moveX = moveX / maxSpeed
				moveY = moveY / maxSpeed
	
				-- фикс диагонали (хз у нейронеки спросил, какие то цифры ибанные написало)
				if math.abs(moveX) > 0.01 and math.abs(moveY) > 0.01 then
					moveX = moveX * 1.4142
					moveY = moveY * 1.4142
				end
	
				moveX = math.Clamp(moveX, -1, 1)
				moveY = math.Clamp(moveY, -1, 1)
	
				local ratio = math.Clamp(velocity:Length2D() / maxSpeed, 0, 1)
				
				local targetX = moveX * ratio
				local targetY = moveY * ratio
				
				local prevX = self:GetPoseParameter("move_x")
				local prevY = self:GetPoseParameter("move_y")
				
				local ft = FrameTime()
				local ftr
				
				if not ply:OnGround() then
					ftr = ft * 8
				else
					ftr = .5
				end
					
				targetX = Lerp(ftr, prevX, targetX)
				targetY = Lerp(ftr, prevY, targetY)
	
				self:SetPoseParameter("move_x", targetX)
				self:SetPoseParameter("move_y", targetY)
			else
				self:SetPoseParameter("move_x", 0)
				self:SetPoseParameter("move_y", 0)
			end
		end
		
		if not table.IsEmpty(self.FadeOutLayers) then
			for id, data in pairs(self.FadeOutLayers) do
			
				local start = data.starttime
				local outTime = data.endtime
				local duration = data.duration
				local ease = data.ease and math.ease[data.ease] or nil
				
				local scale = data.initialweight or 1
				
				local w = (ct - outTime) / duration
				w = w*-1
				w = math.Clamp(w, 0, 1 * scale)
				
				if ease then w = Lerp(ease(w), 0, 1) end
				
				self:SetLayerWeight(id, w)
				
				if w <= 0 then
					self.FadeOutLayers[id] = nil
				end
			end
		end
		
		if not table.IsEmpty(self.FadeInLayers) then
			for id, data in pairs(self.FadeInLayers) do
			
				local start = data.starttime
				local outTime = data.endtime
				local duration = data.duration
				local ease = data.ease and math.ease[data.ease] or nil
				
				local w = (ct - outTime) / duration + 1
				w = math.Clamp(w, 0, 1)
				
				if ease then w = Lerp(ease(w), 0, 1) end
				
				self:SetLayerWeight(id, w)
				
				if w >= 1 then
					self.FadeInLayers[id] = nil
				end
			end
		end
	end
	
	self:SetPoseParameter("move_yaw", ply:GetPoseParameter("move_yaw"))
	
	if self.formTable.aim and CLIENT then
		local eyeAngles = ply:EyeAngles()
		
		if vrmod and vrmod.IsPlayerInVR(ply) then eyeAngles = vrmod.GetHMDAng( ply ) end
		
		if self.formTable.aim.xPose then
			local yaw = math.AngleDifference(eyeAngles.y, self:GetAngles().y)
			
			if self.formTable.aim.xInvert then yaw = -yaw end
			
			self:SetPoseParameter(self.formTable.aim.xPose, yaw)
		end
		if self.formTable.aim.yPose then
			local pitch = math.AngleDifference(eyeAngles.p, self:GetAngles().p)
			if self.formTable.aim.yInvert then pitch = -pitch end
			self:SetPoseParameter(self.formTable.aim.yPose, pitch)
		end
	end
	
	if SERVER then
		self:SetPos(ply:GetPos())
	elseif CLIENT then
		if self:GetParent() == ply then
			self:SetRenderOrigin(ply:GetPos())
		else
			self:SetRenderOrigin(nil)
		end
	end
	
	local usef_angs = self:GetUseForceAngles()
	local angs = usef_angs and self:GetForceAngles() or (SERVER and ply:GetAngles() or ply:EyeAngles())
	if not usef_angs then angs.p = 0 end
	if SERVER then 
		self:SetAngles(angs)
		self:SetLookAngles(angs)
	else 
		if (vel < 5 or !ply:OnGround()) and !self.formTable.noLookLerp then
			self:SetRenderAngles(LerpAngle(FrameTime() * 25, self:GetAngles(), self:GetLookAngles() ))
		elseif !self.formTable.noLookLerp or self.formTable.noLookLerp and vel > 5 or usef_angs then
			self:SetRenderAngles(angs)
		end
	end
	
	if self.formTable.postThink then
		self.formTable.postThink(ply, self, vel)
	end
	
	self:NextThink(ct + fh_pill_update_rate:GetFloat())
	return true
end

function ENT:Get(name, default)
	if !IsValid(self) or !self.formTable then return default or nil end
	
	local get = self.formTable[name]
	
	if get then return get end
	
	return default or nil
end

function ENT:Func(name, ...)
	if !IsValid(self) or !self.formTable then return nil end
	
	local get = self.formTable[name]
	
	if get then return get(...) end
	
	return nil
end

if SERVER then
	function ENT:DetachPlayer()
		local ply = self:GetPillUser()
	
		self:SetPrevPillUser(ply)
		self:SetPillUser(nil)
		self:SetParent()
		
		ply.lastFhMappedEnt = self
		
		pills.unmapEnt(ply, self)
	end
	function ENT:AttachPlayer(ply)
		ply = ply or self:GetPrevPillUser()
	
		self:SetPillUser(ply)
		self:SetParent(ply)
		self:SetPrevPillUser(nil)
		
		ply.lastFhMappedEnt = nil
		
		pills.mapEnt(ply, self)
	end
	
	function ENT:UpdateTransmitState() 
		return TRANSMIT_ALWAYS
	end

	function ENT:DoKeyPress(ply, key)
		if self.animFreeze and !self.ignoreFreeze then return end
	
		if self:GetChargeTime() ~= 0 then
			self:SetChargeTime(0)
			self:PillLoopStop("charge")
	
			return
		end
	
		if key == IN_ATTACK and self.formTable.attack and self.formTable.attack.mode == "trigger" and !self.ignoreFreeze then
			self.formTable.attack.func(ply, self, self.formTable.attack)
		end
	
		if key == IN_ATTACK2 and self.formTable.attack2 and self.formTable.attack2.mode == "trigger" then
			self.formTable.attack2.func(ply, self, self.formTable.attack2)
		end
	
		if key == IN_RELOAD and self.formTable.reload then
			self.formTable.reload(ply, self)
		end
	
		if key == IN_DUCK then
			if self.formTable.canBurrow then
				if not self.burrowed then
					local trace = util.QuickTrace(ply:GetPos(), Vector(0, 0, -1), ply)
	
					if trace.Hit and (trace.MatType == MAT_DIRT or trace.MatType == MAT_SAND or trace.MatType == MAT_GRASS) then
						self:PillAnim("burrow_in")
						self:PillSound("burrow_in")
						ply:SetLocalVelocity(Vector(0, 0, 0))
						ply:SetMoveType(MOVETYPE_NONE)
						ply:SetNotSolid(true)
						self.burrowed = true
						self:DrawShadow(false)
					end
				else
					self:PillAnim("burrow_out")
					self:PillSound("burrow_out")
					ply:SetMoveType(MOVETYPE_WALK)
					ply:SetNotSolid(false)
					self.burrowed = nil
					self:DrawShadow(true)
				end
			end
		end
	end
	
	function ENT:DoJump()
		if self.formTable.jump then
			self.formTable.jump(self:GetPillUser(), self)
		end
	end
	
	function ENT:PillDie()
		local ply = self:GetPillUser() or self:GetPrevPillUser()
	
		if self.formTable.die then
			self.formTable.die(ply, self)
		end
	
		self:PillSound("die")
		
		pills.restore(ply:Nick(), true)
	end
	
	function ENT:PlayAnim(anim)
		local ply = self:GetPillUser()
		
		if IsValid(ply) and anim and (self:GetSequence() ~= self:LookupSequence(anim) or self.animStart or (self.formTable.autoRestartAnims and self:GetCycle() == 1)) or self.justSpawned then
			ply:SetSequence(ply:LookupSequence(anim))
			
			self:ResetSequence(self:LookupSequence(anim))
			self:SetCycle(self.forceCycle or 0)
			self.forceCycle = nil
			self.animCycle = 0
		end
		self.animStart = nil
	end
	
	function ENT:PillAnim(name, freeze, cycle)
		self.anim = name
		self.animStart = true
		self.animFreeze = freeze
		self.animLoop = false
		self.forceCycle = cycle
		
		if freeze then
			local ply = self:GetPillUser()
		
			if IsValid(ply) then
				ply:SetWalkSpeed(5)
				ply:SetRunSpeed(5)
				ply:SetSlowWalkSpeed(5)
				ply:SetJumpPower(0)
			end
			self:SetFrozen(true)
		end
		
		self:SetNextAnimThink(0)
	end
	
	function ENT:PillAnimTick(name)
	end
	
	function ENT:PillGesture(name, priority, rate, blendin, out, start, loop)
		local ply = self:GetPillUser()
		if not IsValid(ply) then return end
		local anims = self.formTable.anims.gestures or {}
		local gesture = anims[name]
		if !gesture then return end
		
		local seq = self:LookupSequence(gesture)
		local id = nil
		
		if !self.usedLayers then self.usedLayers = {} end
		
		if self.usedLayers[seq] then
			id = self.usedLayers[seq]
		end
		if !id then
			id = self:AddLayeredSequence(seq, priority or 1)
			self.usedLayers[seq] = id
		else
			self:SetLayerSequence(id, seq)
		end
		
		local dur = self:GetLayerDuration( id )
		
		self:SetLayerPriority(id, priority or 1)
		self:SetLayerPlaybackRate(id, (rate or 1))
		self:SetLayerCycle(id, start or 0)
		
		self:SetLayerWeight(id, 1)
		self:SetLayerBlendIn(id, blendin or 0.1)
		self:SetLayerBlendOut(id, out or 0.1)
		self:SetLayerLooping(id, loop or false)
		return dur
	end
	
	-- для совместимости с сторонними пилл паками
	function ENT:GetPuppet()
		return self
	end
	
	function ENT:PillStopGesture(name, fadeout, ease)
		local ply = self:GetPillUser()
		if not IsValid(ply) then return end
		local anims = self.formTable.anims['gestures'] or {}
		local gesture = anims[name]
		
		if !gesture then return end
		
		local seq = self:LookupSequence(gesture)
		local id = nil
		
		if !self.usedLayers then return end -- no layer to stop
		
		if self.usedLayers[seq] then
			id = self.usedLayers[seq]
		end
		
		if !id then return end
		
		--if self:GetLayerWeight(id) <= 0 then return end
		-- Если убрать комментарий выше, то движок не сможет выключать слои в тот же тик с включением
		
		if fadeout and isnumber(fadeout) and fadeout > 0 then
			local ct = CurTime()
			
			self:SetLayerBlendIn(id, 0)
			self:SetLayerBlendOut(id, 0)
			
			self.FadeInLayers[id] = nil
			
			local curWeight = self:GetLayerWeight(id)
			if curWeight >= 1 then curWeight = nil end
			
			self.FadeOutLayers[id] = {
				starttime = ct,
				endtime = ct + fadeout,
				duration = fadeout,
				ease = ease,
				initialweight = curWeight,
			}
		else
			self.FadeOutLayers[id] = nil
			self.FadeInLayers[id] = nil
		
			self:SetLayerPlaybackRate(id, 0.5)
			self:SetLayerCycle(id, 0)
			
			self:SetLayerWeight(id, 0)
			self:SetLayerBlendIn(id, 0)
			self:SetLayerBlendOut(id, 0)
		end
	end
	
	function ENT:PillGestureSwap(from, to, dur, dur2, ease, ease2)
		local ply = self:GetPillUser()
		if not IsValid(ply) then return end
		
		if not dur then return end
		if not dur2 then dur2 = dur end
		
		local anims = self.formTable.anims['gestures'] or {}
		
		local gesture_from = anims[from]
		local gesture_to = anims[to]
		
		if !gesture_from or !gesture_to then return end
		
		local seq_from = self:LookupSequence(gesture_from)
		local seq_to = self:LookupSequence(gesture_to)
		local id = nil
		local id2 = nil
		
		if !self.usedLayers then return end -- there are no layers to swap from - to
		
		if self.usedLayers[seq_from] then id = self.usedLayers[seq_from] end
		if self.usedLayers[seq_to] then id2 = self.usedLayers[seq_to] end
		
		if !id or !id2 then return end
		
		if self:GetLayerWeight(id) <= 0 then return end
		
		local ct = CurTime()
		
		self:SetLayerBlendIn(id, 0)
		self:SetLayerBlendOut(id, 0)
		
		self.FadeInLayers[id] = nil
		self.FadeOutLayers[id] = {
			starttime = ct,
			endtime = ct + dur,
			duration = dur,
			ease = ease,
		}
		
		self:SetLayerBlendIn(id2, 0)
		self:SetLayerBlendOut(id2, 0)
		
		self.FadeOutLayers[id2] = nil
		self.FadeInLayers[id2] = {
			starttime = ct,
			endtime = ct + dur2,
			duration = dur2,
			ease = ease2,
		}
	end
	
	function ENT:PillChargeAttack()
		if not self:GetPillUser():OnGround() or self.burrowed then return end
		self:PillAnim("charge_start", true)
		self:PillSound("charge_start")
	
		local function doStart()
			if not IsValid(self) then return end
			self:SetChargeTime(CurTime())
			local angs = self:GetPillUser():EyeAngles()
			angs.p = 0
			self:SetChargeAngs(angs)
			self:PillLoopSound("charge")
		end
	
		if self.formTable.charge.delay then
			timer.Simple(self.formTable.charge.delay, doStart)
		else
			doStart()
		end
	end
else
    function ENT:GetPillHealth()
        return self:GetPillUser():Health()
    end
end
	
function ENT:HandleAnimEvent( event, eventTime, cycle, type, options )
	if self.formTable.animEvent then
		-- gentoi bullshit compatibility :pray:
		local eventName = util.GetAnimEventNameByID( event )
		if eventName:len() <= 0 then eventName = "Step" end
		
		self.formTable.animEvent(self:GetPillUser(), self, eventName, eventTime, cycle, type, options)
		return true
	end
end

--The "bulk" parameter should only be used if you plan to play a ton of sounds in quick succession.
function ENT:PillSound(name, bulk)
	if not self.formTable.sounds then return end
	local s = self.formTable.sounds[name]
	
	local ply = self:GetPillUser()
	
	if (istable(s)) then
		s = table.Random(s)
	end
	
	if isstring(s) and IsValid(ply) then
		if bulk then
			sound.Play(s, self:GetPos(), self.formTable.sounds[name .. "_level"] or (name == "step" and 75 or 75), self.formTable.sounds[name .. "_pitch"] or 100, 1)
		else
			local rf = RecipientFilter()
			rf:AddAllPlayers()
			
			local recipients = hook.Run("PillSound", ply or self:GetParent(), self, name)
			if recipients then
				rf:RemovePlayers(recipients)
			end
			
			self:GetPillUser():EmitSound(s, self.formTable.sounds[name .. "_level"] or 75, self.formTable.sounds[name .. "_pitch"] or 100, 1, CHAN_AUTO, 0, 0, rf)
		end
	
		return true
	end
end

function ENT:PillLoopSound(name, volume, pitch)
	if not self.loopingSounds[name] then return end
	local s = self.loopingSounds[name]
	
	if s:IsPlaying() then
		if volume then
			s:ChangeVolume(volume)
		end
	
		if pitch then
			s:ChangePitch(pitch, .1)
		end
	else
		if volume or pitch then
			s:PlayEx(volume or 1, pitch or 100)
		else
			s:Play()
		end
	end
end

function ENT:PillLoopStop(name)
	if not self.loopingSounds[name] then return end
	local s = self.loopingSounds[name]
	s:FadeOut(.1)
end

function ENT:PillLoopStopAll()
    if self.loopingSounds then
        for _, v in pairs(self.loopingSounds) do
            v:Stop()
        end
    end
end

function ENT:DoKeyPressShared(ply, key)
	if self.animFreeze and !self.ignoreFreeze then return end

	if key == IN_ATTACK and self.formTable.attack_sh and self.formTable.attack_sh.mode == "trigger" and !self.ignoreFreeze then
		self.formTable.attack_sh.func(ply, self, self.formTable.attack_sh)
	end

	if key == IN_ATTACK2 and self.formTable.attack2_sh and self.formTable.attack2_sh.mode == "trigger" then
		self.formTable.attack2_sh.func(ply, self, self.formTable.attack2_sh)
	end

	if key == IN_RELOAD and self.formTable.reload_sh then
		self.formTable.reload_sh(ply, self)
	end
end

function ENT:DoKeyPressShared_NoLagCompensation(ply, key)
	if self.animFreeze and !self.ignoreFreeze then return end

	if key == IN_ATTACK and self.formTable.attack_sh_nolc and self.formTable.attack_sh_nolc.mode == "trigger" and !self.ignoreFreeze then
		self.formTable.attack_sh_nolc.func(ply, self, self.formTable.attack_sh_nolc)
	end

	if key == IN_ATTACK2 and self.formTable.attack2_sh_nolc and self.formTable.attack2_sh_nolc.mode == "trigger" then
		self.formTable.attack2_sh_nolc.func(ply, self, self.formTable.attack2_sh_nolc)
	end

	if key == IN_RELOAD and self.formTable.reload_sh_nolc then
		self.formTable.reload_sh_nolc(ply, self)
	end
end

function ENT:ToggleCloak()
    local ply = self:GetPillUser()

    if self.iscloaked then
        self.iscloaked = nil
        self:PillSound("uncloak")
    else
        local cloakleft = self:GetCloakLeft()

        if cloakleft > 0 or cloakleft == -1 then
            self.iscloaked = true
            self:PillSound("cloak")
        end
    end
end

function ENT:SetSpeed(walk, run, duck, jump)
    local ply = self:GetPillUser()
	
	local speed = self.formTable.moveSpeed
	
	speed.walk = walk
	speed.run = run
	speed.ducked = duck / (walk or 200)
    self.formTable.jumpPower = jump
	
    ply:SetWalkSpeed(walk)
    ply:SetRunSpeed(run)
    ply:SetCrouchedWalkSpeed(duck / (walk or 200))
	ply:SetJumpPower(jump)
end

function ENT:ResetSpeed()
    local ply = self:GetPillUser()

    local speed = self.formTable.moveSpeed or {}
    ply:SetWalkSpeed(speed.walk or 200)
    ply:SetRunSpeed(speed.run or speed.walk or 500)
	ply:SetJumpPower(self.formTable.jumpPower or 200)
	ply:SetSlowWalkSpeed(speed.walk or 200)
    self:SetFrozen(nil)
end

function ENT:ReplaceAnimation(old, new)
	if self.formTable.anims['default'] ~= nil then
		self.formTable.anims['default'][old] = new
	end
end

function ENT:ResetAngle()
	if SERVER then return end
	
	local ply = self:GetPillUser()
	if CLIENT and not IsValid(ply) then
		ply = self:GetOwner()
	end
	
	if IsValid(self) then
		local angs=ply:EyeAngles()
		angs.p=0
		
		self:SetRenderAngles(angs)
	
		self:DrawModel()
	end
end

function ENT:OnRestore()
	local player = self:GetPillUser()
	
	if IsValid(player) then
		pills.apply(player:Nick(), self.formTable.name, true)
	end
end

function ENT:GetPillName()
	return self.formTable.name
end

function ENT:SetDefaultSpeed()
    local ply = self:GetPillUser()
	
	self.formTable.moveSpeed = table.Copy(self.formTable.initMoveSpeed)
	self.formTable.jumpPower = self.formTable.initJumpPower
	
	local speed = self.formTable.moveSpeed
	local jump = self.formTable.jumpPower
	
    ply:SetWalkSpeed(speed.walk)
    ply:SetRunSpeed(speed.run)
    ply:SetCrouchedWalkSpeed(speed.ducked / (speed.walk or 200))
	ply:SetJumpPower(jump)
end

if SERVER then return end

ENT.IsDrawn = true

function ENT:Draw()
	local ply = self:GetPillUser()
	
	if not IsValid(ply) then
		self:DrawModel()
		return
	end
	
	local myself = LocalPlayer()
	
	if ply == myself and vrmod and vrmod.IsPlayerInVR( myself ) then
		self.IsDrawn = false
		self:DestroyShadow()
		self:DrawShadow(false)
		return
	end
	
	--self:FrameAdvance()
	ply:RemoveAllDecals()
	
	if self:GetNoDraw() then
		self.IsDrawn = false
		self:DestroyShadow()
		self:DrawShadow(false)
	end
	
    local drawHook = hook.Run("ForceDrawPill", ply, self)

	if drawHook == true then
		self:DrawModel()
		self.IsDrawn = true
		return
    elseif drawHook == false then
		self.IsDrawn = false
		self:DestroyShadow()
		self:DrawShadow(false)
		return
	end
	
	local rendertarget = render.GetRenderTarget()
	local rtargetname = rendertarget ~= nil and rendertarget:GetName() or ""
	
	if ply == myself:GetObserverTarget() 
	and myself:GetViewEntity() == myself
	and myself:GetObserverMode() == OBS_MODE_IN_EYE
	and !ply:ShouldDrawLocalPlayer() then
		return
	end
	
	if ply == myself
	and ply:GetViewEntity() == ply
	and !pills.convars.cl_thirdperson:GetBool() and CurTime() >= myself:GetNW2Float("fh_pill_thirdperson")
	and !ply:ShouldDrawLocalPlayer() then
		self.IsDrawn = false
		self:DestroyShadow()
		self:DrawShadow(false)
		return
	end

    local invisible = self:GetMaterial() == "models/null"

    if invisible then
		self:DestroyShadow()
		self:DrawShadow(false)
    end

	self:DrawModel()
	self.IsDrawn = true
	
	if ply == myself and not invisible then
		self:DrawShadow(true)
	end
end

function ENT:DrawTranslucent()
    self:Draw()
end