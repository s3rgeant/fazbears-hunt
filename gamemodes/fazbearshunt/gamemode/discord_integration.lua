local webhookURL = conVars.fh_discord_url_webhook:GetString()

cvars.AddChangeCallback("fh_discord_url_webhook", function(name, old, new)
	webhookURL = conVars.fh_discord_url_webhook:GetString()
end)

local function sendDiscordMessage(username, avatarURL, message, embed)
    if system.IsWindows() then
        local payload = {
            username = username,
            avatar_url = avatarURL,
            content = message
        }
        if embed then
            payload.embeds = {embed}
        end
		
        local jsonPayload = util.TableToJSON(payload, false)

        http.Post(webhookURL, {payload_json = jsonPayload},
        function(result)
            -- Message sent successfully (no print statement)
        end,
        function(failed)
			-- print("Failed to send message to Discord: " .. failed)
        end)
    end
end


return {
    sendDiscordMessage = sendDiscordMessage
}
