AddCSLuaFile()
ENT.Base = "base_anim"
ENT.Type = "anim"
ENT.AutomaticFrameAdvance = true

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "PillForm")
    self:NetworkVar("Entity", 0, "PillUser")
    self:NetworkVar("Float", 0, "ChargeTime")
    self:NetworkVar("Angle", 0, "ChargeAngs")
    self:NetworkVar("Bool", false, "UseForceAngles")
    self:NetworkVar("Angle", nil, "ForceAngles")
    self:NetworkVar("Float", 1, "CloakLeft")
	self:NetworkVar( "Bool", false, "Frozen" )
end

local fh_pill_update_rate = CreateConVar( "fh_pill_update_rate", 0, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Increasing this will result in better performance with a lot of pill_costume running. (Animation errors might occure)" )

function ENT:Initialize()
	self.usedLayers = {}
    self.formTable = pills.getPillTable(self:GetPillForm())
    local ply = self:GetPillUser()

    if not self.formTable or !IsValid(ply) then
        self:Remove()

        return
    end
	self.formTable.initMoveSpeed = table.Copy(self.formTable.moveSpeed)
	self.formTable.initJumpPower = self.formTable.jumpPower

    local hull = self.formTable.hull or Vector(32, 32, 72)
    local duckBy = self.formTable.duckBy or (self.formTable.hull and 0 or 36)
    ply:SetHull(-Vector(hull.x / 2, hull.y / 2, 0), Vector(hull.x / 2, hull.y / 2, hull.z))
    ply:SetHullDuck(-Vector(hull.x / 2, hull.y / 2, 0), Vector(hull.x / 2, hull.y / 2, hull.z - duckBy or 0))
	ply:SetMaterial("models/null")
	ply:DrawShadow(false)
    --Do this so weapon equips are not blocked
    pills.mapEnt(ply, nil)
		
	hook.Run("PillApply", ply, self)
	
	if CLIENT then
		ply:SetRenderBounds(-Vector(hull.x / 2, hull.y / 2, 0), Vector(hull.x / 2, hull.y / 2, hull.z + 25))
	end

	self:ResetAngle()
    if SERVER then
        self:SetModel("models/Combine_Helicopter/helicopter_bomb01.mdl")
        self:SetPos(ply:GetPos())
        self:SetParent(ply)
		self:SetRenderMode(RENDERMODE_NORMAL)
		self:SetIK(true)
        //self:DrawShadow(false)
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
			
			if self.formTable.viewmodel.func then
				local wep = ply:GetActiveWeapon()
				if IsValid(wep) then
					self.formTable.viewmodel.func(wep)
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

        if ply:FlashlightIsOn() then
            ply:Flashlight(false)
        end

        ply:SetNotSolid(false)
        --ply:DrawWorldModel(false)
        local camOffset = self.formTable.camera and self.formTable.camera.offset or Vector(0, 0, 64)
        --clside this?
        ply:SetStepSize(self.formTable.stepSize or (hull.z / 4))
        ply:SetViewOffset(camOffset)
        ply:SetViewOffsetDucked(camOffset - Vector(0, 0, duckBy))
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
			speed.maxwalk = speed.walk or 200
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
                            local play, time = f(self:GetPillUser(), self)

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
		
		if self.formTable.bloodType then
			self:GetPillUser():SetBloodColor( self.formTable.bloodType )
		end

        if self.formTable.health then
            self:GetPillUser():SetHealth(self.formTable.health)
            self:GetPillUser():SetMaxHealth(self.formTable.health)
        else
            self:GetPillUser():GodEnable()
        end

        ply:SetArmor(0)
        ply:DropToFloor()

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

        if bodyGroups then
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

        if self.formTable.modelScale then
            self:SetModelScale(self.formTable.modelScale, 0)
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
    end

    pills.mapEnt(ply, self)
	
	hook.Run("PillCreated", ply, self)
end


function ENT:OnRemove()
    local ply = self:GetPillUser()

    -- compatibility
    if self.formTable.onRemove then
        self.formTable.onRemove(self, self.formTable)
    end

    if SERVER then
        self:PillLoopStopAll()
	
		if self.formTable.restore then
			self.formTable.restore(ply, self, self.formTable)
		end
    end

    local newType = pills.unmapEnt(self:GetPillUser(), self)

    if newType ~= "ply" and IsValid(ply) then
        ply:ResetHull()

		hook.Run("PillRestore", ply, self)
    end
end

function ENT:Think()
    local ply = self:GetPillUser()
    if not IsValid(self) or not IsValid(ply) then return end

    local vel = ply:GetVelocity():Length()

    if SERVER then
        local anims = table.Copy(self.formTable.anims.default or {})
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) then
            table.Merge(anims, self.formTable.anims[wep:GetHoldType()] or {})
        elseif self.forceAnimSet then
            table.Merge(anims, self.formTable.anims[self.forceAnimSet] or {})
        end

        if not self.anim or not anims[self.anim] then
            self.animFreeze, self.ignoreFreeze, self.animStart = nil, nil, nil
        end

        if self.animFreeze and not self:GetFrozen() then
            ply:SetWalkSpeed(5)
            ply:SetRunSpeed(5)
            ply:SetSlowWalkSpeed(5)
            ply:SetJumpPower(0)
            self:SetFrozen(true)
        elseif not self.animFreeze and self:GetFrozen() then
            self:ResetSpeed(ply)
        end

        if self.anim == "jump" and ply:IsOnGround() then
            self.anim, self.animCycle = nil, nil
        end

        local anim, overrideRate
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
        elseif self.tickAnim and anims[self.tickAnim] then
            anim, overrideRate = anims[self.tickAnim], anims[self.tickAnim .. "_rate"] or 1
            self.tickAnim = nil
        elseif self.burrowed then
            anim = anims["burrow_loop"]
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

        if anim and (self:GetSequence() ~= self:LookupSequence(anim) or self.animStart or (self.formTable.autoRestartAnims and self:GetCycle() == 1)) then
            self:ResetSequence(self:LookupSequence(anim))
            self:SetCycle(0)
            self.animCycle = 0
        end
        self.animStart = nil

        local seq_vel = self:GetSequenceGroundSpeed(self:GetSequence())
        if not overrideRate and self.formTable.movePoseMode ~= "xy" and self.formTable.movePoseMode ~= "xy-bot" then
            local rate = vel / (seq_vel ~= 0 and seq_vel or 1)
            self:SetPlaybackRate(math.min(rate, 12))
        end

        if self.formTable.movePoseMode == "xy" then
            if not overrideRate then
                local velocity, pillspeed = ply:GetVelocity(), self.formTable.moveSpeed or {}
                local fwd, right = ply:GetForward(), ply:EyeAngles():Right()
                local moveX, moveY = fwd:Dot(velocity), right:Dot(velocity)

                local maxSpeed = math.max(pillspeed.maxwalk or 80, ply:GetWalkSpeed())
                if ply:IsSprinting() and ply:GetWalkSpeed() ~= ply:GetRunSpeed() then
                    maxSpeed = ply:GetRunSpeed()
                end
                if ply:Crouching() then maxSpeed = maxSpeed * 0.5 end

                local len = math.sqrt(moveX * moveX + moveY * moveY)
                if len > 0 then moveX, moveY = moveX / len, moveY / len end

                local ratio = math.Clamp(velocity:Length2D() / maxSpeed, 0, 1)
                self:SetPoseParameter("move_x", moveX * ratio)
                self:SetPoseParameter("move_y", moveY * ratio)
            else
                self:SetPoseParameter("move_x", 0)
                self:SetPoseParameter("move_y", 0)
            end

        elseif self.formTable.movePoseMode == "xy-bot" then
            if not overrideRate then
                local localvel = ply:WorldToLocal(ply:GetPos() + ply:GetVelocity())
                local maxdim = math.max(math.abs(localvel.x), math.abs(localvel.y))
                local clampedvel = maxdim == 0 and Vector(0, 0, 0) or localvel / maxdim
                local move_dir = self:WorldToLocalAngles(ply:GetVelocity():Angle())

                self:SetPoseParameter("move_x", clampedvel.x)
                self:SetPoseParameter("move_y", -clampedvel.y)
                self:SetPoseParameter("move_yaw", move_dir.y)

                if seq_vel ~= 0 then
                    self:SetPoseParameter("move_x", math.Clamp(localvel.x / seq_vel, -0.99, 0.99))
                    self:SetPoseParameter("move_y", math.Clamp(-localvel.y / seq_vel, -0.99, 0.99))
                    self:SetPoseParameter("move_scale", math.Clamp(localvel:Length() / seq_vel, -0.99, 0.99))
                end
            else
                self:SetPoseParameter("move_x", 0)
                self:SetPoseParameter("move_y", 0)
                self:SetPoseParameter("move_yaw", 0)
                self:SetPoseParameter("move_scale", 0)
            end
        end

        self.touchingWater = ply:WaterLevel() > 1
        if not ply:IsOnGround() and ply:WaterLevel() == 0 and self.formTable.glideThink then
            self.formTable.glideThink(ply, self)
        --elseif not ply:OnGround() and not self.touchingWater and ply:WaterLevel() > 0 and self.formTable.land and not ply:IsFrozen() then
			--self.formTable.land(ply, self)
        end

        if self.formTable.damageFromWater and self.touchingWater then
            if self.formTable.damageFromWater == -1 then
                ply:Kill()
            else
                ply:TakeDamage(self.formTable.damageFromWater)
            end
        end
    else
        if self.formTable.movePoseMode == "yaw" then
            local move_dir = self:WorldToLocalAngles(ply:GetVelocity():Angle())
            self:SetPoseParameter("move_yaw", move_dir.y)
        end
    end

    if self.formTable.aim then
        if self.formTable.aim.xPose then
            local yaw = math.AngleDifference(ply:EyeAngles().y, self:GetAngles().y)
            if self.formTable.aim.xInvert then yaw = -yaw end
            self:SetPoseParameter(self.formTable.aim.xPose, yaw)
        end
        if self.formTable.aim.yPose then
            local pitch = math.AngleDifference(ply:EyeAngles().p, self:GetAngles().p)
            if self.formTable.aim.yInvert then pitch = -pitch end
            self:SetPoseParameter(self.formTable.aim.yPose, pitch)
        end
    end

    if SERVER then
        self:SetPos(ply:GetPos())
    else
        self:SetRenderOrigin(ply:GetPos())
    end

    if vel > 5 or ply:IsFlagSet(FL_FROZEN) or self:GetUseForceAngles() then
        local angs = self:GetUseForceAngles() and self:GetForceAngles() or ply:EyeAngles()
        if not self:GetUseForceAngles() then angs.p = 0 end
        if SERVER then self:SetAngles(angs) else self:SetRenderAngles(angs) end
    end

    self:NextThink(CurTime() + fh_pill_update_rate:GetFloat())
    return true
