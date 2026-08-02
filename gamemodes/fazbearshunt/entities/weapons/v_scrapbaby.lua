SWEP.PrintName = "Scrap Baby SWEP"

SWEP.Base = "v_base"

if CLIENT then
	local vfov = CreateClientConVar('cl_fov_scrapbaby', 100, true, false, 'Fov of Scrap Baby')
	SWEP.ViewModelFOV = vfov:GetFloat() or 100
    
    cvars.AddChangeCallback("cl_fov_scrapbaby", function(name, old_value, new_value)
		local wep = LocalPlayer():GetActiveWeapon()
		if IsValid(wep) and string.StartWith(wep:GetClass(), "v_") then
			wep.ViewModelFOV = tonumber(new_value) or 100
		end
    end)
end

SWEP.ViewModel = "models/torres/ffps/salvage/vm/scrapbabyv19.mdl"
SWEP.m_WeaponDeploySpeed = 0.7
SWEP.LandHold = 0.2

SWEP.LoopSoundBaby = nil
SWEP.LoopSoundClaw = nil

SWEP.Primary.Automatic = false
SWEP.Secondary.Automatic = true

function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "Charging")
    self:NetworkVar("Bool", 1, "ClawFlying")
    self:NetworkVar("Bool", 2, "ClawWait")
    self:NetworkVar("Bool", 3, "ClawFlyingHome")
    self:NetworkVar("Entity", 0, "Claw")
    self:NetworkVar("Entity", 1, "PillCostume")
    return self.BaseClass.SetupDataTables and self.BaseClass.SetupDataTables(self)
end

function SWEP:SetupAnimations()
	self:AddAnimation("draw")
	self:AddAnimation("attack")
	self:AddAnimation("aim")
	self:AddAnimation("aim-loop")
	self:AddAnimation("shoot")
	self:AddAnimation("shoot-loop")
	self:AddAnimation("hit")
	self:AddAnimation("pull")
	self:AddAnimation("return")
end

function SWEP:PrimaryAttack()
	local owner = self:GetOwner()
	if self:GetCharging() and owner:KeyDown(IN_ATTACK2) then
		self:ThrowHook()
		return
	end
	
	if self:GetClawFlying() and not self:GetClawFlyingHome() then
		self:AskClawBack()
	end
end

function SWEP:SecondaryAttack()
    local ply = self:GetOwner()
    local ent = self:GetPillCostume()
    if not IsValid(ent) then return end
	
	if cooldown.Exists(ply, "snatch") then return end
	
    if ply:IsFrozen() then return end
	if IsValid(self:GetClaw()) then return end
	if self:GetClawWait() or self:GetClawFlying() or self:GetClawFlyingHome() then return end
    if self:GetCharging() or ply.tasered then return end

    if SERVER then
		ent:PillGesture('aim', 2, 1, 0.1, 0.3)
		
		timer.Simple(0.5, function()
			if not ply:KeyDown(IN_ATTACK2) then return end
			if not IsValid(ent) then return end
			if self:GetClawWait() or self:GetClawFlying() or self:GetClawFlyingHome() then return end
			
			ent:PillGesture('aimL', 1, 1, 0, 0, nil, true)
			timer.Simple(0, function()
				if not IsValid(ent) then return end
				ent:PillStopGesture("aim")
			end)
		end)
        ply:EmitSound("animatronics/scrapbaby/baby_hook_ready.mp3", 90)
    end

    if IsFirstTimePredicted() then
        self:HandleAnimation("aim", 99999)
    end

    self:SetCharging(true)
end

function SWEP:CanJumpscare()
	return not self:GetCharging() and not self:GetClawFlying() and not self:GetClawFlyingHome() and not self:GetClawWait()
end

function SWEP:CanLand()
	return not self:GetClawFlying() and not self:GetClawFlyingHome() and not self:GetClawWait()
end

