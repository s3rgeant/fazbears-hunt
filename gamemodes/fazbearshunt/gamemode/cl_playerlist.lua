local scoreboardHeader = nil
local customScoreboard = nil
local anim_scrollPanel = nil
local surv_scrollPanel = nil

surface.CreateFont("ScoreFont", {font = "Trebuchet24", size = 24, weight = 500})

surface.CreateFont("metaFont16", { font = "Share Tech Mono Regular", size = 28, extended = true, weight = fh_timer_width, antialias = true, bold = true })
surface.CreateFont("metaFont14", { font = "Share Tech Mono Regular", size = 18, extended = true, weight = fh_timer_width, antialias = true, bold = true })

local faded_black = Color(0, 0, 0, 200)

local boosters = {}

surface.CreateFont("bySergeantFont", { font = "Share Tech Mono Regular", 
		size = 18, 
		extended = true, 
		antialias = true, 
		bold = true 
})

function GM:ScoreboardShow()
	gui.EnableScreenClicker(true)
    if IsValid(customScoreboard) then
		UpdatePlayerList(2701, anim_scrollPanel)
		UpdatePlayerList(TEAM_UNASSIGNED, surv_scrollPanel)
        customScoreboard:SetVisible(true)
		scoreboardHeader:SetVisible(true)
        return
    end

    customScoreboard = vgui.Create("DFrame")
    customScoreboard:SetSize(550, 500)
    customScoreboard:SetTitle("")
    customScoreboard:ShowCloseButton(false)
    customScoreboard:SetDraggable(false)
    customScoreboard:Center()
	customScoreboard:SetPos(customScoreboard.x, 300)
	
    anim_scrollPanel = vgui.Create("DScrollPanel", customScoreboard)
	anim_scrollPanel:SetSize( 278, 500 )
    anim_scrollPanel:Dock(LEFT)
    anim_scrollPanel:DockMargin(-5,26,-5,5)
	
	local color_swag1, color_swag2 = Color(83, 0, 0), Color(152, 2, 2)
	local sbar = anim_scrollPanel:GetVBar()
	
	function sbar:Paint(w, h)
		draw.RoundedBox(0, 0, 0, w*0.5, h, Color(0, 0, 0, 100))
	end
	function sbar.btnGrip:Paint(w, h)
		draw.RoundedBox(4, 0, 1, w*0.5, h - 2, color_swag2)
	end

	function sbar.btnUp:Paint(w, h)
		draw.RoundedBox(4, 0, 0, w*0.5, h, color_swag1)
	end
	function sbar.btnDown:Paint(w, h)
		draw.RoundedBox(4, 0, 0, w*0.5, h, color_swag1)
	end
	
    surv_scrollPanel = vgui.Create("DScrollPanel", customScoreboard)
	surv_scrollPanel:SetSize( 278, 500 )
    surv_scrollPanel:Dock(RIGHT)
    surv_scrollPanel:DockMargin(0,26,-5,0)
	
	local sbar = surv_scrollPanel:GetVBar()
	
	function sbar:Paint(w, h)
		draw.RoundedBox(0, 0, 0, w*0.5, h, Color(0, 0, 0, 100))
	end
	function sbar.btnGrip:Paint(w, h)
		draw.RoundedBox(4, 0, 1, w*0.5, h - 2, color_swag2)
	end

	function sbar.btnUp:Paint(w, h)
		draw.RoundedBox(4, 0, 0, w*0.5, h, color_swag1)
	end
	function sbar.btnDown:Paint(w, h)
		draw.RoundedBox(4, 0, 0, w*0.5, h, color_swag1)
	end

    UpdatePlayerList(2701, anim_scrollPanel)
    UpdatePlayerList(TEAM_UNASSIGNED, surv_scrollPanel)
	
	customScoreboard.Paint = function(self, w, h)
		surface.SetDrawColor(255, 255, 255, 250)
		surface.SetMaterial(Material("vgui/playerlist/playerlist.png"))
		surface.DrawTexturedRect(0, 0, w, h)
		
		local anim_scroll_wide = 0
		
		if anim_scrollPanel and table.Count(anim_scrollPanel:GetCanvas():GetChildren()) > 0 then
			anim_scroll_wide = anim_scrollPanel:GetCanvas():GetChildren()[1]:GetWide()
		
			surface.SetDrawColor(255, 255, 255, 250)
			surface.SetMaterial(Material("vgui/playerlist/tabs/left_t.png"))
			surface.DrawTexturedRect(16, 16, anim_scroll_wide, 32)
			
			draw.SimpleText(
				"АНИМАТРОНИКИ",
				"timerFontSmall",
				anim_scroll_wide / 2 + 16,
				20,
				color_white,
				TEXT_ALIGN_CENTER,
				TEXT_ALIGN_TOP
			)
		end
		
		local surv_scroll_wide = 0
		
		if surv_scrollPanel and table.Count(surv_scrollPanel:GetCanvas():GetChildren()) > 0 then
			surv_scroll_wide = surv_scrollPanel:GetCanvas():GetChildren()[1]:GetWide()
		
			surface.SetDrawColor(255, 255, 255, 250)
			surface.SetMaterial(Material("vgui/playerlist/tabs/right_t.png"))
			surface.DrawTexturedRect(surv_scrollPanel.x + 16, 16, surv_scroll_wide, 32)
			
			draw.SimpleText(
				"ВЫЖИВШИЕ",
				"timerFontSmall",
				surv_scrollPanel.x + surv_scroll_wide / 2 + 16,
				20,
				color_white,
				TEXT_ALIGN_CENTER,
				TEXT_ALIGN_TOP
			)
		end
	
		--[[
		draw.SimpleText(
			language.GetPhrase("fuppr.scoreboard.players") .. " ( " .. #player.GetAll() .. " / " .. game.MaxPlayers() .. " )",
			"bySergeantFont",
			w / 2,
			8,
			color_white,
			TEXT_ALIGN_CENTER,
			TEXT_ALIGN_TOP
		)
		]]--
	end

    scoreboardHeader = vgui.Create("DFrame")
    scoreboardHeader:SetSize(550, 100)
    scoreboardHeader:SetTitle("")
    scoreboardHeader:ShowCloseButton(false)
    scoreboardHeader:SetDraggable(false)
    scoreboardHeader:Center()
	scoreboardHeader:SetPos(scoreboardHeader.x, 196)
	
	scoreboardHeader.Paint = function(self, w, h)
		surface.SetDrawColor(255, 255, 255, 250)
		surface.SetMaterial(Material("vgui/playerlist/playerlist_header.png"))
		surface.DrawTexturedRect(0, 0, w, h)
		
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(Material("vgui/playerlist/fh logo.png"))
		surface.DrawTexturedRect((w / 2) - (156/2), 12, 156, 55)
		
		surface.SetDrawColor(255, 255, 255, 120)
		surface.SetMaterial(Material("vgui/playerlist/logo_glow.png"))
		surface.DrawTexturedRect((w / 2) - (242/2) + 15, 0, 242, 100)
	
		draw.SimpleText(
			"by sergeant",
			"bySergeantFont",
			w / 2,
			h - 28,
			color_white,
			TEXT_ALIGN_CENTER,
			TEXT_ALIGN_TOP
		)
	
		draw.SimpleText(
			language.GetPhrase("ping"),
			"metaFont16",
			w * 0.15,
			4,
			Color(153, 0, 0),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP
		)
	
		draw.SimpleText(
			LocalPlayer():Ping() .. " ms",
			"metaFont14",
			w * 0.15,
			32,
			Color(232, 232, 232),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP
		)
	
		draw.SimpleText(
			language.GetPhrase("players"),
			"metaFont16",
			w * 0.15,
			46,
			Color(153, 0, 0),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP
		)
	
		draw.SimpleText(
			table.Count(player.GetAll()) .. "|" .. game.MaxPlayers(),
			"metaFont14",
			w * 0.15,
			74,
			Color(232, 232, 232),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP
		)
	
		draw.SimpleText(
			language.GetPhrase("time"),
			"metaFont16",
			w * 0.85,
			4,
			Color(153, 0, 0),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP
		)
	
		draw.SimpleText(
			math.floor(CurTime() / 3600) .. "h|" .. math.floor((CurTime() % 3600) / 60) .. "m|" .. math.floor(CurTime() % 60) .. "s",
			"metaFont14",
			w * 0.85,
			32,
			Color(232, 232, 232),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP
		)
	
		draw.SimpleText(
			language.GetPhrase("map"),
			"metaFont16",
			w * 0.85,
			46,
			Color(153, 0, 0),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP
		)
	
		draw.SimpleText(
			game.GetMap(),
			"metaFont14",
			w * 0.85,
			74,
			Color(232, 232, 232),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP
		)
	end
