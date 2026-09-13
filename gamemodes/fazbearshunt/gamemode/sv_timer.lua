fh.timer = fh.timer or {}

local timerName = "fh_gamedefault_timer"
local currentTitle = ""

local CurTime = CurTime
local StartTime = 0
local EndTime = 0

function fh.timer.StartDefaultTimer(duration, endfunc)
	timer.Create(timerName, duration, 1, endfunc)
	
	local ct = CurTime()
	StartTime = ct
	EndTime = ct + duration
	
    net.Start("fh_start_lobby_timer")
	net.WriteFloat( StartTime )
	net.WriteFloat( EndTime )
    net.Broadcast()
end

function fh.timer.StartGameTimer(dur, setupdur, sound, title, endfunc)
	timer.Create(timerName, dur + setupdur, 1, endfunc)
	
	local ct = CurTime()
	StartTime = math.floor(ct)
	EndTime = math.floor(ct + dur + setupdur)
	
    net.Start("fh_start_game_timer")
	net.WriteFloat( StartTime )
	net.WriteFloat( EndTime )
	net.WriteFloat( setupdur )
	net.WriteString( sound )
	net.WriteString( title )
    net.Broadcast()
	
	currentTitle = title
end

function fh.timer.CutBack(dur, sound)
	timer.Adjust(timerName, dur)
	
	local ct = CurTime()
	EndTime = ct + dur
	if StartTime > EndTime then StartTime = EndTime end
	
	net.Start("fh_timer_cutback")
	net.WriteFloat( StartTime )
	net.WriteFloat( EndTime )
	net.WriteString(sound)
	net.Broadcast()
	
	hook.Run("fh_timercutback", dur)
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
	net.WriteFloat( StartTime )
	net.WriteFloat( EndTime )
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

function fh.timer.TimeLeft()
	return fh.timer.GetTimeLeft()
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
		net.WriteFloat( StartTime )
		net.WriteFloat( EndTime )
		net.WriteFloat(0)
		net.WriteString("")
		net.WriteString(currentTitle)
		net.Send(ply)
	end
end

function fh.timer.LobbySend(ply)
	if IsValid(ply) and ply:IsPlayer() then
		net.Start("fh_start_lobby_timer")
		net.WriteFloat( StartTime )
		net.WriteFloat( EndTime )
		net.Send(ply)
	end
end