function SWEP:ThrowHook()
	local ply = self:GetOwner()
    local ent = self:GetPillCostume()
	
	self.Stuckie = 0
	
    if SERVER then
		ent:PillGesture('shoot', 2, 1, 0.1, 0.3)
		
		timer.Simple(0.5, function()
			if not IsValid(ent) then return end
			if not self:GetClawFlying() and not self:GetClawFlyingHome() and not self:GetClawWait() then return end
			
			ent:PillGesture('shootL', 1, 1, 0, 0, nil, true)
			timer.Simple(0, function()
				if not IsValid(ent) then return end
				ent:PillStopGesture("shoot")
			end)
		end)
		ply:EmitSound("animatronics/scrapbaby/baby_hook_throw.mp3", 90)
    end
	
	if SERVER and IsValid(ent) then
		ent:PillStopGesture("aim")
		ent:PillStopGesture("aimL")
		ent:SetBodygroup(1, 1)
	end
	
	self:SetCharging(false)
	self:SetClawFlying(true)
	
	self:HandleAnimation("shoot", 2)
	ply:GetViewModel():SetBodygroup(0, 1)
	
	if CLIENT then return end
	
	local spawnPos = (ply:EyePos() - Vector(0,0,4)) + (ply:GetForward() * 20) + (ply:GetRight() * 2)
	
	local claw = ents.Create("baby_claw")
	
	claw:SetPos(spawnPos)
	claw:SetAngles(ply:GetAngles())
	claw:SetOwner(ply)
	claw:Spawn()
	claw:Activate()
	
	if SERVER then
		if self.LoopSoundBaby then
			self.LoopSoundBaby:Stop()
			self.LoopSoundBaby = nil
		end
		if not self.LoopSoundBaby then
			local rf = RecipientFilter()
			rf:AddAllPlayers()
			
			self.LoopSoundBaby = CreateSound(claw, ")animatronics/scrapbaby/hook_loop.wav", rf)
		end
		self.LoopSoundBaby:Play()
	end
	
	self:SetClaw(claw)
	
	local phys = claw:GetPhysicsObject()
	
	if IsValid(phys) then
		phys:EnableGravity( false )
		--phys:SetVelocity(ply:GetForward() * 2500)
	end
end

if CLIENT then
	local rope = {slack = 100, material = "cable/cable"}
	--local rope = {slack = 100, material = "unioncity/cable/chandchain"}
	hook.Add("OnEntityCreated", "scrapbaby_hookspawn", function(ent)
		if ent:GetClass() == "baby_claw" then
			local owner = ent:GetOwner()
			
			if IsValid(owner) then
				local ent = ent
				local ent2 = owner:GetPill()
				
				if not IsValid(ent2) then return end
				
				local ropeEnt = ents.CreateClientRope( ent, 0, ent2, 1, rope )
			end
		end
	end)
end

SWEP.ProcessedHit = false
function SWEP:ClawHit(target)
	if self.ProcessedHit then return end
	
    local ply = self:GetOwner()
	local ent = ply:GetPillCostume()
	local validTarget = false
	
    self:HandleAnimation("hit", 2)
	self:SetClawFlying(false)
	self:SetClawWait(true)
		
	local claw = self:GetClaw()
	
	if target ~= ply and target:IsPlayer() then
		target:SetNWEntity("_ScrapBabyHooker", ply)
		validTarget = true
		
		smoothLookAt(target, ply)
		
		if IsValid(ent) then
			if ent.formTable.clawPlayerHit then
				ent.formTable.clawPlayerHit(ply, ent, claw, target)
			end
		end
		
		if IsValid(claw) then
			if target:IsAnimatronic() then
				claw:EmitSound("animatronics/scrapbaby/baby_hook_teammate.mp3")
				target._skipLandAnim = true
			else
				claw:EmitSound("animatronics/scrapbaby/baby_hook_success.mp3")
			end
			claw:SetSucker(target)
			claw:SetPos(target:GetPos() + target:OBBCenter())
			claw:SetParent(target)
			
			self.ProcessedHit = true
		end
	end
	
	if not target:IsPlayer() then
		if IsValid(claw) then
			claw:EmitSound("animatronics/scrapbaby/baby_hook_enviroment.mp3")
		end
		
		if IsValid(ent) then
			if ent.formTable.clawEnvironmentHit then
				ent.formTable.clawEnvironmentHit(ply, ent, target)
			end
		end
	end
	
	if target:GetClass() == "prop_door_rotating" then
		timer.Simple(0, function()
			if not IsValid(target) then return end
			breakBustDoor(ply, target, 15)
		end)
	end
	
	if SERVER and self.LoopSoundBaby then
		self.LoopSoundBaby:ChangePitch(77, 0.1)
		self.LoopSoundBaby:ChangeVolume(0, 0.1)
	end
	
	timer.Simple(0.1, function()
		self:SetClawWait(false)
		self:SetClawFlyingHome(true)
	
		if SERVER and self.LoopSoundBaby then
			self.LoopSoundBaby:ChangePitch(100, 1.5)
			self.LoopSoundBaby:ChangeVolume(1, .1)
		end
		
		if IsValid(claw) then
			self:HandleAnimation("pull", 25)
			claw:SetGoHome(true)
			
			if not validTarget then
				--self:SetCollisionGroup(COLLISION_GROUP_VEHICLE_CLIP)
				claw:SetNotSolid(true)
			end
			return
		end
		self:SetClawFlyingHome(false)
		if IsValid(ent) then 
			ent:SetBodygroup(1, 0)
		end
		if IsValid(ply) and IsValid(ply:GetViewModel()) then
			ply:GetViewModel():SetBodygroup(0, 0)
		end
	end)