end

function UpdatePlayerList(teamIndex, scrollbar)
	local teamIndex = teamIndex or TEAM_UNASSIGNED

    scrollbar:Clear()
		
    local players = team.GetPlayers(teamIndex)
	
	if teamIndex == TEAM_UNASSIGNED then
		table.Add(players, team.GetPlayers(TEAM_SPECTATOR))
	end
	
    table.sort(players, function(a, b)
        return a:Team() < b:Team()
    end)

    for _, ply in ipairs(players) do
        local plyPanel = scrollbar:Add("DPanel")
        plyPanel:SetSize(0, 32)
        plyPanel:Dock(TOP)
        plyPanel:DockMargin(16, 0, 16, 5)
		
		local suffix = ply:Team() == TEAM_SPECTATOR and "_dead" or ""
		
        plyPanel.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(0, 0, 0, 255))
		
			surface.SetDrawColor(255, 255, 255, 120)
			surface.SetMaterial(Material("vgui/playerlist/tabs/player" .. suffix .. ".png"))
			surface.DrawTexturedRect(0, 0, w, h)
        end

		local Avatar = vgui.Create( "AvatarImage", plyPanel )
		Avatar:SetSize( 24, 24 )
		Avatar:SetPos( 4, 4 )
		Avatar:SetPlayer( ply, 32 )
		
		Avatar.Paint = function(self, w, h)
			if self:IsHovered() then
				surface.SetDrawColor(255, 255, 255, 10)
				surface.DrawRect(0, 0, w, h)
			end
		end
		Avatar.DoClick = function()
			if !ply:IsBot() then
				ply:ShowProfile()
			end
		end
		
		local clr = Color(255,255,255)
		local name_x = 28
		local sub_name_val = 0
		
		table.HasValue(boosters, ply:SteamID64())
	
		if table.HasValue(boosters, ply:SteamID64()) then
			clr = Color(243, 168, 38)
			name_x = 48

			local boosty = vgui.Create( "DImage", plyPanel )
			boosty:SetSize( 14, 16 )
			boosty:SetPos( 36, 8 )
			boosty:SetImage("vgui/playerlist/icons/boosty.png")
			sub_name_val = 2
		end
		
		if ply:Team() == TEAM_SPECTATOR then
		
			clr = Color(120,120,120)
		
		end

        local nameLabel = vgui.Create("DLabel", plyPanel)
        nameLabel:SetText(utf8.sub(ply:Nick(), 0, 16 - sub_name_val))
		nameLabel:SetTextColor(clr)
        nameLabel:SetFont("timerFontSmall")
        nameLabel:DockMargin(name_x, 0, 0, 0)
        nameLabel:SetSize(300, 30)
        nameLabel:Dock(FILL)
        nameLabel:SetContentAlignment(5)
		
		--[[
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
		]]--
    end
