ENT.Type = "point"
ENT.Base = "base_point"

local CHECK_INTERVAL = 0.05
local TELEPORT_COOLDOWN = 0.25

function ENT:Initialize()
	self:SetNoDraw(true)
	self:DrawShadow(false)

	self:SetSolid(SOLID_NONE)
	self:SetMoveType(MOVETYPE_NONE)
	self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)

	self.NextTeleportTime = 0
end

-- Проверяет, находится ли мировая точка внутри brush-энтити.
local function IsPointInsideEntity(ent, worldPosition)
	if not IsValid(ent) then return false end

	local localPosition = ent:WorldToLocal(worldPosition)
	local mins = ent:OBBMins()
	local maxs = ent:OBBMaxs()

	return localPosition.x >= mins.x
		and localPosition.x <= maxs.x
		and localPosition.y >= mins.y
		and localPosition.y <= maxs.y
		and localPosition.z >= mins.z
		and localPosition.z <= maxs.z
end

local function IsTriggerEnabled(trigger)
	local disabled = trigger:GetInternalVariable("m_bDisabled")

	return disabled ~= true and disabled ~= 1
end

local function GetTeleportDestination(trigger)
	if not IsValid(trigger) then return NULL end

	local targetName = trigger:GetInternalVariable("target")

	if not isstring(targetName) or targetName == "" then
		local keyValues = trigger:GetKeyValues()
		targetName = keyValues.target
	end

	if not isstring(targetName) or targetName == "" then
		return NULL
	end

	local destinations = ents.FindByName(targetName)

	for _, destination in ipairs(destinations) do
		if IsValid(destination) then
			return destination
		end
	end

	return NULL
end

function ENT:TeleportOwner(trigger)
	local owner = self:GetOwner()

	if not IsValid(owner) then return false end
	if CurTime() < self.NextTeleportTime then return false end

	local destination = GetTeleportDestination(trigger)

	if not IsValid(destination) then
		return false
	end

	self.NextTeleportTime = CurTime() + TELEPORT_COOLDOWN

	local destinationPosition = destination:GetPos()
	local destinationAngles = destination:GetAngles()

	owner:SetPos(destinationPosition)

	if owner:IsPlayer() then
		owner:SetLocalVelocity(vector_origin)
		owner:SetEyeAngles(destinationAngles)
	end

	self:SetPos(owner:WorldSpaceCenter())

	trigger:Fire("OnStartTouch", "", 0, owner, self)

	return true
end

function ENT:CheckTeleportTriggers()
	local owner = self:GetOwner()

	if not IsValid(owner) then
		self:Remove()
		return
	end

	local position = owner:WorldSpaceCenter()

	self:SetPos(position)
	
	if self.TeleportCond and self.TeleportCond(owner, self) == false then
		return
	end

	for _, trigger in ipairs(ents.FindByClass("trigger_teleport")) do
		if not IsValid(trigger) then continue end
		if not IsTriggerEnabled(trigger) then continue end
		if not IsPointInsideEntity(trigger, position) then continue end

		if self:TeleportOwner(trigger) then
			break
		end
	end
end

function ENT:Think()
	self:CheckTeleportTriggers()

	self:NextThink(CurTime() + CHECK_INTERVAL)
	return true
end