end

if SERVER then
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
        local ply = self:GetPillUser()

        if self.formTable.die then
            self.formTable.die(ply, self)
        end

        self:PillSound("die")
		
		pills.restore(ply:Nick(), true)
    end

    function ENT:PillAnim(name, freeze)
        self.anim = name
        self.animStart = true
        self.animFreeze = freeze
		self.animLoop = false
    end

    function ENT:PillAnimTick(name)
        self.tickAnim = name
    end
	
    function ENT:PillGesture(name, priority, rate, blendin, out, start)
        local ply = self:GetPillUser()
        if not IsValid(self) then return end
        local anims = table.Copy(self.formTable.anims.default or {})
        table.Merge(anims, IsValid(ply:GetActiveWeapon()) and self.formTable.anims[ply:GetActiveWeapon():GetHoldType()] or {})
        local gesture = anims[name]
		if !gesture then return end
		
		local seq = self:LookupSequence(gesture)
		local id = nil
		
		if self.usedLayers[seq] then
			id = self.usedLayers[seq]
		end
		if !id then
			id = self:AddLayeredSequence(seq, priority or 1)
			self.usedLayers[seq] = id
			//print('созда')
		else
			//print('использа')
			self:SetLayerSequence(id, seq)
		end
		self:SetLayerPlaybackRate(id, (rate or 1))
		self:SetLayerCycle(id, start or 0)
		
		self:SetLayerWeight(id, 1)
		self:SetLayerBlendIn(id, blendin or 0.1)
		self:SetLayerBlendOut(id, out or 0.1)
		
    end
	
	-- для совместимости с сторонними пилл паками
	function ENT:GetPuppet()
		return self
	end
	
    function ENT:PillStopGesture(name)
        local ply = self:GetPillUser()
        if not IsValid(self) then return end
        local anims = table.Copy(self.formTable.anims.default or {})
        table.Merge(anims, IsValid(ply:GetActiveWeapon()) and self.formTable.anims[ply:GetActiveWeapon():GetHoldType()] or {})
        local gesture = anims[name]
		local seq = self:LookupSequence(gesture)
		local id = nil
		
		if self.usedLayers[seq] then
			id = self.usedLayers[seq]
		end
		if !id then
			return
		end
		
		self:SetLayerPlaybackRate(id, 0.5)
		self:SetLayerCycle(id, 0)
		
		self:SetLayerWeight(id, 0)
		self:SetLayerBlendIn(id, 0)
		self:SetLayerBlendOut(id, 0)
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

    if (istable(s)) then
        s = table.Random(s)
    end

    if isstring(s) then
        if bulk then
            sound.Play(s, self:GetPos(), self.formTable.sounds[name .. "_level"] or (name == "step" and 75 or 75), self.formTable.sounds[name .. "_pitch"] or 100, 1)
        else
			local recipients = hook.Run("PillSound", self:GetPillUser(), self, name)
		
            self:GetPillUser():EmitSound(s, self.formTable.sounds[name .. "_level"] or 75, self.formTable.sounds[name .. "_pitch"] or 100, 1, CHAN_AUTO, 0, 0, recipients or nil)
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
	if self.formTable.anims.default ~= nil then
		self.formTable.anims.default[old] = new
	end
