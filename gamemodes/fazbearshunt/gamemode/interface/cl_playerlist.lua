playerlist = playerlist or {}

local logo = Material("vgui/base/tab/logo.png")
local logo_w, logo_h = logo:Width(), logo:Height()

local main = Material("vgui/base/tab/main_t.png")
local main_w, main_h = main:Width(), main:Height()

local mainb = Material("vgui/base/tab/main_b.png")
local mainb_w, mainb_h = mainb:Width(), mainb:Height()

local upperbar = Material("vgui/base/tab/upperbar.png")
local upperbar_w, upperbar_h = upperbar:Width(), upperbar:Height()

local animpanel = Material("vgui/base/tab/animbar.png")
local animpanel_w, animpanel_h = animpanel:Width(), animpanel:Height()

local panel = Material("vgui/base/tab/survivorbar.png")
local panel_w, panel_h = panel:Width(), panel:Height()

local panel_grd = Material("vgui/base/tab/gradients/ply_gradient.png")

surface.CreateFont("bySergeantFont", { font = "Share Tech Mono", 
		size = 18, extended = true, antialias = true
})
surface.CreateFont("FHScoreboardData24", { font = "Share Tech Mono", 
		size = 26, extended = true, antialias = true
})
surface.CreateFont("FHScoreboardData14", { font = "Share Tech Mono", 
		size = 16, extended = true, antialias = true
})
surface.CreateFont("FHScoreboardPing8", { font = "Share Tech Mono", 
		size = 10, extended = true, antialias = true
})

local muties = {}
local mutePath = "fazbearshunt/muted_players.txt"

hook.Add("Initialize", "fh_muted", function()
	if file.Exists( mutePath, "DATA" ) then
		local data = file.Read( mutePath, "DATA" ) or ""
		local lines = string.Split(data, "\n")
			
		for _,v in ipairs(lines) do
			muties[v] = true
		end
		
		for _,v in player.Iterator() do
			if muties[v:SteamID64()] then
				v:SetMuted(true)
			end
		end
	else
		file.Write(mutePath, "" )
	end
end)

local function MutePlayer(ply)
	local SteamID64 = ply:SteamID64()
	muties[SteamID64] = true
	
	local tosave = ""
	
	for k, _ in pairs(muties) do
		tosave = tosave .. k .. "\n"
	end
	
	file.Write(mutePath, tosave )
end

local function UnmutePlayer(ply)
	local SteamID64 = ply:SteamID64()
	muties[SteamID64] = nil
	
	local tosave = ""
	
	for k, _ in pairs(muties) do
		tosave = k .. "\n"
	end
	
	file.Write(mutePath, tosave )
end

hook.Add( "OnEntityCreated", "fh_muted", function( ply )
	timer.Simple(0, function()
		if not IsValid(ply) then return end
		if not ply:IsPlayer() then return end
		
		local id = ply:SteamID64()
		
		if muties[id] then
			ply:SetMuted(true)
		end
	end)
end)

local color_fazbearshunt = Color(238, 49, 49)

local playerIcons = {}
local iconsSet = {}
function playerlist.AddIconSet(icon, texture, size, color)
	if iconsSet[icon] then return end
	
	iconsSet[icon] = {
		texture = Material(texture),
		size = size or 16,
		color = color or Color(255,255,255)
	}
end

function playerlist.SetPlayerIcon(steamid, icon)
	if !iconsSet[icon] then
		print("Failed to apply player ( " .. steamid .. " ) icon ( " .. icon .. " )")
		return
	end
	
	playerIcons[steamid] = icon
end

function playerlist.GetPlayerIcon(steamid)
	return playerIcons[steamid]
end

function playerlist.ResetPlayerIcon(steamid)
	playerIcons[steamid] = nil
end

function playerlist.ResetIconSet(icon)
	iconsSet[icon] = nil
end

playerlist.AddIconSet("boosty", "vgui/playerlist/icons/boosty.png", 16, Color(243,168,38))

local function grayPaint(self, w, h)
	surface.SetDrawColor(0, 0, 0, 133)
	surface.DrawRect(0, 0, w, h)
end

local scoreboard

local scrollers_W = 260
local scrollers_H = 420

local color_survivors = teamColors[TEAM_SURVIVOR]
local survsTxt = language.GetPhrase("fazhunt.survivors_team")
survsTxt = survsTxt:upper()

local animsTxt = language.GetPhrase("fazhunt.animatronics_team")
animsTxt = animsTxt:upper()