end

function SWEP:ClawBack()
    self:HandleAnimation("return", -1, true)
	
	self.ProcessedHit = false
	
	self:SetClawFlying(false)
	self:SetClawWait(false)
	self:SetClawFlyingHome(false)
	
	self:SetClaw(NULL)
	
	if SERVER and self.LoopSoundBaby then
		self.LoopSoundBaby:Stop()
		self.LoopSoundBaby = nil
	end
	
    local ply = self:GetOwner()
	
	if SERVER then
		local ent = ply:GetPillCostume()
		if IsValid(ent) then
			ent:PillStopGesture("shoot")
			ent:PillStopGesture("shootL")
			ent:SetBodygroup(1, 0)
		end
	end
	
	if IsValid(ply) and IsValid(ply:GetViewModel()) then
		ply:GetViewModel():SetBodygroup(0, 0)
	end
end

function SWEP:Think()
	local curtime = CurTime()
	local ply = self:GetOwner()
	
	if self:GetCharging() and not ply:KeyDown(IN_ATTACK2) then
		self:SetCharging(false)
        self:ClawBack()
		local ent = self:GetPillCostume()
		
		if SERVER and IsValid(ent) then
			ent:PillStopGesture("aim")
			ent:PillStopGesture("aimL")
		end
        return
    end

    return self.BaseClass.Think and self.BaseClass.Think(self)
end

function SWEP:AskClawBack()
    local ply = self:GetOwner()
	local ent = ply:GetPillCostume()
	local validTarget = false
	
    self:HandleAnimation("hit", 2)
	self:SetClawFlying(false)
	self:SetClawWait(true)
	
	local claw = self:GetClaw()
	
	timer.Simple(0.1, function()
		self:SetClawWait(false)
		self:SetClawFlyingHome(true)
	
		if SERVER and self.LoopSoundBaby then
			self.LoopSoundBaby:ChangePitch(100, 1.5)
			self.LoopSoundBaby:ChangeVolume(1, .1)
		end
		
		if IsValid(claw) then
			self:HandleAnimation("pull", 25)
			claw:SetGoHome(true)
			
			if not validTarget then
				claw:SetNotSolid(true)
			end
			return
		end
		self:SetClawFlyingHome(false)
		if IsValid(ent) then 
			ent:SetBodygroup(1, 0)
		end
		if IsValid(ply) and IsValid(ply:GetViewModel()) then
			ply:GetViewModel():SetBodygroup(0, 0)
		end
	end)
end


local YAW_LIMIT_DPS = 90
local lastAng
hook.Add( "StartCommand", "fh_baby_cantrun_aim", function( ply, cmd )
	if !ply:Alive() then return end
	
	local wep = ply:GetActiveWeapon()
	if !IsValid(wep) or wep:GetClass() ~= "v_scrapbaby" then
		return
	end
	
	if not wep.GetCharging or not wep.GetClawWait or not wep.GetClawFlying or not wep.GetClawFlyingHome then return end
	
	if wep:GetCharging() or wep:GetClawWait() or wep:GetClawFlying() or wep:GetClawFlyingHome() then
		cmd:RemoveKey(IN_SPEED)
		if CLIENT and not wep:GetCharging() and not wep:GetClawFlyingHome() then
			local ang = cmd:GetViewAngles()

			if not lastAng then
				lastAng = Angle(ang.p, ang.y, ang.r)
				return
			end

			local maxDelta = YAW_LIMIT_DPS * RealFrameTime()

			local dy = math.AngleDifference(ang.y, lastAng.y)

			if dy > maxDelta then dy = maxDelta
			elseif dy < -maxDelta then dy = -maxDelta end

			ang.y = lastAng.y + dy
			cmd:SetViewAngles(ang)

			lastAng.y = ang.y
			lastAng.p = ang.p
			lastAng.r = 0
			return
		end
		lastAng = nil
	end
end )

