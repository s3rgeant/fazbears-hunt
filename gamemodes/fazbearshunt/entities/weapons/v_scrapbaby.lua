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

function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "Charging")
    self:NetworkVar("Bool", 1, "ClawFlying")
    self:NetworkVar("Bool", 2, "ClawWait")
    self:NetworkVar("Bool", 3, "ClawFlyingHome")
    self:NetworkVar("Entity", 0, "Claw")
    return self.BaseClass.SetupDataTables and self.BaseClass.SetupDataTables(self)
end

function SWEP:SetupAnimations()
	self:AddAnimation("draw")
	self:AddAnimation("aim")
	self:AddAnimation("aim-loop")
	self:AddAnimation("shoot")
	self:AddAnimation("shoot-loop")
	self:AddAnimation("hit")
	self:AddAnimation("pull")
	self:AddAnimation("return")
end

function SWEP:PrimaryAttack()
	if self:GetCharging() and self:GetOwner():KeyDown(IN_ATTACK2) then
		self:ThrowHook()
	end
end

function SWEP:SecondaryAttack()
    local ply = self:GetOwner()
    local ent = pills.getMappedEnt(ply)
    if not IsValid(ent) then return end
    if ply:IsFrozen() then return end
	if self:GetClawWait() or self:GetClawFlying()  or self:GetClawFlyingHome() then return end
    if self:GetCharging() or ply.tasered then return end

    if SERVER then
		--if !ply:Crouching() then
			--ent:PillGesture('swing', 2, 1, 0.1, 0.3)
		--end
        ply:EmitSound("fnaf3/pre-hit.mp3")
    end

    if IsFirstTimePredicted() then
        self:HandleAnimation("aim", 99999)
    end

    self:SetCharging(true)
end

function SWEP:ThrowHook()
    local ply = self:GetOwner()
	
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
	
	self:SetClaw(claw)
	
	local phys = claw:GetPhysicsObject()
	
	if IsValid(phys) then
		phys:EnableGravity( false )
		phys:SetVelocity(ply:GetForward() * 2500)
	end
end

if CLIENT then
	local rope = {slack = 100, material = "cable/cable"}
	hook.Add("OnEntityCreated", "scrapbaby_hookspawn", function(ent)
		if ent:GetClass() == "baby_claw" then
			local owner = ent:GetOwner()
			
			if IsValid(owner) then
				local ent = ent
				local ent2 = owner:GetPill()
				
				local ropeEnt = ents.CreateClientRope( ent, 0, ent2, 1, rope )
			end
		end
	end)
end

function SWEP:ClawHit(target)
    local ply = self:GetOwner()
	local validTarget = false
	
    self:HandleAnimation("hit", 2)
	self:SetClawFlying(false)
	self:SetClawWait(true)
		
	local claw = self:GetClaw()
	
	if target ~= ply and target:IsPlayer() then
		target:SetNWEntity("_ScrapBabyHooker", ply)
		validTarget = true
		
		if IsValid(claw) then
			claw:SetSucker(target)
			claw:SetParent(target)
		end
	end
	
	timer.Simple(0.1, function()
		self:SetClawWait(false)
		self:SetClawFlyingHome(true)
		
		if IsValid(claw) then
			self:HandleAnimation("pull", 4)
			claw:SetGoHome(true)
			
			if not validTarget then
				claw:SetSolid(SOLID_NONE)
			end
			return
		end
		self:SetClawFlyingHome(false)
		if IsValid(ply) and IsValid(ply:GetViewModel()) then
			ply:GetViewModel():SetBodygroup(0, 0)
		end
	end)
end

function SWEP:ClawBack()
    self:HandleAnimation("return", 1, true)
	
	self:SetClawFlying(false)
	self:SetClawWait(false)
	self:SetClawFlyingHome(false)
	
	self:SetClaw(NULL)
	
    local ply = self:GetOwner()
	if IsValid(ply) and IsValid(ply:GetViewModel()) then
		ply:GetViewModel():SetBodygroup(0, 0)
	end
end

function SWEP:Think()
	local curtime = CurTime()
	
	if self:GetCharging() and not self:GetOwner():KeyDown(IN_ATTACK2) then
		self:SetCharging(false)
        self:ClawBack()
        return
    end

    return self.BaseClass.Think and self.BaseClass.Think(self)
end

hook.Add( "StartCommand", "fh_baby_cantrun_aim", function( ply, cmd )
	if !ply:Alive() then return end
	
	local wep = ply:GetActiveWeapon()
	if !IsValid(wep) or wep:GetClass() ~= "v_scrapbaby" then
		return
	end
	
	if not wep.GetClawWait or not wep.GetClawFlying or not wep.GetClawFlyingHome then return end
	
	if ply:KeyDown(IN_ATTACK2) or wep:GetClawWait() or wep:GetClawFlying() or wep:GetClawFlyingHome() then
		cmd:RemoveKey(IN_SPEED)
	end
end )

hook.Add( "Move", "scrapbaby_move", function( ply, mv )
	local suka = ply:GetNWEntity("_ScrapBabyHooker")
	if suka:IsValid() then
		local wep = suka:GetActiveWeapon()
		
		if IsValid(wep) and wep:GetClass() == "v_scrapbaby" and wep:GetClawFlyingHome() then
			local targetPos = mv:GetOrigin()
			targetPos.z = 0
			local sukaPos = suka:GetPos()
			sukaPos.z = 0
			
			local direction = targetPos - (sukaPos - Vector(0,0,16))
			direction:Normalize()
			
			mv:SetVelocity(direction * (-200 *5))
		end
	end
end)