playerlist.LeftScoreboard = {[TEAM_PILLS] = true}
playerlist.RightScoreboard = {
	[TEAM_SURVIVOR] = true, 
	[TEAM_SPECTATOR] = true
}
function GM:ScoreboardShow()
	local ply = LocalPlayer()
	if IsValid(scoreboard) then
		scoreboard:Remove()
	end
	
	local mainH = ScreenScale(main_h) * .5

	scoreboard = vgui.Create("DFrame")
	scoreboard:SetSize(main_w, mainH+5 + upperbar_h + 10)
	scoreboard:SetTitle("")
	scoreboard:ShowCloseButton(false)
	scoreboard:SetDraggable(false)
	scoreboard:Center()
	
	scoreboard.Paint = function(self, w, h)
		gui.EnableScreenClicker(true)
	end

		-- ОСНОВНАЯ ХУЙНЯ
	mainTab = vgui.Create("DFrame", scoreboard)
	mainTab:SetSize(main_w, mainH + 5)
	mainTab:SetPos(0, upperbar_h + 10)
	mainTab:SetTitle("")
	mainTab:ShowCloseButton(false)
	mainTab:SetDraggable(false)
	
			-- САМИ ИГРОКИ ЕБУЧИЕ любимые мои
			
		local function updateScroller(scroller, teams, pilled)
			scroller:Clear()
			
			local w, h = pilled and animpanel_w or panel_w, pilled and animpanel_h or panel_h
			local panelType = pilled and "FHPlayerPillPanel" or "FHPlayerPanel"
			
			for t, _ in pairs(teams) do
				for _, guy in ipairs(team.GetPlayers( t )) do
				
					local pnl = scroller:Add(panelType)
					pnl:SetSize(w, h)
					pnl:Dock( TOP )
					pnl:DockMargin( 0, 0, 0, 7 )
					pnl:SetPlayer(guy, ply)
				end
			end
		end
		
		local L_x = 32
		local R_x = main_w - scrollers_W - L_x
		local y = 56
		
		local scrollers_H = mainH - (16+y)
		
		local scroll_L = vgui.Create("DScrollPanel", mainTab)
		scroll_L:SetSize(scrollers_W, scrollers_H)
		scroll_L:SetPos(L_x, y)
		scroll_L.Paint = grayPaint
		
		local color_swag1, color_swag2 = Color(176, 12, 12), Color(152, 2, 2)
		local sbar = scroll_L:GetVBar()
		
		function sbar:Paint(w, h) draw.RoundedBox(0, 4, 0, w*0.5, h, Color(0, 0, 0, 100)) end
		function sbar.btnGrip:Paint(w, h) draw.RoundedBox(2, 4, 1, w*0.5, h - 2, color_fazbearshunt) end
		function sbar.btnUp:Paint(w, h) draw.RoundedBox(2, 4, 0, w*0.5, h, color_swag1) end
		function sbar.btnDown:Paint(w, h) draw.RoundedBox(2, 4, 0, w*0.5, h, color_swag1) end
		
		updateScroller(scroll_L, playerlist.LeftScoreboard, true)
		
		local scroll_R = vgui.Create("DScrollPanel", mainTab)
		scroll_R:SetSize(scrollers_W, scrollers_H)
		scroll_R:SetPos(R_x, y)
		scroll_R.Paint = grayPaint
		
		local sbar = scroll_R:GetVBar()
		
		function sbar:Paint(w, h) draw.RoundedBox(0, 4, 0, w*0.5, h, Color(0, 0, 0, 100)) end
		function sbar.btnGrip:Paint(w, h) draw.RoundedBox(2, 4, 1, w*0.5, h - 2, color_fazbearshunt) end
		function sbar.btnUp:Paint(w, h) draw.RoundedBox(2, 4, 0, w*0.5, h, color_swag1) end
		function sbar.btnDown:Paint(w, h) draw.RoundedBox(2, 4, 0, w*0.5, h, color_swag1) end
		
		updateScroller(scroll_R, playerlist.RightScoreboard)
		
		mainTab.NextThink = CurTime()
		mainTab.Think = function(self)
			local ct = CurTime()
			if ct >= self.NextThink then
				updateScroller(scroll_L, playerlist.LeftScoreboard, true)
				updateScroller(scroll_R, playerlist.RightScoreboard)
				
				mainTab.NextThink = ct + 1.5
			end
		end
	
	mainTab.Paint = function(self, w, h)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(main)
		surface.DrawTexturedRect(0, 0, w, main_h)
		
		surface.SetDrawColor(0, 0, 0, 194)
		surface.DrawRect(0, main_h, w, mainH - main_h)
		
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(mainb)
		surface.DrawTexturedRect(0, h - 5, w, 5)
		
		draw.SimpleText(
			animsTxt,
			"FHScoreboardData24",
			L_x,
			y - 6,
			color_fazbearshunt, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM
		)
		
		draw.SimpleText(
			survsTxt,
			"FHScoreboardData24",
			R_x,
			y - 6,
			color_survivors, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM
		)
	end
		

		-- ВЕРХНЯЯ ХУЙНЯ!!!
    upperTab = vgui.Create("DFrame", scoreboard)
    upperTab:SetSize(upperbar_w, upperbar_h)
    upperTab:SetTitle("")
    upperTab:ShowCloseButton(false)
    upperTab:SetDraggable(false)
	
	local uTxt_y = 24
	local dTxt_y = 100
	local addY = 22
	
	local map = language.GetPhrase("map"):upper()
	local curMap = game.GetMap()
	
	local timeTxt = language.GetPhrase("time"):upper()
	local players = language.GetPhrase("players"):upper()
	local ping = language.GetPhrase("ping"):upper()
	
	upperTab.Paint = function(self, w, h)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(upperbar)
		surface.DrawTexturedRect(0, 0, w, h)
		
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(logo)
		surface.DrawTexturedRect((w * .5) - (logo_w * .5), -24, logo_w, logo_h)
	
		draw.SimpleText(
			"by sergeant",
			"bySergeantFont",
			w / 2,
			h - 28,
			color_white,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
		)
	
		draw.SimpleText(
			ping,
			"FHScoreboardData24",
			w * 0.05,
			uTxt_y,
			color_fazbearshunt, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
		)
	
		draw.SimpleText(
			ply:Ping() .. " ms",
			"FHScoreboardData14",
			w * 0.05,
			uTxt_y + addY,
			color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
		)
	
		draw.SimpleText(
			players,
			"FHScoreboardData24",
			w * 0.05,
			dTxt_y,
			color_fazbearshunt, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
		)
	
		draw.SimpleText(
			player.GetCount() .. "|" .. game.MaxPlayers(),
			"FHScoreboardData14",
			w * 0.05,
			dTxt_y + addY,
			color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
		)
	
		draw.SimpleText(
			timeTxt,
			"FHScoreboardData24",
			w * 0.95,
			uTxt_y,
			color_fazbearshunt, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
		)
	
		draw.SimpleText(
			math.floor(CurTime() / 3600) .. "h|" .. math.floor((CurTime() % 3600) / 60) .. "m|" .. math.floor(CurTime() % 60) .. "s",
			"FHScoreboardData14",
			w * 0.95,
			uTxt_y + addY,
			color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
		)
	
		draw.SimpleText(
			map,
			"FHScoreboardData24",
			w * 0.95,
			dTxt_y,
			color_fazbearshunt, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
		)
	
		draw.SimpleText(
			curMap,
			"FHScoreboardData14",
			w * 0.95,
			dTxt_y + addY,
			color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
		)
	end
