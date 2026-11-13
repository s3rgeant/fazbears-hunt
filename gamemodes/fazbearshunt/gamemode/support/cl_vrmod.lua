

local allHandsData = {
	["pill_wfreddy2"] = {model = "models/vr/vm/OldFreddy.mdl", fingerJoints = 2, 
						leftOffset = Angle(-90, 180, 90), 
						rightOffset = Angle(-90, 0, -90)
	},
	["pill_springtrap"] = {model = "models/vr/vm/Springtrap.mdl", fingerJoints = 3,
						leftOffset = Angle(-90, 180, 90), 
						rightOffset = Angle(90, -90, 0)
	},
}

function VR_RegisterHands(pillName, modelPath, fingerJointCount)
	if allHandsData[pillName] then return end -- already exists, no override
	
	allHandsData[pillName] = {
		model = modelPath or "",
		fingerJoints = fingerJointCount or 3,
	}
end

local currentData = ""

if not vrmod then return end

handsModel = handsModel or nil
local boneinfo = {}
local leftHandBone, rightHandBone = -1, -1
local fingerboneids = {}
local frame = 0

local function SetupCustomHands(ply, ent)
	if not IsValid(ent) then return end
	
	local pillName = ent:GetPillName()
	if not allHandsData[pillName] then return end
	
	currentData = pillName
	local modelPath = allHandsData[pillName].model

	if IsValid(handsModel) then handsModel:Remove() end

	handsModel = ClientsideModel(modelPath)
	if not IsValid(handsModel) then
		print("[VR Hands] Не удалось создать модель OldFreddy!")
		return
	end

	handsModel:SetupBones()
	handsModel:SetRenderBounds(Vector(-65000), Vector(65000))

	leftHandBone = handsModel:LookupBone("bip_hand_L") or handsModel:LookupBone("ValveBiped.Bip01_L_Hand")
	rightHandBone = handsModel:LookupBone("bip_hand_R") or handsModel:LookupBone("ValveBiped.Bip01_R_Hand")

	fingerboneids = {}
	for i = 0, handsModel:GetBoneCount() - 1 do
		local name = handsModel:GetBoneName(i):lower()
		if name:find("finger") or name:find("thumb") or name:find("pinky") or
		   name:find("index") or name:find("middle") or name:find("ring") then
			table.insert(fingerboneids, i)
		end
	end

	boneinfo = {}
	local boneCount = handsModel:GetBoneCount()
	local zeroVec, zeroAng = Vector(), Angle()

	for i = 0, boneCount - 1 do
		local parent = handsModel:GetBoneParent(i)
		local mtx = handsModel:GetBoneMatrix(i) or Matrix()
		local pmtx = parent ~= -1 and handsModel:GetBoneMatrix(parent) or mtx

		local relPos, relAng = WorldToLocal(mtx:GetTranslation(), mtx:GetAngles(), pmtx:GetTranslation(), pmtx:GetAngles())

		boneinfo[i] = {
			parent = parent,
			relativePos = relPos,
			relativeAng = relAng,
			offsetAng = zeroAng,
			pos = zeroVec,
			ang = zeroAng,
			overridePos = nil,
			overrideAng = nil,
			targetMatrix = mtx
		}
	end

	print("[VR Hands] OldFreddy загружен! Кисти L:"..leftHandBone.." R:"..rightHandBone.." | Пальцев: "..#fingerboneids)

	-- === BuildBonePositions — главное волшебство ===
	handsModel:AddCallback("BuildBonePositions", function(handsEnt, numbones)
		if frame == FrameNumber() then return end
		frame = FrameNumber()
		
		if not allHandsData[currentData] then return end

		local netFrame = g_VR.net[LocalPlayer():SteamID()] and g_VR.net[LocalPlayer():SteamID()].lerpedFrame
		if not netFrame then return end

		local leftOffset = allHandsData[currentData].leftOffset
		local rightOffset = allHandsData[currentData].rightOffset

		if leftHandBone ~= -1 and netFrame.lefthandPos then
			boneinfo[leftHandBone].overridePos = netFrame.lefthandPos
			local _, finalLeftAng = LocalToWorld(Vector(0,0,0), leftOffset, netFrame.lefthandPos, netFrame.lefthandAng)
			boneinfo[leftHandBone].overrideAng = finalLeftAng
		end

		if rightHandBone ~= -1 and netFrame.righthandPos then
			boneinfo[rightHandBone].overridePos = netFrame.righthandPos
			local _, finalRightAng = LocalToWorld(Vector(0,0,0), rightOffset, netFrame.righthandPos, netFrame.righthandAng)
			boneinfo[rightHandBone].overrideAng = finalRightAng
		end
			

		for k, boneid in ipairs(fingerboneids) do
			if boneinfo[boneid] then
				local fCount = allHandsData[currentData].fingerJoints or 3
				local fingerIdx

				if fCount == 3 then
					fingerIdx = math.floor((k - 1) / 3) + 1
				else
					fingerIdx = math.floor((k - 1) / (fCount + 1)) + 1

					if (k - 1) % (fCount + 1) >= fCount then
						continue
					end
				end

				local flex = netFrame["finger"..fingerIdx] or 0.3
				boneinfo[boneid].offsetAng = LerpAngle(flex, angle_zero, Angle(0, 0, -75))
			end
		end

		for i = 0, boneCount - 1 do
			local info = boneinfo[i]
			local parentInfo = boneinfo[info.parent] or info

			local wpos, wang = LocalToWorld(
				info.relativePos,
				info.relativeAng + info.offsetAng,
				parentInfo.pos,
				parentInfo.ang
			)

			wpos = info.overridePos or wpos
			wang = info.overrideAng or wang

			local mat = Matrix()
			mat:Translate(wpos)
			mat:Rotate(wang)

			info.targetMatrix = mat
			info.pos = wpos
			info.ang = wang
		end

		for i = 0, boneCount - 1 do
			if handsEnt:GetBoneMatrix(i) then
				handsEnt:SetBoneMatrix(i, boneinfo[i].targetMatrix)
			end
		end
	end)
end

hook.Add("PillApply", "vr_fh_hands", function(ply, ent)
	if ply ~= LocalPlayer() then return end
	if not vrmod.IsPlayerInVR(ply) then return end

	timer.Simple(0.1, function() SetupCustomHands(ply, ent) end)
end)

hook.Add("PillRestore", "vr_fh_cleanup", function()
	if IsValid(handsModel) then
		handsModel:Remove()
		handsModel = nil
	end
end)

hook.Add("VRMod_PreRender", "vr_fh_render", function()
	if IsValid(handsModel) then
		handsModel:SetPos(LocalPlayer():GetPos()) -- для освещения
		handsModel:DrawModel()
	end
end)

hook.Add("VRMod_PreRenderRight", "vr_fh_render", function()
	if IsValid(handsModel) then
		handsModel:DrawModel()
	end
end)

hook.Add("VRMod_Start", "vr_fh_cleanup", function()
	local ply = LocalPlayer()
	
	if not IsValid(ply) then return end
	local ent = ply:GetPillCostume()
	if not IsValid(ent) then return end
	
	timer.Simple(0.1, function() SetupCustomHands(ply, ent) end)
end)

hook.Add("VRMod_Exit", "vr_fh_cleanup", function()
	if IsValid(handsModel) then
		handsModel:Remove()
		handsModel = nil
	end
end)