SWEP.Name					=  "Empty Hands"
SWEP.HoldType				=  "normal"
SWEP.Category				=  "Other"

SWEP.Spawnable				=  true
SWEP.AdminSpawnable			=  true

SWEP.Primary.Automatic		=  true

SWEP.Weight = 5

function SWEP:CanPrimaryAttack()
	return true
end

function SWEP:CanSecondaryAttack()
	return true
end

function SWEP:Initialize()
	self:SetHoldType( self.HoldType )
	
	self.Time = 0
	self.Range = 120
end

function SWEP:PrimaryAttack()
	local ply = self.Owner
	local Pos = ply:GetShootPos()
	local Aim = ply:GetAimVector()

	local Tr = util.TraceLine{
		start = Pos,
		endpos = Pos + Aim * self.Range,
		filter = player.GetAll(),
	}

	local HitEnt = Tr.Entity
	
	if self.Drag then
		HitEnt = self.Drag.Entity
	else
		if !IsValid(HitEnt) or HitEnt:GetMoveType() ~= MOVETYPE_VPHYSICS or
			HitEnt:IsVehicle() or HitEnt:GetNWBool("NoDrag", false) or
			HitEnt.BlockDrag ~= nil or
			IsValid(HitEnt:GetParent()) then
			return
		end
		
		if HitEnt:GetVelocity():Length2D() > 100 then
			return
		end
		
		if SERVER and HitEnt:IsPlayerHolding() then
			return
		end

		local Phys = HitEnt:GetPhysicsObject()
		if not IsValid(Phys) then return end
		
		if ply:GetGroundEntity() == HitEnt then
			return
		end

		self.Drag = {
			OffPos = HitEnt:WorldToLocal(Tr.HitPos),
			Entity = HitEnt,
			Fraction = Tr.Fraction,
		}
		HitEnt.IsBeingDragged = true
	end

	if CLIENT or not IsValid(HitEnt) then return end

	local Phys = HitEnt:GetPhysicsObject()
	if IsValid(Phys) then
		local Pos2 = Pos + Aim * self.Range * self.Drag.Fraction
		local OffPos = HitEnt:LocalToWorld(self.Drag.OffPos)
		local Dif = Pos2 - OffPos

		local mass = Phys:GetMass()
		local forceMult = math.max(10, 500 - mass)

		if ply:GetGroundEntity() == HitEnt then
			hook.Run("OnPlayerPhysicsDrop", ply, self.Drag.Entity, false)
			self.Drag = nil
			return
		end

		local Nom = (Dif:GetNormal() * math.min(1, Dif:Length() / 100) * forceMult - Phys:GetVelocity()) * mass
		Phys:ApplyForceOffset(Nom, OffPos)
		Phys:AddAngleVelocity(-Phys:GetAngleVelocity() / 4)
	end
end

function SWEP:SecondaryAttack()
	if not IsFirstTimePredicted() then return end

	if game.SinglePlayer() then
		self:SetShouldDrawCrosshair( not self:GetShouldDrawCrosshair() )
	elseif CLIENT then
		self.CrosshairPredicted = not self.CrosshairPredicted
	end

	self:SetNextSecondaryFire( CurTime() + 0.25 )

	return true
end

function SWEP:SetupDataTables( )
	self:NetworkVar( "Bool", 0, "IsDeployed" )
	self:NetworkVar( "Bool", 1, "ShouldDrawCrosshair" )
end

function SWEP:Think()
    local ply = self.Owner
    if self.Drag and (not ply:KeyDown(IN_ATTACK) or not IsValid(self.Drag.Entity)) then
        if IsValid(self.Drag.Entity) then
            self.Drag.Entity.IsBeingDragged = nil
			hook.Run("OnPlayerPhysicsDrop", ply, self.Drag.Entity, false)
        end
        self.Drag = nil
    end
end

function SWEP:ShouldDrawViewModel()
	return false
end

function SWEP:DrawWorldModel()
end

hook.Add("EntityTakeDamage", "prevent_empty_hands_prop_damage", function(ent, dmg)
    local inflictor = dmg:GetInflictor()

    if IsValid(inflictor) and inflictor.IsBeingDragged then
        dmg:SetDamage(0)
        dmg:ScaleDamage(0)
        return true
    end
end)

if CLIENT then
	local x, y = ScrW() /2, ScrH() /2
	local MainCol = Color( 255, 255, 255, 255 )
	local Col = Color( 255, 255, 255, 255 )

	function SWEP:DrawHUD()
		if IsValid( self.Owner:GetVehicle() ) then return end
		local Pos = self.Owner:GetShootPos()
		local Aim = self.Owner:GetAimVector()

		local Tr = util.TraceLine{
			start = Pos,
			endpos = Pos +Aim *self.Range,
			filter = player.GetAll(),
		}

		local HitEnt = Tr.Entity
		if IsValid( HitEnt ) and HitEnt:GetMoveType() == MOVETYPE_VPHYSICS and
			not self.rDag and
			not HitEnt:IsVehicle() and
			not IsValid( HitEnt:GetParent() ) and
			not HitEnt:GetNWBool( "NoDrag", false ) then

			self.Time = math.min( 1, self.Time +2 *FrameTime() )
		else
			self.Time = math.max( 0, self.Time -2 *FrameTime() )
		end

		if self.Time > 0 then
			Col.a = MainCol.a *self.Time

			draw.SimpleText(
				"Drag",
				"DermaLarge",
				x,
				y,
				Col,
				TEXT_ALIGN_CENTER
			)
		end

		if self.Drag and IsValid( self.Drag.Entity ) then
			local Pos2 = Pos +Aim *100 *self.Drag.Fraction
			local OffPos = self.Drag.Entity:LocalToWorld( self.Drag.OffPos )
			local Dif = Pos2 -OffPos

			local A = OffPos:ToScreen()
			local B = Pos2:ToScreen()

			surface.DrawRect( A.x -2, A.y -2, 4, 4, MainCol )
			surface.DrawRect( B.x -2, B.y -2, 4, 4, MainCol )
			surface.DrawLine( A.x, A.y, B.x, B.y, MainCol )
		end
	end
end