local canCheckAfk = false
local lp = nil

local lastActiveTime = 0
local aboutToBeKicked = false

hook.Add("InitPostEntity", "afk_start", function()
	lp = LocalPlayer()
	if not IsValid(lp) then return end

	canCheckAfk = true
	lastActiveTime = CurTime()
	aboutToBeKicked = false
end)

local function resetAFKState()
	lastActiveTime = CurTime()
	aboutToBeKicked = false
end

local function handleAFK(ply, idleTime)
	if ply:IsListenServerHost() or ply:IsSuperAdmin() then
		resetAFKState()
		return
	end

	local kickDelay = ply:IsAnimatronic() and 45 or 90
	local kickAfterWarn = kickDelay + 25

	if aboutToBeKicked then
		if idleTime >= kickAfterWarn then
			RunConsoleCommand("disconnect")
		end
		return
	end

	if idleTime >= kickDelay then
		aboutToBeKicked = true
		lastActiveTime = CurTime()

		surface.PlaySound("player/suit_denydevice.wav")
		fh_change_display(
			language.GetPhrase("afk.kick_message"),
			"",
			20
		)
	end
end

hook.Add("SetupMove", "afk_check_last", function(ply, mv, cmd)
	if not canCheckAfk then return end

	lp = lp or LocalPlayer()
	if not IsValid(lp) or ply ~= lp then return end

	if
		cmd:GetButtons() ~= 0
		or cmd:GetMouseX() ~= 0
		or cmd:GetMouseY() ~= 0
		or not GetGlobal2Bool("gameOn", false)
		or not ply:Alive()
	then
		resetAFKState()
		return
	end

	local idleTime = CurTime() - lastActiveTime
	if idleTime > 20 then
		handleAFK(ply, idleTime)
	end
end)

hook.Add("StartChat", "afk_chat_start", function()
	if IsValid(LocalPlayer()) then
		resetAFKState()
	end
end)

hook.Add("FinishChat", "afk_chat_finish", function()
	if IsValid(LocalPlayer()) then
		resetAFKState()
	end
end)