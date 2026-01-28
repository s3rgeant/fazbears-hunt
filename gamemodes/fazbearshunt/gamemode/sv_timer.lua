fh.timer = fh.timer or {}

local timerName = "fh_gamedefault_timer"
local currentTitle = ""

function fh.timer.StartDefaultTimer(duration, endfunc)
	timer.Create(timerName, duration, 1, endfunc)
	
    net.Start("fh_start_lobby_timer")
	net.WriteFloat(duration)
    net.Broadcast()
end

function fh.timer.StartGameTimer(dur, setupdur, sound, title, endfunc)
	timer.Create(timerName, dur + setupdur, 1, endfunc)
	
    net.Start("fh_start_game_timer")
	net.WriteFloat( dur )
	net.WriteFloat( setupdur )
	net.WriteString( sound )
	net.WriteString( title )
    net.Broadcast()
	
	currentTitle = title
end

function fh.timer.CutBack(dur, sound)
	net.Start("fh_timer_cutback")
	net.WriteFloat(dur)
	net.WriteString(sound)
	net.Broadcast()
			
	timer.Adjust(timerName, dur)
end

function fh.timer.Pause(sound)
	net.Start("fh_pause_game_timer")
	net.WriteFloat( fh.timer.GetTimeLeft() )
	net.WriteString( sound )
	net.Broadcast()
			
	timer.Pause(timerName)
end

function fh.timer.UnPause(sound)
	timer.UnPause(timerName)
	
	net.Start("fh_timer_cutback")
	net.WriteFloat( fh.timer.GetTimeLeft() )
	net.WriteString(sound)
	net.Broadcast()
end

function fh.timer.RemoveTimer()
	if timer.Exists(timerName) then
		timer.Remove(timerName)
	end
	
	currentTitle = ""
	
    net.Start("ResetTimer")
    net.Broadcast()
end

function fh.timer.RemoveTimerNB()
	if timer.Exists(timerName) then
		timer.Remove(timerName)
	end
end

function fh.timer.Exists()
	return timer.Exists(timerName)
end

function fh.timer.GetTimeLeft()
	if timer.Exists(timerName) then
		return timer.TimeLeft(timerName)
	end
	return 0
end

function fh.timer.Send(ply)
	if IsValid(ply) and ply:IsPlayer() then
		net.Start("fh_start_game_timer")
		net.WriteFloat(fh.timer.GetTimeLeft())
		net.WriteFloat(0)
		net.WriteString("")
		net.WriteString(currentTitle)
		net.Send(ply)
	end
end

function fh.timer.LobbySend(ply)
	if IsValid(ply) and ply:IsPlayer() then
		net.Start("fh_start_lobby_timer")
		net.WriteFloat(fh.timer.GetTimeLeft())
		net.Send(ply)
	end
end