end

function GM:ScoreboardHide()
    if IsValid(customScoreboard) then
        customScoreboard:SetVisible(false)
		scoreboardHeader:SetVisible(false)
		gui.EnableScreenClicker(false)
    end
end

gameevent.Listen( "player_connect_client" )
hook.Add("player_connect_client", "UpdateScoreboardJoin", function()
    if IsValid(customScoreboard) then
		timer.Simple(0.5, function()
			UpdatePlayerList(TEAM_UNASSIGNED, surv_scrollPanel)
			UpdatePlayerList(2701, anim_scrollPanel)
		end)
    end
end)

gameevent.Listen( "player_hurt" )
hook.Add("player_hurt", "UpdateScoreboardLeave", function()
    if IsValid(customScoreboard) then
		timer.Simple(0.5, function()
			UpdatePlayerList(TEAM_UNASSIGNED, surv_scrollPanel)
			UpdatePlayerList(2701, anim_scrollPanel)
		end)
    end
end)

gameevent.Listen( "player_disconnect" )
hook.Add("player_disconnect", "UpdateScoreboardLeave", function()
    if IsValid(customScoreboard) then
		timer.Simple(0.5, function()
			UpdatePlayerList(TEAM_UNASSIGNED, surv_scrollPanel)
			UpdatePlayerList(2701, anim_scrollPanel)
		end)
    end
end)

hook.Add( "Initialize", "some_unique_name", function()
    http.Fetch( "https://raw.githubusercontent.com/s3rgeant/fazbearshunt_docs/refs/heads/main/boosty",
		
		-- onSuccess function
		function( body, length, headers, code )
			for line in string.gmatch(body, "[^\n]+") do
				local num = string.match(line, "^%d+")
				if num then
					table.insert(boosters, num)
				end
			end
		end,
	
		-- onFailure function
		function( message )
			-- We failed. =(
		end,
		{ 
			["accept-encoding"] = "gzip, deflate",
			["accept-language"] = "fr" 
		}
	)
end )

--[[
concommand.Add("fh_1", function()
    http.Fetch( "https://raw.githubusercontent.com/s3rgeant/fazbearshunt_docs/refs/heads/main/boosty",
		
		-- onSuccess function
		function( body, length, headers, code )
			for num in string.gmatch(body, "%d+") do
				table.insert(boosters, num) -- добавляем число в массив
			end
		end,
	
		-- onFailure function
		function( message )
			-- We failed. =(
		end,
		{ 
			["accept-encoding"] = "gzip, deflate",
			["accept-language"] = "fr" 
		}
	)
end)
--]]