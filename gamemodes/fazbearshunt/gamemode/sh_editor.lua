if SERVER then
	util.AddNetworkString("fh_client_asks_editor")

	net.Receive("fh_client_asks_editor", function(len, ply)
		if !ply:IsSuperAdmin() then return end

		ply:StripWeapons()
		ply:Spectate(OBS_MODE_ROAMING)
		ply:SetTeam(TEAM_EDITOR)
	end)
end

--[[
	я нихуя не доделал ещё. хули ты смотришь?
]]--

local currentSpeed = 250
local baseSpeed = 300
local maxSpeed = 1500
local accel = 1500
local shiftAccel = 6000
local shiftMax = 3000

hook.Add("Move", "FH_EditorNoclip", function(ply, mv)
	if ply:Team() ~= TEAM_EDITOR then return end

	local ft = FrameTime()
	local isMoving = mv:GetForwardSpeed() ~= 0 or mv:GetSideSpeed() ~= 0 or mv:GetUpSpeed() ~= 0
	local isShift = mv:KeyDown(IN_SPEED)

	local targetMax = isShift and shiftMax or maxSpeed
	local targetAccel = isShift and shiftAccel or accel

	-- разгоняемся, если движемся
	if isMoving then
		currentSpeed = math.min(currentSpeed + targetAccel * ft, targetMax)
	else
		currentSpeed = math.max(currentSpeed - targetAccel * 2 * ft, baseSpeed)
	end

	local ang = mv:GetMoveAngles()
	local pos = mv:GetOrigin()
	local dir = Vector(0, 0, 0)

	dir = dir + ang:Forward() * (mv:GetForwardSpeed() / 100)
	dir = dir + ang:Right() * (mv:GetSideSpeed() / 100)
	dir = dir + ang:Up() * (mv:GetUpSpeed() / 100)

	if dir:IsZero() then
		mv:SetVelocity(Vector(0, 0, 0))
		currentSpeed = 250
		return true
	end

	dir:Normalize()

	local vel = dir * currentSpeed
	pos = pos + vel * ft

	mv:SetVelocity(vel)
	mv:SetOrigin(pos)

	--debugoverlay.Text(pos, ("Speed: %.1f"):format(currentSpeed), 0.05)

	return true
end)

if CLIENT then

	local function InEditor()
		return (LocalPlayer() and LocalPlayer():Team() == TEAM_EDITOR)
	end

	local placedPositions = {}
	local placingEntity = nil
	local addAng = 0

	local placedEntities = {}
	local lastRotateTime = 0

	function RemoveAllPlacedEntities()
		for _, ent in ipairs(placedEntities) do
			if IsValid(ent) then
				ent:Remove()
			end
		end
		table.Empty(placedEntities)
	end

	local function createSpringDancePos(pos, ang)
		if IsValid(placingEntity) then placingEntity:Remove() end

		local ent = ClientsideModel("models/editor/playerstart.mdl")
		ent:SetPos(pos)
		ent:SetAngles(ang)
		ent:Spawn()

		table.insert(placedEntities, ent)
	end

	local function createEditableSpringtrapDancePos()
		if IsValid(placingEntity) then placingEntity:Remove() end

		local trace = LocalPlayer():GetEyeTrace()
		local ent = ClientsideModel("models/editor/playerstart.mdl")
		ent:SetPos(trace.HitPos)
		ent:SetAngles(Angle(0, 0, 0))
		ent:Spawn()
		ent:SetModelScale(1)
		ent:SetColor(Color(0, 255, 0))
		ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
		ent:SetMaterial("models/wireframe")

		placingEntity = ent
		gui.EnableScreenClicker(false)
		editorButtons()
	end

	local fh_editor_menu = nil
	function editorButtons()
		if fh_editor_menu then
			fh_editor_menu:Remove()
			fh_editor_menu = nil
			gui.EnableScreenClicker( false )
			return
		end
		fh_editor_menu = vgui.Create( "DPanel" )
		fh_editor_menu:SetPos( 0, 20 )
		fh_editor_menu:SetSize( 200, ScrH() )
		fh_editor_menu.Paint = function(self, w, h)
			surface.SetDrawColor(255, 255, 255, 0)
		end

		local DermaButton = vgui.Create( "DButton", fh_editor_menu )
		DermaButton:SetText( "Add Springtrap Dance Pos" )	
		DermaButton:SetPos( 5, 10 )
		DermaButton:SetSize( 180, 30 )
		DermaButton.DoClick = createEditableSpringtrapDancePos
		
		gui.EnableScreenClicker( true )
	end

	hook.Add( "PlayerButtonDown", "fh_editor_cursor", function( ply, button )
		if !InEditor() or button != KEY_Z then return end
		if not IsFirstTimePredicted() then return end

		editorButtons()
	end)

	hook.Add("Think", "fh_editor_place_think", function()
		if not IsValid(placingEntity) then return end
		local tr = LocalPlayer():GetEyeTrace()
		placingEntity:SetPos(tr.HitPos)
		
		local ang = placingEntity:GetAngles()
		ang.p = 0
		ang.r = 0
		ang.y = addAng
		placingEntity:SetAngles(ang)
	end)
	
	local function NormalizeAngle(angle)
		angle = angle % 360
		if angle > 180 then
			angle = angle - 360
		end
		return angle
	end

	hook.Add( "InputMouseApply", "FreezeTurning", function( cmd )
		if CurTime() - lastRotateTime < 0.025 then return end
		local delta = math.Round(math.min(cmd:GetMouseWheel(), 1))
		if delta ~= 0 then
			addAng = addAng + delta * 22.5
			addAng = NormalizeAngle(addAng)
			lastRotateTime = CurTime()
		end
	end )

	hook.Add("PlayerButtonDown", "fh_editor_place_click", function(ply, key)
		if not IsValid(placingEntity) then return end
		if key ~= MOUSE_LEFT then return end

		if !placedPositions["info_killer_win"] then placedPositions["info_killer_win"] = {} end

		table.insert(placedPositions["info_killer_win"], {
			pos = placingEntity:GetPos(),
			ang = placingEntity:GetAngles()
		})

		print("[fh_editor] Позиция сохранена:")
		PrintTable(placedPositions)

		createSpringDancePos(placingEntity:GetPos(), placingEntity:GetAngles())

		placingEntity:Remove()
		placingEntity = nil
	end)
end