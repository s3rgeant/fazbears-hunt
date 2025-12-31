local canCheckAfk = false

hook.Add( "InitPostEntity", "afk_start", function()
	canCheckAfk = true
	
	local myself = LocalPlayer()
	if IsValid(myself) then
		myself._LastActiveCommand = CurTime()
		myself._aboutToBeKicked = false
	end
end )

local function handleAFK(ply, t)
	if ply:IsListenServerHost() or ply:IsSuperAdmin() then
		ply._LastActiveCommand = CurTime()
		return
	end

	local reallyCheck = ply:IsAnimatronic() and 45 or 90

	if ply._aboutToBeKicked then
		if t > reallyCheck + 25 then
			RunConsoleCommand("disconnect")
		end
		return
	end

	if t > reallyCheck then
		ply._aboutToBeKicked = true
		ply._LastActiveCommand = CurTime()

		surface.PlaySound("player/suit_denydevice.wav")
		fh_change_display(language.GetPhrase("afk.kick_message"), "", 20)
	end
end


hook.Add( "SetupMove", "afk_check_last", function( ply, mv, cmd )
	if !canCheckAfk then return end

	if ply._LastActiveCommand and CurTime() - ply._LastActiveCommand > 20 then
		handleAFK(ply, CurTime() - ply._LastActiveCommand)
	end
	if cmd:GetButtons() > 0 or cmd:GetMouseX() ~= 0 or cmd:GetMouseY() ~= 0 or !GetGlobal2Bool("gameOn", false) or !ply:Alive() then
		ply._LastActiveCommand = CurTime()
		ply._aboutToBeKicked = false
	end
end)

-- трогает чат значит не афк
hook.Add( "StartChat", "afk_chat", function( )
	local myself = LocalPlayer()
	if IsValid(myself) then
		myself._LastActiveCommand = CurTime()
		myself._aboutToBeKicked = false
	end
end)
hook.Add( "FinishChat", "afk_chat", function( )
	local myself = LocalPlayer()
	if IsValid(myself) then
		myself._LastActiveCommand = CurTime()
		myself._aboutToBeKicked = false
	end
end)