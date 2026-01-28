playerlist = playerlist or {}

local scoreboardHeader = nil
local customScoreboard = nil
local anim_scrollPanel = nil
local surv_scrollPanel = nil

surface.CreateFont("metaFont16", { font = "Share Tech Mono Regular", size = 28, extended = true, weight = fh_timer_width, antialias = true, bold = true })
surface.CreateFont("metaFont14", { font = "Share Tech Mono Regular", size = 18, extended = true, weight = fh_timer_width, antialias = true, bold = true })

local fh_logo = Material("vgui/playerlist/fh logo.png")
local fh_logo_glow = Material("vgui/playerlist/logo_glow.png")

local playerlist_mat = Material("vgui/playerlist/playerlist.png")
local playerlist_mat_lowres = Material("vgui/playerlist/playerlist_lowres.png")
local playerlist_mat_highres = Material("vgui/playerlist/playerlist_highres.png")

local playerlist_header = Material("vgui/playerlist/playerlist_header.png")
local right_tab_mat = Material("vgui/playerlist/tabs/right_t.png")
local left_tab_mat = Material("vgui/playerlist/tabs/left_t.png")

local faded_black = Color(0, 0, 0, 200)

local boosters = boosters or {}

surface.CreateFont("bySergeantFont", { font = "Share Tech Mono Regular", 
		size = 18, 
		extended = true, 
		antialias = true, 
		bold = true 
})

nextTimeUpdate = 0

local playerIcons = {}
local iconsSet = {}
function playerlist.AddIconSet(icon, texture, size, color)
	if !iconsSet[icon] then
		iconsSet[icon] = {
			texture = texture,
			size = size or 16,
			color = color or Color(255,255,255)
		}
	end
end

function playerlist.SetPlayerIcon(steamid, icon)
	if !iconsSet[icon] then
		print("Failed to apply player ( " .. steamid .. " ) icon ( " .. icon .. " )")
		return
	end
	
	playerIcons[steamid] = icon
end

function playerlist.ResetPlayerIcon(steamid)
	playerIcons[steamid] = nil
end

function playerlist.ResetIconSet(icon)
	iconsSet[icon] = nil
end

playerlist.AddIconSet("boosty", "vgui/playerlist/icons/boosty.png", 16, Color(243,168,38))

