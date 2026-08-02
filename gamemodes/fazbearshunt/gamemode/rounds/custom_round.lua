AddCSLuaFile()

local duration = 600
local setup = 300

fh.RegisterRoundType("custom_round", -10, function()
	
	freezeAnimatronics(setup)
	
	fh.timer.StartGameTimer(
		duration, 
		setup, 
		"ambient/alarms/warningbell1.wav", 
		tostring( "CUSTOM" ), 
		endRound
	)
end, 2)

fh.SetRoundTypeBlocked(-10, true)

if CLIENT then return end

hook.Add("fh_startgame", "prevent_custom_round", function(roundType)
	if roundType == -10 then
		return false
	end
end)