end

function ENT:ResetAngle()
	if SERVER then return end
	
	local ply = self:GetPillUser()
	if IsValid(self) then
		local angs=ply:EyeAngles()
		angs.p=0
		
		self:SetRenderAngles(angs)
	
		self:DrawModel()
	end
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

ENT.IsDrawn = true

function ENT:Draw()
	local ply = self:GetPillUser()
	
	--self:FrameAdvance()

	ply:RemoveAllDecals()
	
	if self:GetNoDraw() then
		self.IsDrawn = false
		self:DrawShadow(false)
	end
	
    local drawHook = hook.Run("ForceDrawPill", ply, self)

	if drawHook == true then
		self:DrawModel()
		self.IsDrawn = true
		return
    elseif drawHook == false then
		self.IsDrawn = false
		self:DrawShadow(false)
		return
	end
	
	if ply == LocalPlayer():GetObserverTarget() 
	and LocalPlayer():GetViewEntity() == LocalPlayer()
	and LocalPlayer():GetObserverMode() == OBS_MODE_IN_EYE then
		return
	end
	
	if ply == LocalPlayer() 
	and ply:GetViewEntity() == ply
	and !pills.convars.cl_thirdperson:GetBool() 
	and !ply.fh_target_player then
		self.IsDrawn = false
		self:DrawShadow(false)
		return
	end

    local invisible = self:GetMaterial() == "models/null"

    if invisible then
		self:DrawShadow(false)
    end

	self:DrawModel()
	self.IsDrawn = true
	
	if ply == LocalPlayer() and !invisible then
		self:DrawShadow(true)
	end
