AddCSLuaFile()

SWEP.PrintName = "#weapon_taser"
if CLIENT then
	SWEP.WepSelectIcon = surface.GetTextureID( "weapons/taser" )
end
SWEP.DrawWeaponInfoBox = false

SWEP.Gifted = true

SWEP.Spawnable = true
SWEP.Slot = 1
SWEP.SlotPos = 2

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

SWEP.UseHands = true
SWEP.ViewModel	= "models/fh/weapons/c_taser.mdl"
SWEP.ViewModelFOV = 65
SWEP.WorldModel = "models/realistic_police/taser/w_taser.mdl"

function SWEP:SetupDataTables()
	self:NetworkVar( "Float", 1, "NextIdle" )
end

function SWEP:Think()
    if self:GetNextIdle() > 0 and CurTime() >= self:GetNextIdle() then
        self:SendWeaponAnim(ACT_VM_IDLE)
        self:SetNextIdle(0)
    end
	
	if true then return end
	
	local owner = self:GetOwner()
	
	if not owner:IsValid() then return end
	
	local vel = owner:GetVelocity()
	local speed = vel:Length()
	
	local vm = owner:GetViewModel()
	
	if not vm:IsValid() then return end
	vm:SetPoseParameter("move_speed", speed)
end

function SWEP:Initialize()
    self:SetHoldType("pistol")
	self.Weapon:SetClip1( 100 )
    self:SetNextIdle(CurTime() + 1)
end

function SWEP:Holster()
	return true
end

if SERVER then
    util.AddNetworkString("StunEffect_Shake")
end

local mins = Vector(-10,-10,-10)
local maxs = Vector(10,10,10)
function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    if !IsValid(owner) then return end
	
	if self:Clip1() < 100 then return end
	
	local ct = CurTime()
	
    self:SetNextIdle(ct + 1)
	
	self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
	
	owner:LagCompensation(true)

    local shootPos = owner:GetShootPos()
    local aimDir = owner:GetAimVector()
    local endPos = shootPos + aimDir * 600

    local tr = util.TraceLine({
		start = shootPos,
		endpos = endPos,
		filter = function(ent)
			return ent ~= owner and (ent:IsPlayer() and ent:Team() ~= owner:Team())
		end
	})
	
	if not IsValid(tr.Entity) then
		tr = util.TraceHull({
			start = shootPos,
			endpos = endPos,
			mins = mins,
			maxs = maxs,
			mask = MASK_SHOT_HULL,
			filter = function(ent)
				return ent ~= owner and (ent:IsPlayer() and ent:Team() ~= owner:Team())
			end
		})
	end
	
	local target = tr.Entity
	
	local wait = 25
	if SERVER then
		if target:IsPlayer() and target:IsAnimatronic() then
			if target:Alive() and not target.tasered and not target.lobbyFreeze then
				wait = 65
				TaseAnimatronic(target, owner)
				stats.Add(owner, "tasered", 1)
			end
		end
		
		timer.Create("taser" .. owner:EntIndex(), wait / 100, 100, function()
			if IsValid(self) and self:Clip1() < 100 then
				self:SetClip1( self:Clip1() + 1 )
			end
		end)
	end

    self:EmitSound('weapons/tasergun/shoot.mp3')
    local hitPos = tr.HitPos or endPos

    local fx = EffectData()
    fx:SetOrigin(hitPos + Vector(0, 0, 5))
	fx:SetStart(hitPos)
	util.Effect("cball_explode", fx)

	owner:LagCompensation(false)
	self:SetClip1( 0 )
	
	owner:SetAnimation(PLAYER_ATTACK1)
	
	if CLIENT then
		local dlight = DynamicLight( owner:EntIndex() )
		if ( dlight ) then
			dlight.pos = tr.HitPos
			dlight.r = 255
			dlight.g = 255
			dlight.b = 255
			dlight.brightness = 2
			dlight.decay = 450
			dlight.size = 256
			dlight.dietime = ct + 3
		end
	end
	
	self:SetNextPrimaryFire(ct + wait)
end

function SWEP:SecondaryAttack()
	self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
	
    local vm = self:GetOwner():GetViewModel()
    if IsValid(vm) then
        local seq = vm:SelectWeightedSequence(ACT_VM_SECONDARYATTACK)
        local dur = vm:SequenceDuration(seq)

        self:SetNextIdle(CurTime() + dur)
		self:SetNextSecondaryFire(CurTime() + dur)
    end
end