end

function GM:ScoreboardHide()
    if IsValid(scoreboard) then
		scoreboard:Hide()
		gui.EnableScreenClicker(false)
    end
end

local showAnimTooltip = false
local animTooltipText = ""

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

	-- панелька выжившего 
local muteM = Material("vgui/base/tab/mute.png")
local mute_w, mute_h = muteM:Width(), muteM:Height()

local PlayerPanel = {}
function PlayerPanel:Init()
	self:SetTall(28)
	self:SetText("")
	self:SetMouseInputEnabled(true)
	
	self.ms_x = .85
	
	self.clr = color_white
	
	local avatar = vgui.Create( "AvatarImage", self )
	avatar:SetSize( 22, 22 )
	avatar:SetPos( 6, 4 )
	
	self.avatar = avatar
		
	local avImage = vgui.Create("DButton", self)
	avImage:SetSize( 36, 36 )
	avImage:SetPos( 6, 4 )
	avImage:SetVisible(true)
	avImage:SetText("")
	
	avImage.Paint = function(me, w, h)
	end
	
	self.avImage = avImage
		
	local icon = vgui.Create("DImage", self)
	icon:SetSize( 16, 16 )
	icon:SetPos( 24, 4 )
	icon:SetVisible(true)
	icon:SetText("")
	
	icon.Paint = function(me, w, h)
	end
	
	self.icon = icon
	
	local ply = self.ply
	
	local mute = vgui.Create( "DButton", self )
	mute:SetSize( 32, 32 )
	mute:SetText("")
	
	mute.Paint = function(me, w, h)
		local ply = self.ply
		local clr = color_white
		
		if ply and IsValid(ply) and ply:IsMuted() then
			clr = color_fazbearshunt
		end
	
		surface.SetDrawColor(clr.r, clr.g, clr.b, 255)
		surface.SetMaterial(muteM)
		surface.DrawTexturedRect(0, 0, mute_w, mute_h + 1)
	end
	
	mute.DoClick = function()
		if self.ply then
			local ply = self.ply
			
			if IsValid(ply) then
				ply:SetMuted( not ply:IsMuted() )
				if ply:IsMuted() then
					MutePlayer(ply)
				else
					UnmutePlayer(ply)
				end
			end
		end
	end
	
	self.mute = mute
	
	avImage.DoClick = function()
		if self.ply then
			local ply = self.ply
			
			if IsValid(ply) and not ply:IsBot() then
				ply:ShowProfile()
			end
		end
	end
