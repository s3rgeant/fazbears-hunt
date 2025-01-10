local customScoreboard = nil
local scrollPanel = nil

surface.CreateFont("ScoreFont", {font = "Trebuchet24", size = 24, weight = 500})

local faded_black = Color(0, 0, 0, 200)

function GM:ScoreboardShow()
	gui.EnableScreenClicker(true)
    if IsValid(customScoreboard) then
        UpdatePlayerList()
        customScoreboard:SetVisible(true)
        return
    end

    customScoreboard = vgui.Create("DFrame")
    customScoreboard:SetSize(400, ScrH() * 0.77)
    customScoreboard:SetTitle("")
    customScoreboard:ShowCloseButton(false)
    customScoreboard:SetDraggable(false)
    customScoreboard:Center()
	customScoreboard:SetPos(customScoreboard.x, 155)
	
	customScoreboard.Paint = function(self, w, h)
	    draw.RoundedBox(24, 0, 0, w, h, faded_black)
	    draw.SimpleText(language.GetPhrase("fuppr.scoreboard.players") .. " ( " .. #player.GetAll() .. " / " .. game.MaxPlayers() .. " )", "ScoreFont", 200, 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end

    scrollPanel = vgui.Create("DScrollPanel", customScoreboard)
    scrollPanel:Dock(FILL)

    UpdatePlayerList()
end

function UpdatePlayerList()
    scrollPanel:Clear()
		
    local players = player.GetAll()
    table.sort(players, function(a, b)
        return a:Team() > b:Team()
    end)

    for _, ply in ipairs(players) do
        local plyPanel = scrollPanel:Add("DPanel")
        plyPanel:SetSize(0, 32)
        plyPanel:Dock(TOP)
        plyPanel:DockMargin(0, 0, 0, 5)
		
        plyPanel.Paint = function(self, w, h)
            draw.RoundedBox(12, 0, 0, w, h, self:GetBackgroundColor())
        end

		local clr = Color(0, 0, 0)
			
        if ply:Team() == TEAM_SPECTATOR or !ply:Alive() then
            plyPanel:SetBackgroundColor(Color(32, 32, 32, 200))
			clr = Color(132, 132, 132)
        elseif ply:Team() == TEAM_UNASSIGNED then
            plyPanel:SetBackgroundColor(Color(0, 123, 200, 200))
			clr = Color(255, 255, 255)
		elseif ply:Team() == 2701 then
            plyPanel:SetBackgroundColor(Color(200, 0, 20, 200))
			clr = Color(255, 240, 240)
        else
            plyPanel:SetBackgroundColor(Color(200, 200, 200, 200))
        end

        local avatar = vgui.Create("AvatarImage", plyPanel)
        avatar:SetSize(32, 32)
        avatar:SetPlayer(ply, 32)
        avatar:Dock(LEFT)
        avatar.Paint = function(self, w, h)
            surface.SetDrawColor(255, 255, 255)
            draw.RoundedBox(16, 0, 0, w, h, Color(255, 255, 255))
        end
		
		local avatarButton = vgui.Create("DButton", avatar)
		avatarButton:SetSize(32, 32)
		avatarButton:Dock(LEFT)
		avatarButton:SetText("")
		avatarButton:SetContentAlignment(5)
		avatarButton:SetMouseInputEnabled(!ply:IsBot())
		avatarButton.Paint = function(self, w, h)
			if self:IsHovered() then
				surface.SetDrawColor(255, 255, 255, 10)
				surface.DrawRect(0, 0, w, h)
			end
		end
		avatarButton.DoClick = function()
			if !ply:IsBot() then
				ply:ShowProfile()
			end
		end

        local nameLabel = vgui.Create("DLabel", plyPanel)
        nameLabel:SetText(ply:Nick())
		nameLabel:SetTextColor(clr)
        nameLabel:SetFont("ScoreFont")
        nameLabel:SetSize(300, 30)
        nameLabel:Dock(FILL)
        nameLabel:SetContentAlignment(5)
		
		if ply != LocalPlayer() then

			local muteButton = vgui.Create("DButton", plyPanel)
			muteButton:SetSize(32, 32)
			muteButton:Dock(RIGHT)
			muteButton:SetText("")
			muteButton:SetTooltip("Заглушить игрока")
			muteButton.Paint = function(self, w, h)
				if !IsValid(ply) then return end
				local isMuted = ply:IsMuted()
				local bgColor = isMuted and Color(200, 0, 0, 200) or Color(255, 255, 255, 200)
				draw.RoundedBox(12, 0, 0, w, h, bgColor)
			end
			muteButton.DoClick = function()
				ply:SetMuted(!ply:IsMuted())
			end
		end
    end
end

function GM:ScoreboardHide()
    if IsValid(customScoreboard) then
        customScoreboard:SetVisible(false)
		gui.EnableScreenClicker(false)
    end
end

gameevent.Listen( "player_connect_client" )
hook.Add("player_connect_client", "UpdateScoreboardJoin", function()
    if IsValid(customScoreboard) then
		timer.Simple(0.5, function()
			UpdatePlayerList()
		end)
    end
end)

gameevent.Listen( "player_hurt" )
hook.Add("player_hurt", "UpdateScoreboardLeave", function()
    if IsValid(customScoreboard) then
		timer.Simple(0.5, function()
			UpdatePlayerList()
		end)
    end
end)

gameevent.Listen( "player_disconnect" )
hook.Add("player_disconnect", "UpdateScoreboardLeave", function()
    if IsValid(customScoreboard) then
		timer.Simple(0.5, function()
			UpdatePlayerList()
		end)
    end
end)