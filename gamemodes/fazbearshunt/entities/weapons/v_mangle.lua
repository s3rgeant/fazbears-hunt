SWEP.PrintName = "Mangle SWEP"

if CLIENT then
	local vfov = CreateClientConVar('cl_fov_mangle', 95, true, false, 'Fov of Mangle')
	SWEP.ViewModelFOV = vfov:GetFloat() or 95
    
    cvars.AddChangeCallback("cl_fov_mangle", function(name, old_value, new_value)
		local wep = LocalPlayer():GetActiveWeapon()
		if IsValid(wep) and string.StartWith(wep:GetClass(), "v_") then
			wep.ViewModelFOV = tonumber(new_value) or 95
		end
    end)

end

SWEP.ViewModel = "models/ufmp/fnaf2/toys/vm/themangle.mdl"
SWEP.WorldModel = ""
SWEP.UseHands = false
SWEP.DrawAmmo = false
SWEP.m_WeaponDeploySpeed = 0.7
SWEP.CurAnim = 'idle'
SWEP.PreviousOnGround = true
SWEP.HoldAnim = 0

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Ammo = "none"

local LAND_ANIM_DELAY = 0.4
local JUMP_ANIM_DELAY = 0.3

function SWEP:SetupDataTables()
	self:NetworkVar( "Float", 1, "NextIdle" )
end

function SWEP:Deploy()
	--self.CurAnim = "deploy"
    self:SetNextIdle(1)
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
		
		local curtime = CurTime()
		
        if self.HoldAnim > 0 and curtime < self.HoldAnim then
            return
        end
	
		if self:GetNextIdle() > 0 and curtime >= self:GetNextIdle() then
			self:SendWeaponAnim(ACT_IDLE)
			self:SetNextIdle(0)
		end
        
        if (onGround and ply:WaterLevel() <= 1) and not self.PreviousOnGround then
            if self.CurAnim ~= 'land' then
                self.Weapon:SendWeaponAnim(ACT_LAND)
                self.CurAnim = 'land'
				self.HoldAnim = curtime + LAND_ANIM_DELAY
				self:SetNextIdle(1)
				return
            end
        elseif not onGround and self.PreviousOnGround then
            if self.CurAnim ~= 'jump' then
                self.Weapon:SendWeaponAnim(ACT_JUMP)
				self.HoldAnim = curtime + JUMP_ANIM_DELAY
                self.CurAnim = 'jump'
				return
            end
        end
        
        self.PreviousOnGround = onGround

        if ((onGround or ply:GetNWBool("_MangleHooked")) and ply:WaterLevel() <= 1) and walkSpeed > 10 then
			if speed >= runSpeed * 0.9 and walkSpeed != runSpeed then
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
            if (ply:GetVelocity().z ~= 0 and !OnGround) or ply:WaterLevel() > 1 then
                if self.CurAnim ~= 'glide' then
                    self.Weapon:SendWeaponAnim(ACT_GLIDE)
                    self.CurAnim = 'glide'
                end
            end
        end
    end

    return self.BaseClass.Think and self.BaseClass.Think(self)
end

local lastmangle_CL_viewoffset = nil
function SWEP:CalcViewModelView( vm, oldpos, oldangles, pos, angles )
	local ply = self.Owner
	if !lastmangle_CL_viewoffset then
		lastmangle_CL_viewoffset = ply:GetCurrentViewOffset()
	end
	
	local plypos = ply:GetPos()
	
	lastmangle_CL_viewoffset = LerpVector(FrameTime() * 10, lastmangle_CL_viewoffset, ply:GetCurrentViewOffset())

	return plypos + lastmangle_CL_viewoffset, angles
end

function SWEP:PlayCustomAnimation(anim, hold)
    if not self or not IsValid(self) then return end
    
    local animMap = {
        ["ACT_MELEE_ATTACK1"] = ACT_MELEE_ATTACK1,
        ["ACT_SPECIAL_ATTACK1"] = ACT_SPECIAL_ATTACK1,
        ["ACT_VM_DEPLOY"] = ACT_VM_DEPLOY,
        ["ACT_VM_DRAW"] = ACT_VM_DRAW,
        ["ACT_IDLE"] = ACT_IDLE,
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