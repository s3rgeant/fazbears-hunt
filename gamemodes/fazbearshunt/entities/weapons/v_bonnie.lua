SWEP.PrintName = "Bonnie SWEP"

SWEP.Base = "v_base"

if CLIENT then
	local vfov = CreateClientConVar('cl_fov_bonnie', 95, true, false, 'Fov of Bonnie')
	SWEP.ViewModelFOV = vfov:GetFloat() or 95
    
    cvars.AddChangeCallback("cl_fov_bonnie", function(name, old_value, new_value)
		local wep = LocalPlayer():GetActiveWeapon()
		if IsValid(wep) and string.StartWith(wep:GetClass(), "v_") then
			wep.ViewModelFOV = tonumber(new_value) or 95
		end
	end)
end

SWEP.ViewModel = "models/speps/vm/oldbonnie.mdl"
SWEP.m_WeaponDeploySpeed = 0.7
SWEP.Secondary.Automatic = true

function SWEP:SetupDataTables()
    self:NetworkVar("Entity", 0, "LastTarget")
    return self.BaseClass.SetupDataTables and self.BaseClass.SetupDataTables(self)
end

function SWEP:SetupAnimations()
	self:AddAnimation("scare")
	self:AddAnimation("deploy")
	self:AddAnimation("draw")
	self:AddAnimation("attack")
	
	self:AddAnimation("positive")
	self:AddAnimation("negative")
end

SWEP.LastTarget = nil
SWEP.PickingRandom = false
SWEP.Picking = false
SWEP.HullTarget = nil

SWEP.ControlSound = nil
SWEP.GlobalControlSound = nil
SWEP.RandomTarget = nil

SWEP.Controlling = false
function SWEP:YoursMineTimer(dur)
	if CLIENT then return end
    local ply = self:GetOwner()
	
	local timerName = "bonnie_swep_yoursmine_rmb_" .. ply:EntIndex()
	
	if timer.Exists(timerName) then timer.Remove(timerName) end
	
	timer.Create(timerName, dur, 1, function()
		local target = self.LastTarget or self.RandomTarget
		
		if IsValid(target) then
			YoursMine_Start(self.Owner, target)
			return
		end
		ply:SendLua("surface.PlaySound('ability_failed.wav')")
		
		cooldown.Set(ply, "yoursmine", 1)
		cooldown.Send(ply, "yoursmine")
	end)
end

function SWEP:SecondaryAttack()
    local ply = self:GetOwner()
    if not IsValid(ply) then return end
	
	if CLIENT then return end
	
	if cooldown.Exists(ply, "yoursmine") then return end
	
	if ply:IsFrozen() or !ply:OnGround() then return end

    local shootPos = ply:GetShootPos()
    local ang = ply:EyeAngles()

    local dist = 10000

    local tr = util.TraceHull({
        start  = shootPos,
        endpos = shootPos + ang:Forward() * dist,
        mins   = Vector(-5, -5, -5),
        maxs   = Vector(5, 5, 5),
        filter = ply
    })
	
	self.Picking = true

    local ent = tr.Entity
	self.HullTarget = ent
    if IsValid(ent) and ent:IsPlayer() and ent:IsSurvivor() and !ent:IsInvisible() and !PlayerInOutworld(ent) then
        if ent ~= self.LastTarget then
            self.LastTarget = ent
			self:SetLastTarget(ent)
			self.RandomTarget = nil
			
			-- ЛОКАЛЬНЫЙ ЗВУК
			local rf = RecipientFilter()
			rf:AddPlayer(self.LastTarget)
			rf:AddPlayer(ply)
			
			if self.ControlSound then
                self.ControlSound:Stop()
				self.ControlSound = nil
			end
			if !self.ControlSound then
				self.ControlSound = CreateSound(game.GetWorld(), "bonnie_control_targetted.wav", rf)
				self.ControlSound:SetSoundLevel( 0 )
			end
			self.ControlSound:Play()
		
			-- ГЛОБАЛЬНЫЙ ЗВУК
			local rf = RecipientFilter()
			rf:AddAllPlayers()
			rf:RemovePlayer(self.LastTarget)
			rf:RemovePlayer(ply)
			
			if self.GlobalControlSound then
				self.GlobalControlSound:Stop()
				self.GlobalControlSound = nil
			end
			if !self.GlobalControlSound then
				self.GlobalControlSound = CreateSound(ply, "bonnie_control_others.wav", rf)
				self.GlobalControlSound:SetSoundLevel( 0 )
			end
			self.GlobalControlSound:Play()

            local now = CurTime()
            self:SetNextPrimaryFire(now + 2)
            self:SetLastAttack(now)
		
			self.PickingRandom = false
			
			self:YoursMineTimer(2)
        end
    end
	
	if !self.LastTarget and !self.PickingRandom then
		local now = CurTime()
		
		self.RandomTarget = fh_random_yoursmine_target(ply)
		
		-- ЛОКАЛЬНЫЙ ЗВУК
		
		if !IsValid(self.RandomTarget) then return end
		
		local rf = RecipientFilter()
		rf:AddPlayer(self.RandomTarget)
		rf:AddPlayer(ply)
		
		if self.ControlSound then
            self.ControlSound:Stop()
			self.ControlSound = nil
		end
		if !self.ControlSound then
			self.ControlSound = CreateSound(game.GetWorld(), "bonnie_control_randoms.wav", rf)
			self.ControlSound:SetSoundLevel( 0 )
		end
		self.ControlSound:Play()
		
		-- ГЛОБАЛЬНЫЙ ЗВУК
		local rf = RecipientFilter()
		rf:AddAllPlayers()
		rf:RemovePlayer(self.RandomTarget)
		rf:RemovePlayer(ply)
		
		if self.GlobalControlSound then
            self.GlobalControlSound:Stop()
			self.GlobalControlSound = nil
		end
		if !self.GlobalControlSound then
			self.GlobalControlSound = CreateSound(ply, ")bonnie_control_others.wav", rf)
		end
		self.GlobalControlSound:Play()
		
		self:SetNextPrimaryFire(now + 3)
		self:SetLastAttack(now)
			
		self:YoursMineTimer(3)
		
		self.PickingRandom = true
	end
