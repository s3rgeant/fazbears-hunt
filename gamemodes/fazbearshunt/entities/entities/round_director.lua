--[[
	в хаммере через этот энтити можно строить логику ивентов карты, которые будут происходит во время
	начала раунда, разморозки аниматроников, сокращение таймера и конец раунда.
]]
AddCSLuaFile()

ENT.Base = "base_anim"
ENT.Type = "point"

function ENT:Initialize()
end

function ENT:KeyValue(k, v)
	if string.Left( k, 2 ) == "On" then
		self:StoreOutput( k, v )
	end
end

if SERVER then
	hook.Add("fh_startgame", "round_director_outputs", function()
		local director = ents.FindByClass("round_director")[1]
		
		if IsValid(director) then
			director:TriggerOutput("OnStartRound")
		end
	end)

	hook.Add("fh_poststartgame", "round_director_outputs", function()
		local director = ents.FindByClass("round_director")[1]
		
		if IsValid(director) then
			director:TriggerOutput("OnPostStartRound")
		end
	end)

	hook.Add("fh_postendgame", "round_director_outputs", function(killW)
		local director = ents.FindByClass("round_director")[1]
		
		if IsValid(director) then
			director:TriggerOutput(killW and "OnEndGameKillers" or "OnEndGameSurvivors")
		end
	end)

	hook.Add("fh_timercutback", "round_director_outputs", function(killW)
		local director = ents.FindByClass("round_director")[1]
		
		if IsValid(director) then
			director:TriggerOutput("OnTimerCutback")
		end
	end)

	hook.Add("FH_LastManStanding", "round_director_outputs", function(killW)
		local director = ents.FindByClass("round_director")[1]
		
		if IsValid(director) then
			director:TriggerOutput("OnLastManStanding")
		end
	end)
end