end

function ENT:DrawTranslucent()
    self:Draw()
end

hook.Add("PrePlayerDraw", "fh_pill_costume_mirrors", function(ply)
    if ply ~= LocalPlayer() then return end

    local ent = pills.getMappedEnt(ply)
    if not IsValid(ent) then return end
    if ent.IsDrawn or ent:GetNoDraw() or ent:GetMaterial() == "models/null" then return end

    if not IsValid(ent.mirrorPill) then
        local m = ClientsideModel(ent:GetModel(), RENDERGROUP_OPAQUE)
        if IsValid(m) then
            m:SetParent(ent)
            m:SetSkin(ent:GetSkin())
            m:AddEffects(EF_BONEMERGE)
            m:SetNoDraw(true)
            ent.mirrorPill = m

            local bodyGroups = ent.formTable.bodyGroups

            if ent.formTable.options then
                local options = ent.formTable.options()
                local pickedOption

                if ent.formTable.option and options[ent.formTable.option] then
                    pickedOption = options[ent.formTable.option]
                else
                    pickedOption = table.Random(options)
                end

                if pickedOption and pickedOption.bodyGroups then
                    bodyGroups = pickedOption.bodyGroups
                end
            end

            if bodyGroups then
                for k, v in pairs(bodyGroups) do
                    if isnumber(k) then
                        m:SetBodygroup(k, v)
                    elseif isstring(k) then
                        local id = m:FindBodygroupByName(k)
                        if id >= 0 then
                            m:SetBodygroup(id, v)
                        end
                    elseif isnumber(v) then
                        m:SetBodygroup(v, 1)
                    end
                end
            end
        end
    end

    local cm = ent.mirrorPill
    if IsValid(cm) then
        cm:SetModel(ent:GetModel())
        cm:DrawModel()
    end
end)