function GM:ScoreboardShow()
	gui.EnableScreenClicker(true)
    if IsValid(customScoreboard) then
		if CurTime() > nextTimeUpdate then
			nextTimeUpdate = CurTime() + 1
			
			UpdatePlayerList(TEAM_SURVIVOR, surv_scrollPanel)
			UpdatePlayerList(2701, anim_scrollPanel)
		end
		
        customScoreboard:SetVisible(true)
		scoreboardHeader:SetVisible(true)
        return
    end
	
	nextTimeUpdate = CurTime() + 3
	
	local lowres = ScrH() <= 600 
	local highres = ScrH() > 1080 
	
	local bababoey = lowres and 100 or highres and 400 or 250

    customScoreboard = vgui.Create("DFrame")
    customScoreboard:SetSize(550, lowres and 300 or highres and 750 or 500)
    customScoreboard:SetTitle("")
    customScoreboard:ShowCloseButton(false)
    customScoreboard:SetDraggable(false)
    customScoreboard:Center()
	customScoreboard:SetPos(customScoreboard.x, math.Clamp( ScrH() / 2 - bababoey, 125 , 360))
	
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

	if #anim_scrollPanel:GetCanvas():GetChildren() == 0 and #surv_scrollPanel:GetCanvas():GetChildren() == 0 then
		UpdatePlayerList(2701, anim_scrollPanel)
		UpdatePlayerList(TEAM_SURVIVOR, surv_scrollPanel)
	end
	
	customScoreboard.Paint = function(self, w, h)
		surface.SetDrawColor(255, 255, 255, 250)
		surface.SetMaterial(!lowres and playerlist_mat or playerlist_mat_lowres)
		surface.DrawTexturedRect(0, 0, w, h)
		
		local anim_scroll_wide = 0
		
		if anim_scrollPanel and table.Count(anim_scrollPanel:GetCanvas():GetChildren()) > 0 then
			anim_scroll_wide = anim_scrollPanel:GetCanvas():GetChildren()[1]:GetWide()
		
			surface.SetDrawColor(255, 255, 255, 250)
			surface.SetMaterial(left_tab_mat)
			surface.DrawTexturedRect(16, 16, anim_scroll_wide, 32)
			
			draw.SimpleText(
				string.upper( language.SafeGetPhrase("fazhunt.animatronics_team") ),
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
			surface.SetMaterial(right_tab_mat)
			surface.DrawTexturedRect(surv_scrollPanel.x + 16, 16, surv_scroll_wide, 32)
			
			draw.SimpleText(
				string.upper( language.SafeGetPhrase("fazhunt.survivors_team") ),
				"timerFontSmall",
				surv_scrollPanel.x + surv_scroll_wide / 2 + 16,
				20,
				color_white,
				TEXT_ALIGN_CENTER,
				TEXT_ALIGN_TOP
			)
		end
	end

    scoreboardHeader = vgui.Create("DFrame")
    scoreboardHeader:SetSize(550, 100)
    scoreboardHeader:SetTitle("")
    scoreboardHeader:ShowCloseButton(false)
    scoreboardHeader:SetDraggable(false)
    scoreboardHeader:Center()
	scoreboardHeader:SetPos(scoreboardHeader.x, customScoreboard.y - 104)
	
	scoreboardHeader.Paint = function(self, w, h)
		surface.SetDrawColor(255, 255, 255, 250)
		surface.SetMaterial(playerlist_header)
		surface.DrawTexturedRect(0, 0, w, h)
		
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(fh_logo)
		surface.DrawTexturedRect((w / 2) - (156/2), 12, 156, 55)
		
		surface.SetDrawColor(255, 255, 255, 120)
		surface.SetMaterial(fh_logo_glow)
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
			player.GetCount() .. "|" .. game.MaxPlayers(),
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

local function CreatePlayerPanel(scrollbar, ply)
	local panel_height = 32
	
	local plyPanel = scrollbar:Add("DPanel")
	plyPanel:SetSize(0, panel_height)
	plyPanel:Dock(TOP)
	plyPanel:DockMargin(16, 0, 16, 5)
	
	local suffix = ply:Team() == TEAM_SPECTATOR and "_dead" or ""
	
	local plypanel_mat = Material("vgui/playerlist/tabs/player" .. suffix .. ".png")
	
	plyPanel.Paint = function(self, w, h)
		draw.RoundedBox(8, 0, 0, w, h, Color(0, 0, 0, 255))
	
		surface.SetDrawColor(255, 255, 255, 120)
		surface.SetMaterial(plypanel_mat)
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
	local AvatarBtn = vgui.Create("DButton", plyPanel)
	AvatarBtn:SetSize(24, 24)
	AvatarBtn:SetPos(4, 4)
	AvatarBtn:SetText("")
	AvatarBtn:SetZPos(10)
	AvatarBtn:SetCursor("hand")
	
	AvatarBtn.Paint = function(self, w, h)
		if self:IsHovered() then
			surface.SetDrawColor(255, 255, 255, 20)
			surface.DrawRect(0, 0, w, h)
		end
	end
	
	AvatarBtn.DoClick = function()
		if ply:IsBot() then return end
		
		local isMyself = ply == LocalPlayer()
		
		AvatarBtn:SetEnabled(false)
	
		local frame = vgui.Create("DFrame", plyPanel)
		frame:SetTitle("")
		frame:SetSize(200, isMyself and 45 or 90)
		frame:SetPos(gui.MouseX() - 16, gui.MouseY() - 16)
		frame:MakePopup()
		frame:ShowCloseButton(false)
		
		hook.Add( "ScoreboardHide", "playerlist_frame_" .. tostring(frame), function()
			if !IsValid(frame) then return end
			frame:Close()
			hook.Remove("ScoreboardHide", "playerlist_frame_" .. tostring(frame))
		end )
		
		frame.OnClose = function()
			if IsValid(AvatarBtn) then
				AvatarBtn:SetEnabled(true)
			end
		end
	
		frame.Paint = function(self, w, h)
			draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 40, 230))
		end
	
		local profileBtn = vgui.Create("DButton", frame)
		profileBtn:SetText(language.GetPhrase("fazhunt.playerlist.showprofile"))
		profileBtn:SetSize(180, 30)
		profileBtn:SetPos(10, 10)
		profileBtn:SetColor(Color(0,0,0))
		profileBtn.DoClick = function()
			ply:ShowProfile()
			frame:Close()
			hook.Remove("ScoreboardHide", "playerlist_frame_" .. tostring(frame))
		end
	
		local muteBtn = vgui.Create("DButton", frame)
		muteBtn:SetText(ply:IsMuted() and language.GetPhrase("fazhunt.playerlist.unmute_player") or language.GetPhrase("fazhunt.playerlist.mute_player"))
		muteBtn:SetSize(180, 30)
		muteBtn:SetPos(10, 50)
		muteBtn:SetColor(ply:IsMuted() and Color(255, 0, 0) or Color(0,0,0))
		muteBtn.DoClick = function()
			ply:SetMuted(not ply:IsMuted())
			frame:Close()
			hook.Remove("ScoreboardHide", "playerlist_frame_" .. tostring(frame))
		end
		
		frame.OnCursorExited = function()
			if muteBtn:IsHovered() or profileBtn:IsHovered() then return end
			frame:Close()
			hook.Remove("ScoreboardHide", "playerlist_frame_" .. tostring(frame))
		end
	end
	
	local clr = Color(255,255,255)
	local name_x = 28
	local sub_name_val = 0
	
	if playerIcons[ply:SteamID64()] then
		local icon = playerIcons[ply:SteamID64()]
		
		if iconsSet[icon] then
			local texture = iconsSet[icon].texture
			local size = iconsSet[icon].size
			local color = iconsSet[icon].color
			
			clr = color
			
			local icon = vgui.Create( "DImage", plyPanel )
			icon:SetSize( size, size )
			icon:SetPos( 36, (panel_height/2) - (size/2) )
			icon:SetImage(texture)
			
			name_x = name_x + size
			sub_name_val = math.ceil( size / 8 )
		end
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
end

