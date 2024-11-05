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
    customScoreboard:SetSize(300, ScrH() * 0.8)
    customScoreboard:SetTitle("")
    customScoreboard:ShowCloseButton(false)
    customScoreboard:SetDraggable(false)
    customScoreboard:Center()
	customScoreboard:SetPos(customScoreboard.x, 155)
	
	customScoreboard.Paint = function(self, w, h)
	    draw.RoundedBox(2, 0, 0, w, h, faded_black)
	    draw.SimpleText(language.GetPhrase("fuppr.scoreboard.players"), "ScoreFont", 150, 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
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
		avatar:SetMouseInputEnabled(true)
		avatar.DoClick = function()
			local steamID64 = ply:SteamID64()
			if steamID64 then
				steamworks.ViewProfile(steamID64)
			end
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
    end
end

function GM:ScoreboardHide()
    if IsValid(customScoreboard) then
        customScoreboard:SetVisible(false)
		gui.EnableScreenClicker(false)
    end
end

gameevent.Listen( "player_connect" )
hook.Add("player_connect", "UpdateScoreboardJoin", function()
    if IsValid(customScoreboard) then
        UpdatePlayerList()
    end
end)

gameevent.Listen( "player_hurt" )
hook.Add("player_hurt", "UpdateScoreboardLeave", function()
    if IsValid(customScoreboard) then
        UpdatePlayerList()
    end
end)

gameevent.Listen( "player_disconnect" )
hook.Add("player_disconnect", "UpdateScoreboardLeave", function()
    if IsValid(customScoreboard) then
        UpdatePlayerList()
    end
end)