hook.Add( "SetupMove", "fh_baby_slowwalk_aim", function( ply, mv, cmd )
	if !ply:Alive() then return end
	
	local wep = ply:GetActiveWeapon()
	if !IsValid(wep) or wep:GetClass() ~= "v_scrapbaby" then
		return
	end
	
	-- ХЗ это круто что я это заюзал кайф не???
	if cooldown.Exists(ply, "kill") then
		mv:SetMaxSpeed(120)
		mv:SetMaxClientSpeed(120)
	end
	
	if not wep.GetCharging or not wep.GetClawWait or not wep.GetClawFlying or not wep.GetClawFlyingHome then return end
	
	if wep:GetCharging() or wep:GetClawWait() or wep:GetClawFlying() or wep:GetClawFlyingHome() then
		mv:SetMaxSpeed(150)
		mv:SetMaxClientSpeed(150)
	end
end )

local up_tr = {}
local down_tr = {}
local mins = Vector(6,6,6)
local maxs = Vector(6,6,6)

up_tr.mins = mins
up_tr.maxs = maxs
up_tr.collisiongroup = COLLISION_GROUP_PLAYER

down_tr.mins = mins
down_tr.maxs = maxs
down_tr.collisiongroup = COLLISION_GROUP_PLAYER

hook.Add( "Move", "scrapbaby_move", function( ply, mv )
	local suka = ply:GetNWEntity("_ScrapBabyHooker")
	if suka:IsValid() then
		local wep = suka:GetActiveWeapon()
		
		if IsValid(wep) and wep:GetClass() == "v_scrapbaby" and wep:GetClawFlyingHome() then
			local forceMove = false
		
			local targetPos = mv:GetOrigin()
			local targetEyes = ply:EyePos()
			--targetPos.z = 0
			local sukaPos = suka:GetPos()
			--sukaPos.z = 0
			
			local targetPath = sukaPos - targetPos
			targetPath:Normalize()
			
			up_tr.start = targetEyes
			up_tr.endpos = targetEyes + targetPath * 48
			up_tr.filter = ply
			
			down_tr.start = targetPos
			down_tr.endpos = targetPos + targetPath * 48
			down_tr.filter = ply
			
			--debugoverlay.Line( up_tr.start, up_tr.endpos, 10 )
			
			local up = 		util.TraceHull( up_tr )
			local down = 	util.TraceHull( down_tr )
			
			local addDir = Vector(0,0,0)
			
			if down.Hit and not up.Hit then
				addDir = suka:GetUp() * 1500
			elseif not down.Hit and up.Hit then
				addDir = suka:GetUp() * -1500
			elseif down.Hit and up.Hit then
				if not wep.Stuckie then wep.Stuckie = 0 end
				wep.Stuckie = wep.Stuckie + 0.1
			end
			
			if ply:GetVelocity():Length() < 600 then
				if not wep.Stuckie then wep.Stuckie = 0 end
				wep.Stuckie = wep.Stuckie + 0.1
			end
			
			local direction = targetPos - (sukaPos - Vector(0,0,16))
			direction:Normalize()
			
			mv:SetVelocity((direction * (-200 *5)) + addDir)
			
			if wep.Stuckie and wep.Stuckie >= 5 then
				mv:SetOrigin(mv:GetOrigin() + direction * -40)
				return true
			end
		end
	end
end)

hook.Add( "StartCommand", "scrapbaby_hooktarget_nocommands", function( ply, cmd )
	local suka = ply:GetNWEntity("_ScrapBabyHooker")
	if suka:IsValid() then
		cmd:ClearMovement() 
		cmd:ClearButtons()
	end
end)