local showAnimTooltip = false
local animTooltipText = ""

local function CreateAnimatronicPanel(scrollbar, ply, killerData)
	local ent = pills.getMappedEnt(ply)
	
	local panel_height = 40
	
	local plyPanel = scrollbar:Add("DPanel")
	plyPanel:SetSize(0, panel_height)
	plyPanel:Dock(TOP)
	plyPanel:DockMargin(16, 0, 16, 5)
	
	local plypanel_mat = Material("vgui/playerlist/tabs/animatronic.png", "smooth")
	local animName
	local animFullName
	
	local imagePath = ""

	if IsValid(ent) then
		animName = ent.formTable.name
		if killerData[animName] then
			animFullName = killerData[animName].fullname
		
			local panelColor = killerData[animName] and killerData[animName].color or Color(255, 255, 255, 0)
			
			panelColor.a = 120
			
			plyPanel.Paint = function(self, w, h)
				draw.RoundedBox(8, 0, 0, w, h, Color(0, 0, 0, 255))
			
				surface.SetDrawColor(panelColor)
				surface.SetMaterial(plypanel_mat)
				surface.DrawTexturedRect(0, 0, w, h)
			end
			
			imagePath = "vgui/bars/" .. killerData[animName].name .. ".png"
		end
	end
		
	local animImage = nil
		
    if file.Exists("materials/" .. imagePath, "GAME") and IsValid(ent) and killerData[animName] then
		local storedAvatar = killers.GetAvatar(animName)
		if storedAvatar then
			animImage = storedAvatar
		end

        local box = vgui.Create("DImageButton", plyPanel)
        box:SetSize(32, 32)
		box:SetPos( 4, 4 )
        box.name = animName
		
		box.OnCursorEntered = function(self)
			local key = "fazhunt.animatronics.description." .. killerData[self.name].name
			local localized = language.GetPhrase(key)

			if localized == key then
				showAnimTooltip = false
			else
				showAnimTooltip = true
				animTooltipText = language.SafeGetPhrase(animFullName):upper() .. "\n\n" .. localized
			end
		end

		box.OnCursorExited = function(self)
			showAnimTooltip = false
		end
		
		box.DoClick = function()
			if ply:IsBot() then return end
			
			local isMyself = ply == LocalPlayer()
			
			box:SetEnabled(false)
		
			local frame = vgui.Create("DFrame", plyPanel)
			frame:SetTitle("")
			frame:SetSize(200, isMyself and 45 or 90)
			frame:SetPos(gui.MouseX() - 16, gui.MouseY() - 16)
			frame:MakePopup()
			frame:ShowCloseButton(false)
			
			hook.Add( "ScoreboardHide", "playerlist_frame_" .. tostring(frame), function()
				if !IsValid(frame) then return end
				frame:Close()
				hook.Remove("ScoreboardHide", "playerlist_frame_" .. tostring(frame))
			end )
			
			frame.OnClose = function()
				box:SetEnabled(true)
			end
		
			frame.Paint = function(self, w, h)
				draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 40, 230))
			end
		
			local profileBtn = vgui.Create("DButton", frame)
			profileBtn:SetText(language.GetPhrase("fazhunt.playerlist.showprofile"))
			profileBtn:SetSize(180, 30)
			profileBtn:SetPos(10, 10)
			profileBtn:SetColor(Color(0,0,0))
			profileBtn.DoClick = function()
				ply:ShowProfile()
				frame:Close()
				hook.Remove("ScoreboardHide", "playerlist_frame_" .. tostring(frame))
			end
		
			local muteBtn = vgui.Create("DButton", frame)
			muteBtn:SetText(ply:IsMuted() and language.GetPhrase("fazhunt.playerlist.unmute_player") or language.GetPhrase("fazhunt.playerlist.mute_player"))
			muteBtn:SetSize(180, 30)
			muteBtn:SetPos(10, 50)
			muteBtn:SetColor(ply:IsMuted() and Color(255, 0, 0) or Color(0,0,0))
			muteBtn.DoClick = function()
				ply:SetMuted(not ply:IsMuted())
				frame:Close()
				hook.Remove("ScoreboardHide", "playerlist_frame_" .. tostring(frame))
			end
			
			frame.OnCursorExited = function()
				if muteBtn:IsHovered() or profileBtn:IsHovered() then return end
				frame:Close()
				hook.Remove("ScoreboardHide", "playerlist_frame_" .. tostring(frame))
			end
		end

        if animImage then
            box:SetMaterial(animImage)
        else
            box.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(0, 0, 0))
                draw.SimpleText(language.SafeGetPhrase(killerData[animName].fullname), "timerFontSmall", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
	else
	
		local panelColor = Color(255, 255, 255, 120)
		
		plyPanel.Paint = function(self, w, h)
			draw.RoundedBox(8, 0, 0, w, h, Color(0, 0, 0, 255))
		
			surface.SetDrawColor(panelColor)
			surface.SetMaterial(plypanel_mat)
			surface.DrawTexturedRect(0, 0, w, h)
		end
		
		local Avatar = vgui.Create( "AvatarImage", plyPanel )
		Avatar:SetSize( 32, 32 )
		Avatar:SetPos( 4, 4 )
		Avatar:SetPlayer( ply, 32 )
		
		Avatar.Paint = function(self, w, h)
			if self:IsHovered() then
				surface.SetDrawColor(255, 255, 255, 10)
				surface.DrawRect(0, 0, w, h)
			end
		end
		
		local AvatarBtn = vgui.Create("DButton", plyPanel)
		AvatarBtn:SetSize(32, 32)
		AvatarBtn:SetPos(4, 4)
		AvatarBtn:SetText("")
		AvatarBtn:SetZPos(10)
		AvatarBtn:SetCursor("hand")
		
		AvatarBtn.Paint = function(self, w, h)
			if self:IsHovered() then
				surface.SetDrawColor(255, 255, 255, 20)
				surface.DrawRect(0, 0, w, h)
			end
		end
		
		AvatarBtn.DoClick = function()
			if ply:IsBot() then return end
			
			local isMyself = ply == LocalPlayer()
			
			AvatarBtn:SetEnabled(false)
		
			local frame = vgui.Create("DFrame", plyPanel)
			frame:SetTitle("")
			frame:SetSize(200, isMyself and 45 or 90)
			frame:SetPos(gui.MouseX() - 16, gui.MouseY() - 16)
			frame:MakePopup()
			frame:ShowCloseButton(false)
			
			hook.Add( "ScoreboardHide", "playerlist_frame_" .. tostring(frame), function()
				if !IsValid(frame) then return end
				frame:Close()
				hook.Remove("ScoreboardHide", "playerlist_frame_" .. tostring(frame))
			end )
			
			frame.OnClose = function()
				AvatarBtn:SetEnabled(true)
			end
		
			frame.Paint = function(self, w, h)
				draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 40, 230))
			end
		
			local profileBtn = vgui.Create("DButton", frame)
			profileBtn:SetText(language.GetPhrase("fazhunt.playerlist.showprofile"))
			profileBtn:SetSize(180, 30)
			profileBtn:SetPos(10, 10)
			profileBtn:SetColor(Color(0,0,0))
			profileBtn.DoClick = function()
				ply:ShowProfile()
				frame:Close()
				hook.Remove("ScoreboardHide", "playerlist_frame_" .. tostring(frame))
			end
		
			local muteBtn = vgui.Create("DButton", frame)
			muteBtn:SetText(ply:IsMuted() and language.GetPhrase("fazhunt.playerlist.unmute_player") or language.GetPhrase("fazhunt.playerlist.mute_player"))
			muteBtn:SetSize(180, 30)
			muteBtn:SetPos(10, 50)
			muteBtn:SetColor(ply:IsMuted() and Color(255, 0, 0) or Color(0,0,0))
			muteBtn.DoClick = function()
				ply:SetMuted(not ply:IsMuted())
				frame:Close()
				hook.Remove("ScoreboardHide", "playerlist_frame_" .. tostring(frame))
			end
			
			frame.OnCursorExited = function()
				if muteBtn:IsHovered() or profileBtn:IsHovered() then return end
				frame:Close()
				hook.Remove("ScoreboardHide", "playerlist_frame_" .. tostring(frame))
			end
		end
		
	end
	
	local clr = Color(255,255,255)
	local name_x = 28
	local sub_name_val = 0
	
	if playerIcons[ply:SteamID64()] then
		local icon = playerIcons[ply:SteamID64()]
		
		if iconsSet[icon] then
			local texture = iconsSet[icon].texture
			local size = iconsSet[icon].size
			local color = iconsSet[icon].color
			
			clr = color
			
			local icon = vgui.Create( "DImage", plyPanel )
			icon:SetSize( size, size )
			icon:SetPos( 36, (panel_height/2) - (size/2) )
			icon:SetImage(texture)
			
			name_x = name_x + size
			sub_name_val = math.ceil( size / 8 )
		end
	end

	local nameLabel = vgui.Create("DLabel", plyPanel)
	nameLabel:SetText(utf8.sub(ply:Nick(), 0, 16 - sub_name_val))
	nameLabel:SetTextColor(clr)
	nameLabel:SetFont("timerFontSmall")
	nameLabel:DockMargin(name_x, 0, 0, 0)
	nameLabel:SetSize(300, 30)
	nameLabel:Dock(FILL)
	nameLabel:SetContentAlignment(5)