end

function PlayerPanel:PerformLayout(w, h)
	if self.init then return end
	
	local mute = self.mute
	
	if mute then
		mute:SetPos(w - 8 - mute_w, (h * .5) - mute_h * .5)
	end
	
	local avatar = self.avatar
	
	if avatar then
		avatar:SetPos(6, (h * .5) - 11 + 1)
	end
	
	self.init = true
end

function PlayerPanel:SetPlayer(ply, localplayer)
	local avatar = self.avatar
	avatar:SetPlayer( ply, 32 )
	
	local nick = ply:Nick()
	self.nick = nick
	self.ply = ply
	self.alive = ply:Alive()
	
	local team = ply:Team()
	
	if teamColors[team] then self.clr = teamColors[team] end
	
	if ply == localplayer or ply:IsBot() then
		if self.mute then
			self.mute:Remove()
			self.mute = nil
			self.ms_x = .95
		end
	end
end

local clr_gray = Color(155,155,155)
local clr_grayer = Color(120,120,120)
function PlayerPanel:Paint(w, h)
	local clr = self.clr
	local nick = self.nick or ""
	local nicksub = 22
	
	if self.mute then
		nicksub = nicksub - 3
	end

	surface.SetDrawColor(clr.r, clr.g, clr.b, 255)
	surface.SetMaterial(panel)
	surface.DrawTexturedRect(0, 0, w, h)
	
	local txtX = 0
	local txtClr = color_white

	local ply = self.ply
	local isvalidply = IsValid(ply)
	if isvalidply and playerIcons[ ply:SteamID64() ] then
		local iconS = playerIcons[ ply:SteamID64() ]
		
		if iconsSet[iconS] then
		
			local texture = iconsSet[iconS].texture
			local size = iconsSet[iconS].size
			local color = iconsSet[iconS].color
			if self.alive then
				txtClr = color
			end

			--surface.SetDrawColor(color.r, color.g, color.b, 255)
			--surface.SetMaterial(panel_grd)
			--surface.DrawTexturedRect(0, 2, w, h - 2)

			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(texture)
			surface.DrawTexturedRect(34, size * .5 - 1, size, size)
		
			nicksub = nicksub - 2
			txtX = size + 2
		end
	end
	if not self.alive then
		txtClr = clr_grayer
	end
	
	nick = utf8.sub(nick, 0, nicksub)
	draw.SimpleText(
		nick,
		"FHScoreboardData14",
		36 + txtX,
		h * .5,
		txtClr, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
	)
	
	if not IsValid(ply) then return end
	
	local ping = ply:Ping()
	
	draw.SimpleText(
		ping .. " ms",
		"FHScoreboardPing8",
		w * self.ms_x,
		h * .5,
		clr_gray, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
	)
end
vgui.Register("FHPlayerPanel", PlayerPanel, "DPanel")

