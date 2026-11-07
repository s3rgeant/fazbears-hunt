AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.PrintName = "Travel Agent"

ENT.Speed = 1300

if SERVER then
	local function FindPath(startArea, goalArea)
		if not IsValid(startArea) or not IsValid(goalArea) then return nil end
		if startArea:GetID() == goalArea:GetID() then return { startArea } end

		local open = { startArea }
		local cameFrom = {}
		local gScore = { [startArea:GetID()] = 0 }
		local fScore = { [startArea:GetID()] = startArea:GetCenter():DistToSqr(goalArea:GetCenter()) }
		local closed = {}

		while #open > 0 do
			local bestIndex = 1
			local current = open[1]

			for i = 2, #open do
				if fScore[open[i]:GetID()] < fScore[current:GetID()] then current = open[i]; bestIndex = i end
			end

			table.remove(open, bestIndex)

			local currentID = current:GetID()
			if currentID == goalArea:GetID() then
				local path = { current }
				local id = currentID

				while cameFrom[id] do
					id = cameFrom[id]
					local area = navmesh.GetNavAreaByID(id)
					if not area then return nil end
					table.insert(path, 1, area)
				end

				return path
			end

			closed[currentID] = true

			for _, neighbor in ipairs(current:GetAdjacentAreas()) do
				local neighborID = neighbor:GetID()

				if not closed[neighborID] and not neighbor:IsBlocked(TEAM_ANY) then
					local currentCenter = current:GetCenter()
					local neighborCenter = neighbor:GetCenter()
					local tentativeG = gScore[currentID] + currentCenter:DistToSqr(neighborCenter)
					local ZDist = math.abs(currentCenter.z - neighborCenter.z)
					
					if neighborID ~= goalArea:GetID() and ZDist > 180 then
						debugoverlay.Axis( neighbor:GetCenter(), Angle(0,0,0), 100, 30, true ) 
						continue
					end

					if gScore[neighborID] == nil or tentativeG < gScore[neighborID] then
						cameFrom[neighborID] = currentID
						gScore[neighborID] = tentativeG
						fScore[neighborID] = tentativeG + neighborCenter:DistToSqr(goalArea:GetCenter())

						local exists = false

						for _, area in ipairs(open) do
							if area:GetID() == neighborID then exists = true break end
						end

						if not exists then table.insert(open, neighbor) end
					end
				end
			end
		end

		return nil
	end

	function ENT:Initialize()
		self:SetModel("models/props_junk/garbage_metalcan002a.mdl")
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_NONE)
		self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)

		self.Path = nil
		self.PathIndex = 1
		self.GoalArea = nil
		self.CurrentArea = nil
		self.TargetPoint = nil
		self.Finished = false
	end
	
	--function ENT:UpdateTransmitState()
		--return TRANSMIT_NEVER
	--end

	function ENT:SetGoalArea(goalArea)
		if not IsValid(goalArea) then return 0 end

		local currentArea = navmesh.GetNearestNavArea(self:GetPos(), false, 10000, false, true, TEAM_ANY)
		if not IsValid(currentArea) then return 0 end

		local path = FindPath(currentArea, goalArea)
		if not path then
			self.Path = nil
			self.GoalArea = nil
			self.TargetPoint = nil
			return 0
		end

		self.GoalArea = goalArea
		self.CurrentArea = currentArea
		self.Path = path
		self.PathIndex = 1
		self.Finished = false

		if #path > 1 then
			self.PathIndex = 2
			self.TargetPoint = path[2]:GetClosestPointOnArea(self:GetPos())
		else
			self.TargetPoint = goalArea:GetClosestPointOnArea(self:GetPos())
		end
		
		self.Speed = 1000

		return #path
	end

	function ENT:GetGoalArea()
		return self.GoalArea
	end

	function ENT:IsFinished()
		return self.Finished
	end
	
	function ENT:OnReachedGoal()
		self:Remove()
	end

	function ENT:Think()
		local owner = self:GetOwner()

		if self.Finished or not self.Path or not self.TargetPoint or not IsValid(owner) then
			self:NextThink(CurTime())
			return true
		end

		local pos = owner:GetPos()
		local target = self.TargetPoint
		local distance = pos:Distance(target)

		if distance <= 25 then
			if self.PathIndex >= #self.Path then
				self.Finished = true
				self.TargetPoint = nil

				local ent = owner:GetPillCostume()

				if IsValid(ent) then
					ent:Func("travelAgentEnded", owner, ent)
				end

				self:OnReachedGoal()
			else
				self.PathIndex = self.PathIndex + 1

				local nextArea = self.Path[self.PathIndex]
				self.CurrentArea = nextArea
				self.TargetPoint = nextArea:GetCenter()
			end
		end

		self:SetPos(owner:GetPos())
		self:NextThink(CurTime())
		return true
	end
end