
-- Variables that are used on both client and server

SWEP.PrintName		= "Scripted Viewmodel"
SWEP.Author			= ""
SWEP.Contact		= ""
SWEP.Purpose		= ""
SWEP.Instructions	= ""

SWEP.ViewModelFOV	= 100
SWEP.ViewModelFlip	= false
SWEP.ViewModel		= "models/speps/vm/oldfreddy.mdl"
SWEP.WorldModel		= ""
SWEP.UseHands = false
SWEP.DrawAmmo = false
SWEP.m_WeaponDeploySpeed = 0.7
SWEP.BackupBlocked = true

SWEP.Spawnable		= false
SWEP.AdminOnly		= false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Ammo = "none"
SWEP.Primary.Automatic = true

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Automatic = false

SWEP.Animations = {}

SWEP.CurAnim = 'idle'
SWEP.PreviousOnGround = true
SWEP.HoldAnim = 0

SWEP.LandHold = 0.2
SWEP.JumpHold = 0.2

function SWEP:SetupDataTables()
	self:NetworkVar( "Float", 1, "LastAttack" )
end

-- Avoid using it anywhere except SWEP:SetupAnimations()
function SWEP:AddAnimation(anim, swagAct, swagName, noForce)
	if noForce then
		if self.Animations[anim] then return end
	end

	local seq = self:LookupSequence( swagName or anim )
	
	local act = swagAct or self:GetSequenceActivity( seq )
	
	if !act or act < 0 then
		return
	end
	
	self.Animations[anim] = act
end

function SWEP:Initialize()
	self.Animations = {}
end

function SWEP:PrimaryAttack()
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
end

function SWEP:HandleAnimation(anim, hold, force)
	if !self.Animations[anim] then
		return false
	end
	
	local act = self.Animations[anim]
	
	if self.CurAnim == anim and act == self:GetActivity() and !force then
		return false
	end
	
	if !act or act < 0 then
		return false
	end
	
	self:SendWeaponAnim( act )
	self.CurAnim = anim
	
	if hold and hold > 0 then
		self.HoldAnim = CurTime() + hold
	elseif hold == -1 then
		local seq = self:SelectWeightedSequence( act )
		local len = self:SequenceDuration( seq )
		
		self.HoldAnim = CurTime() + len
	end
end

function SWEP:HandleGroundAnim()
	return false
end

function SWEP:Think()
    if SERVER then
		local curtime = CurTime()
        local ply = self:GetOwner()
        local speed = ply:GetAbsVelocity():Length()
        local onGround = ply:OnGround()
        local runSpeed = ply:GetRunSpeed()
        local walkSpeed = ply:GetWalkSpeed()
        local crouchSpeed = ply:GetCrouchedWalkSpeed()
		
        if self.HoldAnim > 0 and curtime < self.HoldAnim then
			if ply:GetViewModel():IsSequenceFinished() and self.CurAnim and self.CurAnim ~= "" and self.Animations[self.CurAnim .. "-loop"] then
				self:HandleAnimation(self.CurAnim .. "-loop")
			end
            return
        end
        
        if (onGround and ply:WaterLevel() <= 1) and not self.PreviousOnGround and self.Animations['land'] then
			self:HandleAnimation("land", self.LandHold)
        elseif not onGround and self.PreviousOnGround and self.Animations['jump'] then
			self:HandleAnimation("jump", self.JumpHold)
        end
		
        if self.HoldAnim > 0 and curtime < self.HoldAnim then
            return
        end
        
        self.PreviousOnGround = onGround

        if ((onGround or self:HandleGroundAnim()) and ply:WaterLevel() <= 1) and walkSpeed > 10 then
			if ply:Crouching() and speed >= crouchSpeed * 0.9 then
				if self.Animations['crouchmove'] then
					self:HandleAnimation("crouchmove")
					
				elseif self.Animations['walk'] then
					self:HandleAnimation("walk")
					
				elseif self.Animations['run'] then
					self:HandleAnimation("run")
					
				end
			elseif ply:Crouching() and speed <= crouchSpeed and self.Animations['crouch'] then
				self:HandleAnimation("crouch")
            elseif speed >= runSpeed * 0.9 and (walkSpeed ~= runSpeed or self:AlwaysRunning()) and self.Animations['run'] then
				self:HandleAnimation("run")
            elseif speed >= walkSpeed * 0.9 and speed > 5 or ply:Crouching() and speed >= crouchSpeed * 0.9 and self.Animations['walk'] then
				self:HandleAnimation("walk")
            elseif speed <= walkSpeed * 0.2 then
				self:HandleAnimation("idle")
            end
        else
            if (ply:GetVelocity().z ~= 0 and !OnGround) or ply:WaterLevel() > 1 and self.Animations['glide'] then
				self:HandleAnimation("glide")
            end
        end
    end
end

function SWEP:Holster( wep )
	return true
end

function SWEP:AlwaysRunning(  )
	return false
end

function SWEP:SetupAnimations()
end

function SWEP:Deploy()
    self.CurAnim = "deploy"
	
	self:AddAnimation("idle", nil, nil, true)
	self:AddAnimation("walk", nil, nil, true)
	self:AddAnimation("run", nil, nil, true)
	self:AddAnimation("glide", nil, nil, true)
	self:AddAnimation("jump", nil, nil, true)
	self:AddAnimation("land", nil, nil, true)
	self:AddAnimation("crouch", nil, nil, true)
	self:AddAnimation("crouchmove", nil, nil, true)
	
	self:SetupAnimations()
end

function SWEP:OnRemove()
end

function SWEP:Ammo1()
	-- Owner cannot have ammo? Such as NPCs.
	if ( !self:GetOwner().GetAmmoCount ) then return 0 end

	return self:GetOwner():GetAmmoCount( self:GetPrimaryAmmoType() )
end

function SWEP:Ammo2()
	-- Owner cannot have ammo? Such as NPCs.
	if ( !self:GetOwner().GetAmmoCount ) then return 0 end

	return self:GetOwner():GetAmmoCount( self:GetSecondaryAmmoType() )
end