end

hook.Add("PostRenderVGUI", "DrawPLAnimTooltip", function()
	if not showAnimTooltip then return end

	local x, y = input.GetCursorPos()
	local maxWidth = 300
	local padding = 10

	surface.SetFont("DermaDefault")

	local rawLines = string.Explode("\n", animTooltipText, false)
	local lines = {}

	for _, rawLine in ipairs(rawLines) do
		if rawLine == "" then
			table.insert(lines, "")
		else
			local currentLine = ""
			for word in string.gmatch(rawLine, "%S+") do
				local testLine = currentLine == "" and word or currentLine .. " " .. word
				local testWidth = surface.GetTextSize(testLine)

				if testWidth > maxWidth - padding * 2 then
					if currentLine ~= "" then table.insert(lines, currentLine) end
					currentLine = word
				else
					currentLine = testLine
				end
			end
			if currentLine ~= "" then table.insert(lines, currentLine) end
		end
	end

	local tooltipWidth = maxWidth
	local tooltipHeight = #lines * 18 + padding * 2

	surface.SetDrawColor(255, 0, 0, 255)
	surface.DrawRect(x + 9, y + 9, tooltipWidth + 2, tooltipHeight + 2)

	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(x + 10, y + 10, tooltipWidth, tooltipHeight)

	for i, line in ipairs(lines) do
		draw.SimpleText(line, "DermaDefault", x + 10 + padding, y + 10 + padding + (i - 1) * 18, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
end)

function UpdatePlayerList(teamIndex, scrollbar)
	local teamIndex = teamIndex or TEAM_SURVIVOR

    scrollbar:Clear()
		
    local players = team.GetPlayers(teamIndex)
	
	if teamIndex == TEAM_SURVIVOR then
		table.Add(players, team.GetPlayers(TEAM_SPECTATOR))
	end
	
    table.sort(players, function(a, b)
        return a:Team() > b:Team()
    end)
	
	local killerData = killers.getAll()

    for _, ply in ipairs(players) do
		if !ply:IsAnimatronic() then
			CreatePlayerPanel(scrollbar, ply)
		else
			CreateAnimatronicPanel(scrollbar, ply, killerData)
		end
    end
end

function GM:ScoreboardHide()
    if IsValid(customScoreboard) then
        customScoreboard:SetVisible(false)
		scoreboardHeader:SetVisible(false)
		gui.EnableScreenClicker(false)
    end
end

gameevent.Listen( "player_connect" )
hook.Add("player_connect", "UpdateScoreboardJoin", function()
    if IsValid(customScoreboard) then
		timer.Simple(0.5, function()
			UpdatePlayerList(TEAM_SURVIVOR, surv_scrollPanel)
			UpdatePlayerList(2701, anim_scrollPanel)
		end)
    end
end)

gameevent.Listen( "player_hurt" )
hook.Add("player_hurt", "fh_playerlist_update_hurt", function()
    if IsValid(customScoreboard) then
		timer.Simple(0.5, function()
			UpdatePlayerList(TEAM_SURVIVOR, surv_scrollPanel)
			UpdatePlayerList(2701, anim_scrollPanel)
		end)
    end
end)

gameevent.Listen( "player_disconnect" )
hook.Add("player_disconnect", "fh_playerlist_update_disconnect", function()
    if IsValid(customScoreboard) then
		timer.Simple(0.5, function()
			UpdatePlayerList(TEAM_SURVIVOR, surv_scrollPanel)
			UpdatePlayerList(2701, anim_scrollPanel)
		end)
    end
end)

local function apply_boosters()
	for _, v in ipairs(boosters) do
		playerlist.SetPlayerIcon(v, "boosty")
	end
end

local function get_boosters()
    http.Fetch( "https://raw.githubusercontent.com/s3rgeant/fazbearshunt_docs/refs/heads/main/boosty",
		-- onSuccess function
		function( body, length, headers, code )
			for line in string.gmatch(body, "[^\n]+") do
				local num = string.match(line, "^%d+")
				if num then
					table.insert(boosters, num)
				end
			end
			apply_boosters()
		end,
		-- onFailure function
		function( message )
			print("[FH] Failed AGAIN to fetch boosty data base :(")
		end
	)
end

hook.Add( "InitPostEntity", "fh_get_boosters", function()
    http.Fetch( "https://raw.githubusercontent.com/s3rgeant/fazbearshunt_docs/refs/heads/main/boosty",
		
		-- onSuccess function
		function( body, length, headers, code )
			for line in string.gmatch(body, "[^\n]+") do
				local num = string.match(line, "^%d+")
				if num then
					table.insert(boosters, num)
				end
			end
			apply_boosters()
		end,
	
		-- onFailure function
		function( message )
			print("[FH] Failed to fetch boosty data base! Will try again in 10 seconds.")
			
			timer.Simple(10, function()
				get_boosters()
			end)
		end
	)
end)