end

function SWEP:Think()
	if SERVER then
		local ply = self:GetOwner()
		if !self.Owner:KeyDown(IN_ATTACK2) and self.Picking or (ply:IsFrozen() or !ply:OnGround()) then
			self.PickingRandom = false
			self.Picking = false
			self:SetNextPrimaryFire(CurTime() - 1)
			self:SetLastAttack(CurTime())
			
			self.LastTarget = nil
			self:SetLastTarget(nil)
			
			self.RandomTarget = nil
			
			timer.Remove("bonnie_swep_yoursmine_rmb_" .. self.Owner:EntIndex())
			
			if self.ControlSound and !self.Controlling then
                self.ControlSound:Stop()
			end
			
			if self.GlobalControlSound then
                self.GlobalControlSound:Stop()
			end
		end
		
		if self.LastTarget and self.Picking and !IsValid(self.HullTarget) then
			local tr = util.TraceLine( {
				start = ply:EyePos(),
				endpos = self.LastTarget:EyePos(),
				mask = MASK_BLOCKLOS_AND_NPCS,
				filter = {self.LastTarget, ply}
			} )
			
			if tr.Hit then
				self.LastTarget = nil
				self:SetLastTarget(nil)
			
				ply:SendLua("surface.PlaySound('tools/ifm/ifm_denyundo.wav')")
			end
		end
	
	end

    return self.BaseClass.Think and self.BaseClass.Think(self)
end

if CLIENT then
	hook.Add("PreDrawHalos", "yoursmine_weapon", function()
		local ply = LocalPlayer()
		local target = ply:GetObserverTarget()
		if IsValid(target) and target:IsPlayer() then ply = target end

		local wep = ply:GetActiveWeapon()
		if not (IsValid(wep) and wep:GetClass() == "v_bonnie") then return end
		if not ply:KeyDown(IN_ATTACK2) then return end

		local ent = wep:GetLastTarget()
		if IsValid(ent) and ent:IsPlayer() and ent:IsSurvivor() and !ent:IsInvisible() then
			halo.Add({ ent }, Color(55, 25, 255), 1, 1, 2, true, false)
		end
	end)
	
    local crouchFactor = 0

    function SWEP:CalcViewModelView(ViewModel, OldEyePos, OldEyeAng, EyePos, EyeAng)
        local ply = self.Owner
        if not IsValid(ply) then return EyePos, EyeAng end
		
        local target = (self:GetSequenceName(self:GetSequence()):match("crouch") == "crouch") and 1 or 0
        crouchFactor = Lerp(FrameTime() * 5, crouchFactor, target)

        local newPitch = Lerp(crouchFactor, EyeAng.p, 0)
        EyeAng.p = newPitch

        return EyePos, EyeAng
    end
end