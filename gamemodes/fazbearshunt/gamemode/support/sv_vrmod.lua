
if not vrmod then return end

local ENT = {}

ENT.Type = "anim"
ENT.Base = "base_anim"

function ENT:Initialize()
	--self:SetModel("models/props_farm/scenes/bananana_peel.mdl")
	self:SetNoDraw(true)
	self:DrawShadow(false)

	self:SetMoveType(MOVETYPE_NONE)

	self:SetSolid(SOLID_BBOX)
	self:SetCollisionBounds(Vector(-4, -4, -4), Vector(4, 4, 4))
	self:SetTrigger(true)
	self:SetNotSolid(true)
end

local function RunTouch(ent, other)
	local owner = ent:GetOwner()
	if not IsValid(owner) or not IsValid(other) then return end

	local velocity = ent.LastVelocity or vector_origin

	hook.Run("FHVR_TouchAction", owner, other, velocity, ent)
end

function ENT:StartTouch(other)
	RunTouch(self, other)
end

function ENT:Touch(other)
	--RunTouch(self, other)
end

scripted_ents.Register(ENT, "fh_vr_hand")



VR_HANDS_INV = VR_HANDS_INV or {}

local function RemoveHands(ply)
	local t = VR_HANDS_INV[ply]
	if not t then return end

	if IsValid(t.left) then
		t.left:Remove()
	end

	if IsValid(t.right) then
		t.right:Remove()
	end

	VR_HANDS_INV[ply] = nil
end

local function CreateHand(ply, hand)
	local ent = ents.Create("fh_vr_hand")
	if not IsValid(ent) then return end

	ent:SetOwner(ply)
	ent.Hand = hand
	ent:Spawn()

	return ent
end

hook.Add("VRMod_Start", "FHVR_CreateHands", function(ply)
	RemoveHands(ply)

	VR_HANDS_INV[ply] = {
		left = CreateHand(ply, "left"),
		right = CreateHand(ply, "right"),
	}
end)

hook.Add("VRMod_Exit", "FHVR_RemoveHands", RemoveHands)
hook.Add("PlayerDisconnected", "FHVR_RemoveHands", RemoveHands)

hook.Add("EntityRemoved", "FHVR_RemoveHands_Player", function(ent)
	if ent:IsPlayer() then
		RemoveHands(ent)
	end
end)

hook.Add("Tick", "FHVR_UpdateHands", function()
	for ply, hands in pairs(VR_HANDS_INV) do
		if not IsValid(ply) then
			RemoveHands(ply)
			continue
		end

		local function UpdateHand(ent, pos, ang)
			if not IsValid(ent) then return end

			local oldPos = ent:GetPos()

			ent:SetPos(pos)
			ent:SetAngles(ang)

			ent.LastVelocity = ((pos - oldPos) / engine.TickInterval()) - ply:GetVelocity()
		end

		local lPos, lAng = vrmod.GetLeftHandPose(ply)
		if lPos then
			UpdateHand(hands.left, lPos, lAng)
		end

		local rPos, rAng = vrmod.GetRightHandPose(ply)
		if rPos then
			UpdateHand(hands.right, rPos, rAng)
		end
	end
end)

hook.Add("PillApply", "VRMod_Hands", function(ply,ent)
	local pillName = ent:GetPillName()
	
	if pillName == "pill_springtrap" then
		hook.Add("FHVR_TouchAction", "springtrap", function(ply, ent, velocity, self)
			local speed = velocity:Length()
			
			if speed < 150 then return end
	
			if ply ~= ent and ent:IsPlayer() and not ent:IsAnimatronic() then
				ent:SetVelocity(velocity)
				ply:EmitSound("fnaf3/hit.mp3")
						
				local edata = EffectData()
				edata:SetOrigin(self:GetPos())
				edata:SetEntity(ent)
				util.Effect("BloodImpact", edata, true, true)
	
				local dmginfo = DamageInfo()
				dmginfo:SetAttacker(ply)
				dmginfo:SetInflictor(self)
				dmginfo:SetDamage(60)
				
				SuppressHostEvents(NULL)
				ent:TakeDamageInfo(dmginfo)
				SuppressHostEvents(ply)
			end
		end)
	end
end)

hook.Add("FHVR_TouchAction", "props", function(ply, ent, velocity, self)
	if not ply:IsAnimatronic() then return end

	if not ent:GetClass():StartWith("prop_") then return end

	local speed = velocity:Length()

	if speed < 100 then return end

	local dmg = DamageInfo()
	dmg:SetDamage(speed / 20)
	dmg:SetAttacker(ply)
	dmg:SetInflictor(ply)
	dmg:SetDamageForce(velocity)

	SuppressHostEvents(NULL)
	ent:TakeDamageInfo(dmg)
	SuppressHostEvents(ply)
end)

hook.Add("PillRestore", "VRMod_Hands", function(ply, ent)
	local pillName = ent:GetPillName()
	if pillName == "pill_springtrap" then
		hook.Remove("FHVR_TouchAction", "springtrap")
	end
end)

-- ПОДБИРАНИЕ ПЛЮШЕЙ У ЗОЛОТОГО ФРЕДДИ

hook.Add("VRMod_Pickup", "gfreddy_pickup_plushies", function(ply, ent)
	if outworld_victims[ply] and ent == "fh_plushie" then
		pickupPlushie(ply, ent)
	end
end)