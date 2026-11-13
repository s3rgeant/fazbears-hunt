settings.pillsFovEditorData = settings.pillsFovEditorData or {}

local defaultVM = "v_freddy"
local curVM = defaultVM

local DEFAULT_PATH = "models/speps/vm/oldfreddy.mdl"
local currentRender = nil

local function ApplyChanges(e, model)
	e:SetModel(model)
end

local ent = ClientsideModel(DEFAULT_PATH, RENDERGROUP_VIEWMODEL)
ent:SetNoDraw(true)

function settings.OpenPillsFovEditor()
	if IsValid(currentRender) then
		currentRender:Remove()
		currentRender = nil
	end

	if not IsValid(ent) then return end
	
	local data = settings.pillsFovEditorData[curVM]
	local cvar = data.cvar and GetConVar(data.cvar)
	local fov = cvar:GetFloat()
	
	local seq = ent:LookupSequence("idle")
	if seq == -1 then return end

	ent:ResetSequence(seq)
	ent:SetCycle(0)
	ent:SetPlaybackRate(1)

	local duration = ent:SequenceDuration(seq)
	if duration <= 0 then duration = 1 end
	
	duration = duration + 5
	
	surface.PlaySound("fnaf2/gfreddy/head_guardian.mp3")

	currentRender = {
		ent = ent,
		startTime = CurTime(),
		duration = duration
	}
	
	local scrw = ScrW()
	local scrh = ScrH()
	

	hook.Add("PostRenderVGUI", "RenderGuardianModel", function(vm, ply, weapon)
		if not currentRender then return end

		local ent = currentRender.ent
		if not IsValid(ent) then
			currentRender = nil
			return
		end

		local timePassed = CurTime() - currentRender.startTime
		local progress = timePassed / currentRender.duration

		if progress >= 1 then
			currentRender = nil
			hook.Remove("PostRenderVGUI", "RenderGuardianModel")
			return
		end

		ent:FrameAdvance(FrameTime())

		local eyePos = EyePos()
		local eyeAngles = EyeAngles()

		render.ClearDepth()

		cam.Start3D(eyePos, eyeAngles, fov, 0, 0, scrw, scrh, 1, 1000)
			ent:SetPos(eyePos)
			ent:SetAngles(eyeAngles)

			ent:DrawModel()

		cam.End3D()
	end)
end