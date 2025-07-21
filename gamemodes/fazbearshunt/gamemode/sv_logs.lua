local eventLog = {}

local functions = include('discord_integration.lua')

-- я ненавижу этот блок кода, он до крайности ужасен

function GetHostPlayer()
    for _, ply in player.Iterator() do
        if ply:IsListenServerHost() then
            return ply:Nick()
        end
    end
    return GetHostName()
end

local hostPlayer = "idk"
hook.Add( "PlayerInitialSpawn", "fh_player_spawn_logs", function()
	hostPlayer = GetHostPlayer()
end )

function LogEvent(eventText, discord)
    discord = discord or ""
	if !eventText:match("^%s*$") then
		local timestamp = os.date("%Y-%m-%d %H:%M:%S")
		local gameTime = timer.Exists("EndGameTimer") and (gameDuration - (timer.TimeLeft("EndGameTimer") or 0)) or nil
		local logTime = gameTime and formatTime(gameTime) or "00:00"
		
		local message = "`[" .. logTime .. "]` - " .. eventText
		table.insert(eventLog, message)
		
		functions.sendDiscordMessage("( ".. tostring(hostPlayer) .. " ) - РАУНД " .. tostring(roundCount), conVars.fh_discord_url_avatar, message)
	else
		table.insert(eventLog, "")
	end
end

function LogEmbedEvent(eventText, discord, embed)
    discord = discord or ""
	if !eventText:match("^%s*$") then
		local timestamp = os.date("%Y-%m-%d %H:%M:%S")
		local gameTime = timer.Exists("EndGameTimer") and (gameDuration - (timer.TimeLeft("EndGameTimer") or 0)) or nil
		local logTime = gameTime and formatTime(gameTime) or "00:00"
		local map = game.GetMap() or ""
		
		local message = "`[" .. map .. "]`"
		table.insert(eventLog, message)
		
		if discord == "anims_win" then
		
			set_fh_anims_win_embed(embed)
		
			functions.sendDiscordMessage("( ".. tostring(hostPlayer) .. " ) - РАУНД " .. tostring(roundCount), 
				conVars.fh_discord_url_avatar, 
				message, animatronicsEmbed)
		elseif discord == "survs_win" then
		
			set_fh_survs_win_embed(embed)
		
			functions.sendDiscordMessage("( ".. tostring(hostPlayer) .. " ) - РАУНД " .. tostring(roundCount), 
				conVars.fh_discord_url_avatar, 
				message, survivorsEmbed)
		elseif discord == "stats" then
		
			set_fh_stats_embed(embed)
		
			functions.sendDiscordMessage("( ".. tostring(hostPlayer) .. " ) - РАУНД " .. tostring(roundCount), 
				conVars.fh_discord_url_avatar, 
				message, statsEmbed)
		
		end
	else
		table.insert(eventLog, "")
	end
end

concommand.Add("fh_save_logs", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then
        ply:ChatPrint("You don't have permission to use that.")
        return
    end

    local fileName = "fh_event_log_" .. os.date("%Y-%m-%d_%H-%M-%S") .. ".txt"
    local filePath = "garrysmod/data/" .. fileName

    file.Write(fileName, table.concat(eventLog, "\n"))

    if IsValid(ply) then
        ply:ChatPrint("Event log was saved in file: " .. filePath)
    else
        print("Event log was saved in file: " .. filePath)
    end
end)





-- Следующий код какой то ебанутый, но он работает

function set_fh_anims_win_embed(embed)
	animatronicsEmbed.fields[1].value = tostring(embed[1])
	animatronicsEmbed.fields[2].value = tostring(embed[2])
	animatronicsEmbed.fields[3].value = table.concat(embed[3], ', \n')
end

animatronicsEmbed = {
	title = "ПОБЕДА АНИМАТРОНИКОВ",
	color = 0xff4343,
	fields = {
		{
			name = "Последний выживший:",
			value = "",
			inline = true
		},
		{
			name = "Раунд продлился:",
			value = "",
			inline = true
		},
		{
			name = "За аниматроников играли:",
			value = "",
			inline = false
		}
	}
}

function set_fh_survs_win_embed(embed)
	survivorsEmbed.fields[1].value = table.concat(embed[1], ', \n')
	survivorsEmbed.fields[2].value = table.concat(embed[2], ', \n')
end

survivorsEmbed = {
	title = "ПОБЕДА ВЫЖИВШИХ",
	color = 0x43c3ff,
	fields = {
		{
			name = "Выжившие:",
			value = "",
			inline = true
		},
		{
			name = "За аниматроников играли:",
			value = "",
			inline = true
		}
	}
}

function set_fh_stats_embed(embed)
    statsEmbed.description = string.format(
        "Коэффициент побед: `%d %%` / `%d %%`\n** ( Выжившие / Аниматроники )** \n\n**Всего раундов**: `%d`\n**Побед аниматроников**: `%d`\n**Побед выживших**: `%d`",
        embed[1],
        embed[2],
        embed[3],
        embed[4],
        embed[5]
    )
end

statsEmbed = {
	title = "ОБЩАЯ СТАТИСТИКА",
	description = "err.",
	color = 0xd243ff
}