local data = {}
local clrW = Color(255,255,255,128)
local clrB = Color(0,0,0,250)
function TaseAnimatronic(ply, taserer)
	local ent = pills.getMappedEnt(ply)
	
	if !IsValid(ent) then return end
	
	if hook.Run("FH_HandleTaserHit", ply, ent, taserer) == false then return end
	
	local formtbl = ent.formTable
	local movespeed = formtbl.moveSpeed
	
	if !formtbl or !movespeed then return end
	
	if SERVER then
		ply.tasered = true
		ply:DropToFloor()
		
		if IsValid(ent) then
			local stunTimer = "TaserStun" .. ply:EntIndex()
			
			data.timerName = stunTimer
			data.taserer = taserer
			
			local taserHandler = ent:Func("taserStun", ply, ent, data)
			
			if not taserHandler ~= false then
				ply:Freeze(true)
				timer.Create(stunTimer, 5, 1, function()
					if IsValid(ply) then
						ply:Freeze(false) 
						ply.tasered = false
					end
				end)
				playVoiceline(killers.GetName(formtbl.name), 'tasered', ply, 0.05)
				
				if ply.jumpscaring then
					local poorguy = ply.jumpscaring
					
					poorguy:Freeze(false)
					poorguy:SetJumpscared(false)
					
					ply.jumpscaring = nil
				end
				
				if formtbl == "pill_endo02" then
					endoRelease(ply)
				end
				
				ent:PillAnim("stun", true)
				ent:SetUseForceAngles(false)
				timer.Remove("FH_JumpscareKill_" .. ply:EntIndex())
			end
			ent:EmitSound('weapons/tasergun/active_stun.mp3')
		end
	
		net.Start("StunEffect_Shake")
		net.Send(ply)
		
		local clr = ply:GetInfoNum("fh_dark_blindness", 1) == 1 and clrB or clrW
		
		ply:ScreenFade(SCREENFADE.IN, clr, 2, 2)
	end
	
	if !IsValid(ent) then
		ent = ply
	end
	
	local fx = EffectData()
	fx:SetOrigin(ply:GetPos() + Vector(0, 0, 40))
	fx:SetStart(ply:GetPos())
	fx:SetMagnitude(10)
	fx:SetEntity(ent)
	util.Effect("teslaHitBoxes", fx, true, true)
	
	hook.Run("SuccessTaserHit", ply, ent, taserer)
end

hook.Add( "PlayerShouldTakeDamage", "fh_tasered_cant_deal_damage", function( ply, attacker )
	if attacker.tasered then
		return false
	end
end )

hook.Add( "DoPlayerDeath", "fh_taser_drop", function( ply, attacker )
	if ply:HasWeapon("weapon_taser") then
		ply:DropWeapon(ply:GetWeapon("weapon_taser"))
		ply:SetActiveWeapon(nil)
	end
end )

if SERVER then return end

local red = Color(255,0,0,255)
local green = Color(0,255,0,255)
local tlines = Material("models/fh/weapons/taser_lines.vtf")

function SWEP:CalcViewModelView(vm, weapon, ply)
	--return Vector(0,0,0), Angle(0,0,0)
end

function SWEP:PostDrawViewModel(vm, weapon, ply)
	local bone = vm:LookupBone("t.base")
	if not bone then return end
	
	local pos, ang = vm:GetBonePosition(bone)
	if not pos then return end

	ang:RotateAroundAxis(ang:Right(), 90)
	ang:RotateAroundAxis(ang:Up(), 90)
	ang:RotateAroundAxis(-ang:Right(), 90)
	
	local progress = math.max( 3, self:Clip1() )
	local targetColor = progress < 100 and red or green
	local cheeseClr = progress < 100 and color_black or color_white

	cam.Start3D2D(pos + ang:Up() * -0.69 + ang:Forward() * 2.46, ang, 0.02)
		surface.SetDrawColor(targetColor.r, targetColor.g, targetColor.b, 255)
		surface.DrawRect(25, 20, 15, -progress /2.38)
		
		surface.SetDrawColor(cheeseClr.r, cheeseClr.g, cheeseClr.b, math.abs(math.cos(CurTime() * 2)) * 100)
		surface.DrawRect(25, 20, 15, -progress /2.38)
	cam.End3D2D()

	cam.Start3D2D(pos + ang:Up() * -0.7 + ang:Forward() * 2.46, ang, 0.02)
		surface.SetMaterial(tlines)
		surface.SetDrawColor(color_white)
		surface.DrawTexturedRect(25, 20, 18, -45)
	cam.End3D2D()
end

net.Receive("StunEffect_Shake", function()
    local ply = LocalPlayer()
    util.ScreenShake(ply:GetPos(), 15, 5, 5, 500)
end)