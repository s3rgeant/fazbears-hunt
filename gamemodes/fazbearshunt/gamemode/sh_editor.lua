if SERVER then
	util.AddNetworkString("fh_client_asks_editor")
	util.AddNetworkString("fh_editor_save_positions")
	util.AddNetworkString("fh_editor_load_positions")
	util.AddNetworkString("fh_editor_send_positions")
	util.AddNetworkString("fh_editor_clear_positions")
	
	util.AddNetworkString("fh_editor_client_exit")

	local saveDir = "fh_editor"
	local placedData = {}

	local function GetSavePath()
		return saveDir .. "/" .. game.GetMap() .. ".json"
	end

	local function SavePlacedEntities()
		if not file.IsDir(saveDir, "DATA") then
			file.CreateDir(saveDir)
		end
		file.Write(GetSavePath(), util.TableToJSON(placedData, true))
		print("[fh_editor] Saved positions for map:", game.GetMap())
	end

	local function LoadPlacedEntities()
		local path = GetSavePath()
		if not file.Exists(path, "DATA") then
			return
		end
		local data = file.Read(path, "DATA")
		local decoded = util.JSONToTable(data or "{}")
		if not istable(decoded) then return end
		placedData = decoded
		
		return placedData
	end

	local function SpawnAllPlacedEntities()
		if not placedData then return end
		for class, positions in pairs(placedData) do
			for _, info in ipairs(positions) do
				local ent = ents.Create(class)
				if not IsValid(ent) then continue end
				ent:SetPos(Vector(info.pos.x, info.pos.y, info.pos.z))
				ent:SetAngles(Angle(info.ang.p, info.ang.y, info.ang.r))
				ent:Spawn()
				
				if class == "info_killer_win" then
					local ent = ents.Create("fh_win_camera")
					if not IsValid(ent) then continue end
					ent:SetPos(Vector(info.pos.x, info.pos.y, info.pos.z + 70))
					ent:SetAngles(Angle(info.ang.p + 180, info.ang.y, info.ang.r))
					ent:Spawn()
				end
			end
		end
	end

	net.Receive("fh_editor_save_positions", function(_, ply)
		if not ply:IsSuperAdmin() then return end
		local data = net.ReadTable()
		if not istable(data) then return end
		placedData = data
		SavePlacedEntities()
		ply:ChatPrint("[fh_editor] Positions are saved.")
	end)

	net.Receive("fh_editor_load_positions", function(_, ply)
		if not ply:IsSuperAdmin() then return end
		local data = LoadPlacedEntities()
		net.Start("fh_editor_send_positions")
		net.WriteTable(data or {})
		net.Send(ply)
	end)

	net.Receive("fh_editor_clear_positions", function(_, ply)
		if not ply:IsSuperAdmin() then return end
		placedData = {}
		SavePlacedEntities()
		ply:ChatPrint("[fh_editor] All positions are deleted for " .. game.GetMap())
	end)

	hook.Add("InitPostEntity", "fh_editor_load_on_init", function()
		LoadPlacedEntities()
		timer.Simple(1, SpawnAllPlacedEntities)
	end)

	hook.Add("PostCleanupMap", "fh_editor_respawn_after_cleanup", function()
		timer.Simple(1, SpawnAllPlacedEntities)
	end)

	net.Receive("fh_client_asks_editor", function(_, ply)
		if game.SinglePlayer() then
			ply:ChatPrint("Sadly, FH Editor only works in multiplayer!")
			return
		end
		if ply:IsSuperAdmin() or ply:Team() == TEAM_EDITOR then
			if ply:Team() ~= TEAM_EDITOR then
				ply:StripWeapons()
				ply:Spectate(OBS_MODE_ROAMING)
				ply:SetTeam(TEAM_EDITOR)
			else
				net.Start("fh_editor_client_exit")
				net.Send(ply)
				
				if isGameOn then
					ply:StripWeapons()
					ply:Spectate(OBS_MODE_ROAMING)
					ply:SetTeam(TEAM_SPECTATOR)
				else
					ply:Spawn()
					ply:SetTeam(TEAM_SURVIVOR)
				end
			end
		end
	end)
