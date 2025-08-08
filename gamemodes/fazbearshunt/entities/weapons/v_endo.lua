SWEP.PrintName = "Endo SWEP"

if CLIENT then
	local vfov = CreateClientConVar('fh_endo_fov', 100, true, false, 'Fov of Endo')
	SWEP.ViewModelFOV = vfov:GetFloat() or 100
    
    cvars.AddChangeCallback("fh_endo_fov", function(name, old_value, new_value)
		local wep = LocalPlayer():GetActiveWeapon()
		if IsValid(wep) and string.StartWith(wep:GetClass(), "v_") then
			wep.ViewModelFOV = tonumber(new_value) or 100
		end
    end)

end

SWEP.ViewModel = "models/speps/vm/endo02.mdl"
SWEP.WorldModel = ""
SWEP.UseHands = false
SWEP.DrawAmmo = false
SWEP.m_WeaponDeploySpeed = 1
SWEP.CurAnim = 'idle'
SWEP.PreviousOnGround = true
SWEP.HoldAnim = 0

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Ammo = "none"

local LAND_ANIM_DELAY = 0.2

function SWEP:Initialize()
	self.usedLayers = {}
end

function SWEP:Deploy()
	self.CurAnim = "deploy"
    return true
end

function SWEP:Holster()
    return true
end

function SWEP:PrimaryAttack()
    return true
end

function SWEP:SecondaryAttack()
    return true
end

function SWEP:Think()
    if SERVER then
        local ply = self.Owner
        local speed = ply:GetAbsVelocity():Length()
        local onGround = ply:OnGround()
        local runSpeed = ply:GetRunSpeed()
        local walkSpeed = ply:GetWalkSpeed()
        local crouchSpeed = ply:GetCrouchedWalkSpeed()
		
        if self.HoldAnim > 0 and CurTime() < self.HoldAnim then
            return
        end
        
        if (onGround and ply:WaterLevel() <= 1) and not self.PreviousOnGround then
            if self.CurAnim ~= 'land' then
                self.Weapon:SendWeaponAnim(ACT_LAND)
                self.CurAnim = 'land'
				self.HoldAnim = CurTime() + LAND_ANIM_DELAY
				return
            end
        elseif not onGround and self.PreviousOnGround then
            if self.CurAnim ~= 'jump' then
                self.Weapon:SendWeaponAnim(ACT_JUMP)
                self.CurAnim = 'jump'
            end
        end
        
        self.PreviousOnGround = onGround

        if (onGround and ply:WaterLevel() <= 1) and walkSpeed > 10 then
			if ply:Crouching() and speed >= crouchSpeed * 0.9 then
                if self.CurAnim ~= 'crouchmove' then
                    self.Weapon:SendWeaponAnim(ACT_WALK_CROUCH)
                    self.CurAnim = 'crouchmove'
                end
			elseif ply:Crouching() and speed <= crouchSpeed then
                if self.CurAnim ~= 'crouch' then
                    self.Weapon:SendWeaponAnim(ACT_CROUCH)
                    self.CurAnim = 'crouch'
                end
            elseif speed >= runSpeed * 0.9 then
                if self.CurAnim ~= 'run' then
                    self.Weapon:SendWeaponAnim(ACT_VM_SPRINT_IDLE)
                    self.CurAnim = 'run'
                end
            elseif speed >= walkSpeed * 0.9 and speed > 5 then
                if self.CurAnim ~= 'walk' then
                    self.Weapon:SendWeaponAnim(ACT_WALK)
                    self.CurAnim = 'walk'
                end
            elseif speed <= walkSpeed * 0.5 and self.CurAnim ~= 'idle' and self.CurAnim != 'land' then
                self.Weapon:SendWeaponAnim(ACT_IDLE)
                self.CurAnim = 'idle'
            end
        else
            if ply:GetVelocity().z < 0 or ply:WaterLevel() > 1 then
                if self.CurAnim ~= 'glide' then
                    self.Weapon:SendWeaponAnim(ACT_GLIDE)
                    self.CurAnim = 'glide'
                end
            end
        end
    end

    return self.BaseClass.Think and self.BaseClass.Think(self)
end

function SWEP:PlayCustomAnimation(anim, hold)
    if not self or not IsValid(self) then return end
    
    local animMap = {
        ["ACT_MELEE_ATTACK1"] = ACT_MELEE_ATTACK1,
        ["ACT_SPECIAL_ATTACK1"] = ACT_SPECIAL_ATTACK1,
    }
    
    local act = animMap[anim]
    if act then
        self:SendWeaponAnim(act)
        self.CurAnim = anim
		self.HoldAnim = CurTime() + hold
    else
        print("Хуй его знает: ", anim)
    end
end