local PillPanel = table.Copy(PlayerPanel)
function PillPanel:PerformLayout(w, h)
	if self.init then return end
	
	local mute = self.mute
	
	if mute then
		mute:SetPos(w - 8 - mute_w, (h * .5) - mute_h * .5)
	end
	
	local avatar = self.avatar
	local avImage = self.avImage
	
	if avatar and avImage then
		avatar:SetVisible(false)
		
		local ply = self.ply
		if IsValid(ply) then
			local ent = ply:GetPillCostume()
			
			if IsValid(ent) and ent.GetPillName then
				local pillName = ent:GetPillName()
				avImage:SetMaterial( killers.GetAvatar( pillName ) )
				
				local fullName = killers.GetFullName(pillName)
				local dataName = killers.GetName(pillName)
				avImage.OnCursorEntered = function(self)
					local key = "fazhunt.animatronics.description." .. dataName
					local localized = language.GetPhrase(key)

					if localized == key then
						showAnimTooltip = false
					else
						showAnimTooltip = true
						animTooltipText = language.SafeGetPhrase(fullName):upper() .. "\n\n" .. localized
					end
				end
				
				avImage.OnCursorExited = function(self)
					showAnimTooltip = false
				end
				
				self.ent = ent
				self.entName = pillName
			end
		end
	end
	
	self.init = true
end

function PillPanel:Paint(w, h)
	local clr = self.clr
	local nick = self.nick or ""
	local nicksub = 22
	
	if self.mute then
		nicksub = nicksub - 4
	end
	
	if self.ent and self.entName then
		clr = killers.GetColor(self.entName)
	end

	surface.SetDrawColor(clr.r, clr.g, clr.b, 255)
	surface.SetMaterial(panel)
	surface.DrawTexturedRect(0, 0, w, h)
	
	local txtX = 0
	local txtClr = color_white

	local ply = self.ply
	local isvalidply = IsValid(ply)
	if isvalidply and playerIcons[ ply:SteamID64() ] then
		local iconS = playerIcons[ ply:SteamID64() ]
		
		if iconsSet[iconS] then
		
			local texture = iconsSet[iconS].texture
			local size = iconsSet[iconS].size
			local color = iconsSet[iconS].color
			txtClr = color

			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(texture)
			surface.DrawTexturedRect(44, (h * .5) - (size * .5) + 1, size, size)
		
			nicksub = nicksub - 2
			txtX = size + 2
		end
	end
	
	nick = utf8.sub(nick, 0, nicksub)
	draw.SimpleText(
		nick,
		"FHScoreboardData14",
		46 + txtX,
		h * .5,
		txtClr, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
	)

	local ply = self.ply
	
	if not IsValid(ply) then return end
	
	local ping = ply:Ping()
	
	draw.SimpleText(
		ping .. " ms",
		"FHScoreboardPing8",
		w * self.ms_x,
		h * .5,
		clr_gray, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
	)
end

vgui.Register("FHPlayerPillPanel", PillPanel, "DPanel")


gameevent.Listen( "player_connect" )
hook.Add("player_connect", "UpdateScoreboardJoin", function()
    if IsValid(scoreboard) then
		timer.Simple(0.5, function()
			
		end)
    end
end)

gameevent.Listen( "player_hurt" )
hook.Add("player_hurt", "fh_playerlist_update_hurt", function()
    if IsValid(scoreboard) then
		timer.Simple(0.5, function()
			
		end)
    end
end)

gameevent.Listen( "player_disconnect" )
hook.Add("player_disconnect", "fh_playerlist_update_disconnect", function()
    if IsValid(scoreboard) then
		timer.Simple(0.5, function()
			
		end)
    end
end)

local boosters = boosters or {}

local file = "https://raw.githubusercontent.com/s3rgeant/fazbearshunt_docs/refs/heads/main/public/verified_players.json"

local function apply_raw_boosters(body, len, headers, code)
	local tbl = util.JSONToTable(body)
	
	if not tbl then return end
	
	for _, v in ipairs(tbl) do
		if v.steam_id then
			playerlist.SetPlayerIcon(v.steam_id, "boosty")
		end
	end
end

local function get_boosters()
    http.Fetch( file,
		function( body, length, headers, code ) -- onSuccess function
			apply_raw_boosters(body, length, headers, code)
		end,
		function( message ) -- onFailure function
			print("[FH] Failed AGAIN to fetch boosty data base :(")
		end
	)
end

hook.Add( "InitPostEntity", "fh_get_boosters", function()
    http.Fetch( file,
		function( body, length, headers, code ) -- onSuccess function
			apply_raw_boosters(body, length, headers, code)
		end,
	
		function( message ) -- onFailure function
			print("[FH] Failed to fetch boosty data base! Will try again in 10 seconds.")
			
			timer.Simple(10, get_boosters)
		end
	)
end)