end


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
		return LocalPlayer() and LocalPlayer():Team() == TEAM_EDITOR
	end

	local placedPositions = {}
	local placingEntity = nil
	local placingType = ""
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

	local function createEditorPlayerPos(pos, ang)
		if IsValid(placingEntity) then placingEntity:Remove() end

		local ent = ClientsideModel("models/editor/playerstart.mdl")
		ent:SetPos(pos)
		ent:SetAngles(ang)
		ent:Spawn()

		table.insert(placedEntities, ent)
		placingType = ""
	end

	local function createPosShared()
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

	local function createEditableSpringtrapDancePos()
		createPosShared()

		placingType = "info_killer_win"
	end

	local function createEditableSpawnPointPos()
		createPosShared()

		placingType = "info_player_killer"
	end

	local fh_editor_menu = nil
	function editorButtons()
		if fh_editor_menu then
			fh_editor_menu:Remove()
			fh_editor_menu = nil
			gui.EnableScreenClicker(false)
			return
		end

		fh_editor_menu = vgui.Create("DPanel")
		fh_editor_menu:SetPos(20, 20)
		fh_editor_menu:SetSize(250, ScrH() - 40)
		fh_editor_menu.Paint = function(self, w, h)
			surface.SetDrawColor(0, 0, 0, 240)
			surface.DrawRect(0, 0, w, h)
		end

		local y = 50
		local function makeBtn(text, func)
			local b = vgui.Create("DButton", fh_editor_menu)
			b:SetText(text)
			b:SetPos(5, y)
			b:SetSize(240, 30)
			b.DoClick = func
			y = y + 40
			return b
		end

		makeBtn("Add Animatronic Victory Dance Position", createEditableSpringtrapDancePos)
		makeBtn("Add Animatronic Spawnpoint Position", createEditableSpawnPointPos)

		makeBtn("Save Changes", function()
			net.Start("fh_editor_save_positions")
			net.WriteTable(placedPositions)
			net.SendToServer()
			chat.AddText(Color(0, 255, 0), "[fh_editor] Changes are sent to the server.")
		end)

		makeBtn("Load Positions", function()
			net.Start("fh_editor_load_positions")
			net.SendToServer()
		end)

		makeBtn("Clear Positions", function()
			net.Start("fh_editor_clear_positions")
			net.SendToServer()
			RemoveAllPlacedEntities()
			placedPositions = {}
		end)

		gui.EnableScreenClicker(true)
	end

	net.Receive("fh_editor_send_positions", function()
		local data = net.ReadTable() or {}
		
		if table.IsEmpty(data) or table.Count(data) <= 0 then
			chat.AddText(Color(255, 0, 0), "[fh_editor] ERROR! No locations for this map found.")
			return
		end
		RemoveAllPlacedEntities()
		for class, positions in pairs(data) do
			for _, info in ipairs(positions) do
				local ent = ClientsideModel("models/editor/playerstart.mdl")
				ent:SetPos(Vector(info.pos.x, info.pos.y, info.pos.z))
				ent:SetAngles(Angle(info.ang.p, info.ang.y, info.ang.r))
				ent:SetColor(Color(0, 255, 255))
				ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
				ent:SetMaterial("models/wireframe")
				ent:Spawn()
				table.insert(placedEntities, ent)
			end
		end
		chat.AddText(Color(100, 255, 255), "[fh_editor] Positions are successfuly loaded.")
	end)

	net.Receive("fh_editor_client_exit", function()
		RemoveAllPlacedEntities()
	end)

	hook.Add( "PlayerButtonDown", "fh_editor_cursor", function( ply, button )
		if !InEditor() or button ~= KEY_Z then return end
		if not IsFirstTimePredicted() then return end

		editorButtons()
	end)
	
	hook.Add( "PreDrawHUD", "fh_editor_hud", function()
		if !InEditor() then return end
		local w = 256
		local h = 196
		
		local text = "Z - Open Editor Menu"
		.. "\n" .. "Mouse RMB - Place"
		.. "\n" .. "Mouse Wheel - Rotate"

		cam.Start2D()

			surface.SetDrawColor( 20, 20, 20, 200 )
			surface.DrawRect( ScrW() - w, 0, w, h )

			draw.DrawText( text, "Trebuchet24", ScrW() - w + 10 , 10, color_white, TEXT_ALIGN_LEFT )

		cam.End2D()

	end )

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
	
	local function NormalizeAngle(a)
		a = a % 360
		if a > 180 then a = a - 360 end
		return a
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

		if !placedPositions[placingType] then placedPositions[placingType] = {} end

		table.insert(placedPositions[placingType], {
			pos = placingEntity:GetPos(),
			ang = placingEntity:GetAngles()
		})

		print("[fh_editor] Позиция сохранена:")
		PrintTable(placedPositions)

		createEditorPlayerPos(placingEntity:GetPos(), placingEntity:GetAngles())
		placingEntity:Remove()
		placingEntity = nil
	end)
end