fh_admin_panel = fh_admin_panel or nil
local PlayerList, AnimatronicList
local lastSelectedTab = 1

admin = admin or {}

deliverData = deliverData or {}

net.Receive("FH_AdminDeliverData", function()
	local dType = net.ReadBit()
	
	if dType == 1 then
		local dName = net.ReadString()
		deliverData[dName] = {}
		
		local dNext = net.ReadBit()
		
		if dNext == 1 then
			local num = net.ReadUInt(8)
			
			for i = 1, num do
				local dName2 = net.ReadString()
				deliverData[dName][dName2] = {}
				
				local num = net.ReadUInt(8)
				for i = 1, num do
					local key = net.ReadString()
					local value = net.ReadString()
					
					deliverData[dName][dName2][key] = value
				end
			end
		else
			local num = net.ReadUInt(8)
			for i = 1, num do
				local key = net.ReadString()
				local value = net.ReadString()
				
				deliverData[dName][key] = value
			end
		end
	else
		
		local key = net.ReadString()
		local value = net.ReadString()
		
		deliverData[dName][key] = value
	end
end)

local errorClr = Color(255,0,0)

local animSettings = {}

function admin.AddAnimatronicSetting(name, panel_data)
	if !animSettings[name] then animSettings[name] = {} end
	
	if table.HasValue(animSettings[name], panel_data) then return end
	
	table.insert(animSettings[name], panel_data)
end

local function AddNetActionButton(parent, x, y, w, h, text, action, onClick)
    local btn = vgui.Create("DButton", parent)
    if x and y then btn:SetPos(x, y) end
    btn:SetSize(w, h)
    btn:SetText(text)
    btn.DoClick = onClick or function()
        net.Start("AdminAction")
        net.WriteString(action)
        net.SendToServer()
    end
    return btn
end

local function AddCheckbox(parent, x, y, text, convar, action, invert)
	if not convar then return end

    local checkbox = vgui.Create("DCheckBoxLabel", parent)
	if x and y then checkbox:SetPos(x, y) end
    checkbox:SetText(text)
    checkbox:SetDark(true)
    local val = convar:GetBool()
	if invert then val = not val end
    checkbox:SetChecked(val)
    function checkbox:OnChange(b)
		local bool = b
		if invert then bool = not b end
	
        net.Start("AdminAction")
        net.WriteString(action)
        net.WriteBool(bool)
        net.SendToServer()
    end
    return checkbox
end

local function AddSlider(parent, x, y, label, min, max, default, decimals, action)
    local slider = vgui.Create("DNumSlider", parent)
    slider:SetPos(x, y)
    slider:SetSize(390, 30)
    slider:SetText(label)
    slider:SetDark(true)
    slider:SetMin(min)
    slider:SetMax(max)
    slider:SetDefaultValue(default)
    slider:SetDecimals(decimals)
    slider:SetValue(default)
    slider.OnValueChanged = function(_, value)
        net.Start("AdminAction")
        net.WriteString(action)
        net.WriteFloat(value)
        net.SendToServer()
    end
    return slider
end

local function AddNumberWang(parent, x, y, label, min, max, default, decimals, action)
	local numwang = vgui.Create("DNumberWang", parent)
	numwang:SetPos(85, 25)
	numwang:SetSize(45, 30)
    numwang:SetDark(true)
	numwang:SetMin(min)
	numwang:SetMax(max)
    numwang:SetValue(default)
    numwang:SetDefaultValue(default)
    numwang:SetDecimals(decimals)
	
    numwang.OnValueChanged = function(_, value)
        net.Start("AdminAction")
        net.WriteString(action)
        net.WriteFloat(value)
        net.SendToServer()
    end
    return numwang
end

admin.AddAnimatronicSetting("pill_sfreddy2", {
    class = "DCheckBoxLabel",
    setup = function(panel)
        panel:SetText(language.GetPhrase("fazhunt.adminpanel.sfreddy_noclip"))
        panel:SetDark(true)
        panel:SetChecked(shadow_freddyability:GetBool())
        function panel:OnChange(b)
            net.Start("AdminAction")
            net.WriteString("fh_sfreddy_noclip")
            net.WriteBool(b)
            net.SendToServer()
        end
    end
})

admin.AddAnimatronicSetting("pill_plushtrap", {
    class = "DNumSlider",
    setup = function(panel)
		panel:SetDark(true)
		panel:SetMin(500)
		panel:SetMax(4000)
		panel:SetSize(90, 20)
		panel:SetDefaultValue(plushtrap_visionrange:GetDefault())
		panel:SetDecimals(0)
		panel:SetValue(plushtrap_visionrange:GetInt())
		
		local text = panel:Find("DLabel")
		text:Hide()
		
        function panel:OnValueChanged(value)
            net.Start("AdminAction")
            net.WriteString("fh_plushtrap_highlight_range")
			net.WriteFloat(value)
            net.SendToServer()
        end
    end,
	description = language.GetPhrase("fazhunt.adminpanel.plushtrap_vision_range")
})

admin.AddAnimatronicSetting("pill_wfreddy2", {
    class = "DCheckBoxLabel",
    setup = function(panel)
        panel:SetText(language.GetPhrase("fazhunt.adminpanel.wfreddy_blindrage_npcs"))
        panel:SetDark(true)
        panel:SetChecked(npc_blindrage:GetBool())
        function panel:OnChange(b)
            net.Start("AdminAction")
            net.WriteString("fh_blindrage_npcs")
            net.WriteBool(b)
            net.SendToServer()
        end
    end,
	description = language.GetPhrase("fazhunt.adminpanel.not_supported")
})

local dermaActionMenu
local playerActions = {
	{text = "fazhunt.adminpanel.heal", action = "heal", icon = "heart"},
	{text = "fazhunt.adminpanel.give_gift", action = "give_gift", icon = "package_green"},
	{text = "fazhunt.adminpanel.give_all_weapons", action = "give_all_weapons", icon = "gun"},
	{text = "fazhunt.adminpanel.return_spawn", action = "return_spawn", icon = "arrow_undo"},
	{text = "fazhunt.adminpanel.tp_to_teammate", action = "tp_to_teammate", icon = "group_go"},
	{text = "fazhunt.adminpanel.unstuck", action = "unstuck", icon = "arrow_out"},
	{text = "fazhunt.adminpanel.give_immune_gfreddy", action = "immune_gfreddy", icon = "gfreddy"},
	{text = "fazhunt.adminpanel.deprive_immune_gfreddy", action = "un_immune_gfreddy", icon = "gfreddy"},
	{text = "fazhunt.adminpanel.high_anim_chance", action = "set_high_anim", superadmin=true, icon="pill_add"},
	{text = "fazhunt.adminpanel.low_anim_chance", action = "set_low_anim", superadmin=true, icon="pill_delete"},
}

local clrred = Color(255,0,0)
local function f_() end
local function askServerDeleteMapData(map, line, m)
	net.Start("FH_AdminDeleteMapData")
		net.WriteString(map)
	net.SendToServer()
	
	line.Paint = function(self,w,h) draw.RoundedBox( 0, 0, 0, w, h, clrred ) end
	line.OnRightClick = f_
	line.OnLeftClick = f_
	line:SetSelectable(false)
	m:UnselectAll()
	if dermaActionMenu then dermaActionMenu:Hide() end
end
local function askServerUpdateMapData(map)
	net.Start("FH_AdminUpdateMapData")
		net.WriteString(map)
	net.SendToServer()
end

local function GetSelectedPlayers()
    local selectedLines = PlayerList:GetSelected()
    local players = {}
    for _, line in ipairs(selectedLines or {}) do
        if IsValid(line.Player) then
            table.insert(players, line.Player)
        end
    end
    return players
end

local blackie = Color(0,0,0,240)

local myself
local silent_give_killer = false
local onplace_give_killer = false
local secretly_give_killer = false
local function OpenAdminPanel()
    local selectedAnimatron = nil

    if IsValid(fh_admin_panel) then
		if fh_admin_panel:IsVisible() then
			fh_admin_panel:Hide()
			if fh_admin_panel.OnHidden then
				fh_admin_panel:OnHidden()
			end
			gui.EnableScreenClicker(false)
		else
			fh_admin_panel:Show()
			gui.EnableScreenClicker(true)
			createListPlayers()
			createListAnimatronics()
		end
        return
    end
	
	myself = myself or LocalPlayer()

    fh_admin_panel = vgui.Create("DFrame")
    fh_admin_panel:SetSize(700, 500)
    fh_admin_panel:Center()
    fh_admin_panel:SetScreenLock(true)
    fh_admin_panel:SetTitle(language.GetPhrase("fazhunt.adminpanel"))
    gui.EnableScreenClicker(true)

    fh_admin_panel.OnClose = function()
        gui.EnableScreenClicker(false)
    end

    local sheet = vgui.Create("DPropertySheet", fh_admin_panel)
    sheet:Dock(FILL)

    -- === Панель управления игроками === --
    local panelPlayers = vgui.Create("DPanel")
    panelPlayers:Dock(FILL)

    PlayerList = vgui.Create("DListView", panelPlayers)
    PlayerList:Dock(LEFT)
    PlayerList:SetWidth(250)
    PlayerList:AddColumn(language.GetPhrase("fazhunt.players"))
    PlayerList:AddColumn(language.GetPhrase("fazhunt.team"))
    PlayerList:SetMultiSelect(true)
    createListPlayers()

    AnimatronicList = vgui.Create("DListView", panelPlayers)
    AnimatronicList:SetPos(260, 10)
    AnimatronicList:SetSize(180, 320)
    AnimatronicList:AddColumn(language.GetPhrase("fazhunt.animatronics_team"))
    AnimatronicList:SetMultiSelect(false)
    AnimatronicList.OnRowSelected = function(_, _, row)
        selectedAnimatron = row:GetValue(2)
    end
    createListAnimatronics()
	
    if myself:IsSuperAdmin() then 
		AddNetActionButton(panelPlayers, 260, 340, 160, 30, language.GetPhrase("fazhunt.adminpanel.addplayable"), "addplayable", function()
			net.Start("AdminAction")
			net.WriteString("addplayable")
			net.WriteString(selectedAnimatron or "")
			net.SendToServer()
		end)
		
		AddNetActionButton(panelPlayers, 260, 380, 160, 30, language.GetPhrase("fazhunt.adminpanel.removeplayable"), "removeplayable", function()
			net.Start("AdminAction")
			net.WriteString("removeplayable")
			net.WriteString(selectedAnimatron or "")
			net.SendToServer()
		end)
	end

    local actions = {
        {text = "fazhunt.adminpanel.give_killer", action = "give_animatronic"},
        {},
        {},
        {},
        {text = "fazhunt.adminpanel.revive", action = "resurrect"},
        {text = "fazhunt.adminpanel.kill", action = "kill"},
        {text = "fazhunt.adminpanel.highlight", action = "highlight"},
    }

    local y = 10
	local x = 460
    for _, a in ipairs(actions) do
        if a.text then
            if a.superadmin and not myself:IsSuperAdmin() then continue end

            local phrase = language.GetPhrase(a.text)
            AddNetActionButton(panelPlayers, x, y, 180, 30, phrase, a.action, function()
                if a.action:find("playable") then
                    net.Start("AdminAction")
                    net.WriteString(a.action)
                    net.WriteString(selectedAnimatron or "")
                    net.SendToServer()
                    return
                end

                local players = GetSelectedPlayers()
                if #players == 0 then
                    chat.AddText(errorClr, language.GetPhrase("fazhunt.adminpanel.error"))
                    return
                end
				
				if a.action == "give_animatronic" and (!selectedAnimatron or selectedAnimatron:len() < 1) then
                    chat.AddText(errorClr, language.GetPhrase("fazhunt.adminpanel.error_give"))
                    return
				end

                net.Start("AdminAction")
                net.WriteString(a.action)
                net.WriteUInt(#players, 8)
                for _, ply in ipairs(players) do
                    net.WriteEntity(ply)
                    if a.action == "give_animatronic" or a.action == "resurrect" or a.action == "kill" then
                        updatePlayer(ply, a.action)
                    end
                end
                if a.action == "give_animatronic" then
                    net.WriteString(selectedAnimatron or "")
                    net.WriteBit(silent_give_killer)
                    net.WriteBit(onplace_give_killer)
                    net.WriteBit(secretly_give_killer)
                end
                net.SendToServer()
            end)
        end
        y = y + (a.text and 40 or 20)
    end
	
    local checkbox = vgui.Create("DCheckBoxLabel", panelPlayers)
	checkbox:SetPos(x, 45)
    checkbox:SetText(language.GetPhrase("fazhunt.adminpanel.give_killer_silent"))
    checkbox:SetDark(true)
    checkbox:SetChecked(silent_give_killer)
    function checkbox:OnChange(b)
		silent_give_killer = b
    end
	
    local checkbox = vgui.Create("DCheckBoxLabel", panelPlayers)
	checkbox:SetPos(x, 65)
    checkbox:SetText(language.GetPhrase("fazhunt.adminpanel.give_killer_onplace"))
    checkbox:SetDark(true)
    checkbox:SetChecked(onplace_give_killer)
    function checkbox:OnChange(b)
		onplace_give_killer = b
    end
	
    local checkbox = vgui.Create("DCheckBoxLabel", panelPlayers)
	checkbox:SetPos(x, 85)
    checkbox:SetText(language.GetPhrase("fazhunt.adminpanel.give_killer_secretly"))
    checkbox:SetDark(true)
    checkbox:SetChecked(secretly_give_killer)
    function checkbox:OnChange(b)
		secretly_give_killer = b
    end
	
	local actionBox = vgui.Create( "DComboBox", panelPlayers )
	actionBox:SetPos( x, y )
	actionBox:SetSize( 180, 20 )
	actionBox:SetValue( language.GetPhrase("fazhunt.adminpanel.more_actions") )
	actionBox:SetSortItems( false )
	
    for _, a in ipairs(playerActions) do
		if a.superadmin and !myself:IsSuperAdmin() then continue end
		actionBox:AddChoice( language.GetPhrase(a.text), nil, false, a.icon and "icon16/" .. a.icon .. ".png" or nil )
	end
	actionBox.OnSelect = function( self, index, value )
		actionBox:SetValue( language.GetPhrase("fazhunt.adminpanel.more_actions") )

		local players = GetSelectedPlayers()
		if #players == 0 then
			chat.AddText(errorClr, language.GetPhrase("fazhunt.adminpanel.error"))
			return
		end
				
		net.Start("AdminAction")
		net.WriteString(playerActions[index].action)
		net.WriteUInt(#players, 8)
		for _, ply in ipairs(players) do
			net.WriteEntity(ply)
		end
		net.SendToServer()
	end
    y = y + 30
	
    local lblExp = vgui.Create("DLabel", panelPlayers)
	lblExp:SetPos( x, y )
	lblExp:SetSize( 180, 15 )
    lblExp:SetText(language.GetPhrase("fazhunt.adminpanel.give_weaponry") .. ":")
    lblExp:SetDark(true)
    lblExp:SetAutoStretchVertical(true)
    lblExp:SetWrap(true)
	
    y = y + 20
	
	local weaponryBox = vgui.Create( "DComboBox", panelPlayers )
	weaponryBox:SetPos( x, y )
	weaponryBox:SetSize( 180, 20 )
	weaponryBox:SetValue( "..." )
	
	local weapons = weapons.GetList()
	for _, wep in ipairs(weapons) do
		if wep.ClassName and wep.Spawnable then
			local name = wep.PrintName or wep.ClassName
			local suffix = ""
			local icon = nil
			
			if wep.ClassName:match("fh") == "fh" then
				suffix = "(FH) "
			end
			
			if name:StartsWith("#") then
				name = language.GetPhrase(string.sub(name, 2, name:len()))
			end
			
			if wep.WepSelectIcon and isnumber(wep.WepSelectIcon) then
				icon = surface.GetTextureNameByID(wep.WepSelectIcon)
			end
			
			weaponryBox:AddChoice( suffix .. name, wep.ClassName, false, icon )
		end
	end
	weaponryBox.OnSelect = function( self, index, data )
		weaponryBox:SetValue( "..." )

		local players = GetSelectedPlayers()
		if #players == 0 then
			chat.AddText(errorClr, language.GetPhrase("fazhunt.adminpanel.error"))
			return
		end
				
		net.Start("AdminAction")
		net.WriteString("give_weapon")
		net.WriteUInt(#players, 8)
		for _, ply in ipairs(players) do
			net.WriteEntity(ply)
		end
		net.WriteString(self:GetOptionData(index))
		net.SendToServer()
	end
   
   sheet:AddSheet(language.GetPhrase("fazhunt.adminpanel.players"), panelPlayers, "icon16/user.png")
	
    -- === Панель раунда === --
    local roundPanel = vgui.Create("DPanel")
    roundPanel:Dock(FILL)
	
	local roundSheet = vgui.Create( "DPropertySheet", roundPanel )
	roundSheet:Dock( FILL )

		--[[
				УПРАВЛЕНИЕ
		]]--
		local genericPanel = vgui.Create( "DPanel", roundSheet )
		roundSheet:AddSheet( "Управление", genericPanel, "icon16/clock.png" )

		local roundActions = {
			{"startgame", "start_round"},
			{"endgame", "end_round"},
			{"endroundstartup", "end_post_round"},
			{"endlobbytimer", "end_lobby_timer"},
			{"pausegame", "pause_game"},
		}

		local ry = 10
		for _, a in ipairs(roundActions) do
			if a[1] and a[2] then
				local button = AddNetActionButton(genericPanel, 10, ry, 280, 30, language.GetPhrase("fazhunt.adminpanel." .. a[1]), a[2])
				
				local onlyGameOn = a[1] == "endgame" or a[1] == "pausegame" or a[1] == "endroundstartup"
				local onlyLobby = a[1] == "startgame" or a[1] == "endlobbytimer"
				local onlyGameStart = a[1] == "endroundstartup"
				
				function button:PaintOver( w, h )
					if onlyGameOn and !GetGlobal2Bool("gameOn", false)
					or onlyLobby and GetGlobal2Bool("gameOn", false)
					or onlyGameStart and GetGlobal2Bool("roundActive", false)
					then
						draw.RoundedBox( 0, 0, 0, w, h, blackie )
					end
				end
			end
			ry = ry + 40
		end

		AddSlider(genericPanel, 10, ry, language.GetPhrase("fazhunt.adminpanel.game_duration"), 1, 20, conVars.fh_round_duration:GetInt(), 0, "fh_round_duration")
		--[[
				ИВЕНТЫ
		]]--
		local eventsPanel = vgui.Create( "DPanel", roundSheet )
		roundSheet:AddSheet( language.GetPhrase("fazhunt.adminpanel.events"), eventsPanel, "icon16/cog.png" )
		
		AddCheckbox(eventsPanel, 10, 14, language.GetPhrase("fazhunt.adminpanel.gift_spawning"), conVars.fh_gifts_spawning, "fh_gifts_spawning")
		AddCheckbox(eventsPanel, 180, 14, language.GetPhrase("fazhunt.adminpanel.goldenfreddy_spawning"), conVars.fh_goldenfreddy_spawning, "fh_goldenfreddy_spawning")
		AddNetActionButton(eventsPanel, 10, 40, 150, 40, language.GetPhrase("fazhunt.adminpanel.spawn_gifts"), "fh_spawn_gifts")

		local lbl = vgui.Create("DLabel", eventsPanel)
		lbl:SetPos(10, 84)
		lbl:SetText(language.GetPhrase("fazhunt.adminpanel.gifts_description"))
		lbl:SetDark(true)
		lbl:SetSize(150, 100)
		
		--[[
				КАРТА
		]]--
		local highlightPanel = vgui.Create( "DPanel", roundSheet )
		roundSheet:AddSheet( "Карта", highlightPanel, "icon16/map.png" )

		local sliders = {
			{"highlight.cooldown", "set_highlight_delay", 10, 240, GetConVar("halo_cooldown"):GetInt()},
			{"highlight.time", "set_highlight_duration", 3, 30, GetConVar("halo_time"):GetInt()},
			{"highlight.radius", "set_highlight_distance", 100, 4000, GetConVar("halo_radius"):GetInt()},
			{"adminpanel.max_cupcakes", "fh_max_cupcakes", 3, 10, conVars.fh_max_cupcakes:GetInt()},
		}
		
		local btns = {}

		local ry = 10
		for _, s in ipairs(sliders) do
			local sldr = AddSlider(highlightPanel, 10, ry, language.GetPhrase("fazhunt." .. s[1]), s[3], s[4], s[5], 0, s[2])
			btns[s[1]] = sldr
			ry = ry + 25
		end
		
		local function accordMapData(d)
			local s1 = btns["highlight.cooldown"]
			local s2 = btns["highlight.time"]
			local s3 = btns["highlight.radius"]
			local s4 = btns["adminpanel.max_cupcakes"]
			
			local d1 = d["halo_cooldown"]
			local d2 = d["halo_time"]
			local d3 = d["halo_radius"]
			local d4 = d["fh_max_cupcakes"]
			
			s1:SetValue(d1)
			s2:SetValue(d2)
			s3:SetValue(d3)
			s4:SetValue(d4)
		end
		local function openMapMenu(map, line, mapList)
			local menu = DermaMenu()
			
			menu:AddOption( "#spawnmenu.menu.copy_dnd", function() accordMapData( deliverData["MapData"][map] ) end ):SetIcon( "icon16/page_copy.png" )
			menu:AddOption( "#spawnmenu.savechanges", function() askServerUpdateMapData(map) end ):SetIcon( "icon16/page_save.png" )
			menu:AddOption( "#spawnmenu.menu.delete", function() askServerDeleteMapData(map, line, mapList) end ):SetIcon( "icon16/page_delete.png" )
			menu:Open()
			dermaActionMenu = menu
		end
		
		local curMap = game.GetMap()

		AddNetActionButton(highlightPanel, 10, ry + 10, 150, 40, language.GetPhrase("fazhunt.adminpanel.save_settings"), "fh_auto_map_save")
		AddCheckbox(highlightPanel, 170, ry + 35, language.GetPhrase("fazhunt.adminpanel.auto_hl"), conVars.fh_automatic_highlight, "fh_automatic_highlight")
		--AddNetActionButton(highlightPanel, 10, ry + 60, 150, 40, language.GetPhrase("fazhunt.adminpanel.use_map_settings"), "fh_auto_map_hl")

		local mapData = table.Copy(deliverData["MapData"])
		if mapData then
			local mapList = vgui.Create( "DListView", highlightPanel )
			mapList:Dock( RIGHT )
			mapList:SetWidth(250)
			mapList:SetMultiSelect( false )
			mapList:SetSortable( false )
			mapList:AddColumn( "#map" )
			
			if mapData[curMap] then
				local line = mapList:AddLine( curMap, mapData )
				mapList:SelectItem(line)
				
				line.OnRightClick = function() openMapMenu(curMap, line, mapList) end
				line.OnSelect = function() openMapMenu(curMap, line, mapList) end
				local l = mapList:AddLine( "" ) l.Paint = function(w,h) end
				mapData[curMap] = nil
			end

			for map, d in pairs(mapData) do
				local line = mapList:AddLine( map, d )
				
				line.OnRightClick = function() openMapMenu(map, line, mapList) end
				line.OnSelect = function() openMapMenu(map, line, mapList) end
			end
		end
		
		sheet:AddSheet(language.GetPhrase("fazhunt.adminpanel.round"), roundPanel, "icon16/joystick.png")

    -- === Экспериментальная панель === --
    local expPanel = vgui.Create("DPanel")
    expPanel:Dock(FILL)

    local ey = 15
    local function step(n) ey = ey + n return ey - n end
	local function justget(n) return ey + n end

    AddCheckbox(expPanel, 10, step(20), language.GetPhrase("fazhunt.adminpanel.damage_animatronics"), conVars.fh_animatronic_immortal, "fh_animatronic_immortal", true)
    AddCheckbox(expPanel, 10, step(20), language.GetPhrase("fazhunt.adminpanel.quiet_animatronics"), conVars.fh_less_steps, "fh_less_steps")
    AddCheckbox(expPanel, 10, step(20), language.GetPhrase("fazhunt.adminpanel.silent_highlight"), conVars.fh_silent_highlight, "fh_silent_highlight")
    AddCheckbox(expPanel, 10, step(20), language.GetPhrase("fazhunt.adminpanel.fh_respawn_dead_animatronics"), conVars.fh_respawn_dead_animatronics, "fh_respawn_dead_animatronics")
    AddCheckbox(expPanel, 10, step(20), language.GetPhrase("fazhunt.adminpanel.fair_highlight"), conVars.fair_hl, "fh_fair_highlight")
    AddCheckbox(expPanel, 10, step(20), language.GetPhrase("fazhunt.adminpanel.dangerous_cupcakes"), GetConVar("fh_cupcake_blast"), "fh_cupcake_blast")
    AddCheckbox(expPanel, 10, step(20), language.GetPhrase("fazhunt.adminpanel.bear5_killermask_last"), conVars.fh_bear5_killermask_last, "fh_bear5_killermask_last")
    AddCheckbox(expPanel, 10, step(20), language.GetPhrase("fazhunt.adminpanel.fast_roundrestart"), conVars.fh_fast_roundrestart, "fh_fast_roundrestart")
    AddCheckbox(expPanel, 10, step(20), language.GetPhrase("fazhunt.adminpanel.banana_ragdollize"), conVars.fh_banana_ragdollize, "fh_banana_ragdollize")
	
	local DermaList = vgui.Create( "DScrollPanel", expPanel )
	DermaList:SetPos( 10, justget(15) )
	DermaList:SetBackgroundColor( Color(50,50,80) )
	DermaList:SetDrawBackground( true )
	DermaList:SetSize( 640, 220 )

    local lblExp = vgui.Create("DLabel")
	lblExp:SetPos( 10, 5 )
	lblExp:SetSize( 620, 5 )
    lblExp:SetText(language.GetPhrase("fazhunt.adminpanel.experiments_description01") .. "\n\n" .. language.GetPhrase("fazhunt.adminpanel.experiments_description02"))
    --lblExp:SetDark(true)
    lblExp:SetAutoStretchVertical(true)
    lblExp:SetWrap(true)
	DermaList:AddItem( lblExp )

    sheet:AddSheet(language.GetPhrase("fazhunt.adminpanel.experiments"), expPanel, "icon16/chart_line.png")
	
    local animPanel = vgui.Create("DPanel")
    animPanel:Dock(FILL)
	
	local anim_avatar = vgui.Create("DImage", animPanel)
	anim_avatar:SetPos(10, 20)
	anim_avatar:SetSize(125, 125)
	anim_avatar:SetImage("tools/toolsblack.vmt")

    local runTxt = vgui.Create("DLabel", animPanel)
	runTxt:SetPos( 10, 190 )
	runTxt:SetSize( 120, 25 )
    runTxt:SetText("Run Speed: ???")
    runTxt:SetDark(true)
    runTxt:SetAutoStretchVertical(true)
    runTxt:SetWrap(true)

    local walkTxt = vgui.Create("DLabel", animPanel)
	walkTxt:SetPos( 10, 210 )
	walkTxt:SetSize( 120, 25 )
    walkTxt:SetText("Walk Speed: ???")
    walkTxt:SetDark(true)
    walkTxt:SetAutoStretchVertical(true)
    walkTxt:SetWrap(true)

    local crouchTxt = vgui.Create("DLabel", animPanel)
	crouchTxt:SetPos( 10, 230 )
	crouchTxt:SetSize( 120, 25 )
    crouchTxt:SetText("Crouched Speed: ???")
    crouchTxt:SetDark(true)
    crouchTxt:SetAutoStretchVertical(true)
    crouchTxt:SetWrap(true)
	
	local currentAnimatronic = nil
	
	AddNetActionButton(animPanel, 10, 150, 125, 30, language.GetPhrase("fazhunt.adminpanel.morph_myself"), "morph_myself", function()
		if !currentAnimatronic or currentAnimatronic:len() < 1 then
			chat.AddText(errorClr, language.GetPhrase("fazhunt.adminpanel.error_give"))
			return
		end
	
		net.Start("AdminAction")
		net.WriteString("morph_myself")
		net.WriteString(currentAnimatronic or "")
		net.SendToServer()
		
		updatePlayer(myself, "give_animatronic")
	end)

	local w, h = fh_admin_panel:GetSize()
	local CatList = vgui.Create( "DCategoryList", animPanel )
	CatList:SetSize(200, h - 120)
	CatList:SetPos(w - 230, 20)
	
	local background = vgui.Create( "DCategoryList", animPanel )
	background:SetSize(300, h - 120)
	background:SetPos(150, 20)
	
	local animSetList = vgui.Create( "DScrollPanel", animPanel )
	animSetList:SetSize(300, h - 120)
	animSetList:SetPos(150, 20)
	
	--[[
		категории для ёбанных аниматроников
	]]
	local entiretyOfPills = pills.getAllPills()
	local registeredPills = killers.GetAll()
	
	local list = {}
	local categories = {}
	
	if not table.IsEmpty(entiretyOfPills) then
		for k, v in pairs(entiretyOfPills) do
			if registeredPills[k] then
				list[k] = registeredPills[k]
				list[k].registered = true

				local ctgry = list[k].category or "Uncategorized"

				categories[ctgry] = categories[ctgry] or {}

				table.insert(categories[ctgry], {
					name = k,
					fh_data = list[k],
					pill_data = v
				})
			else
				list[k] = {}

				local ctgry = list[k].category or "Unlisted"

				categories[ctgry] = categories[ctgry] or {}

				table.insert(categories[ctgry], {
					name = k,
					fh_data = list[k],
					pill_data = v
				})
			end
		end
	end

	for categoryName, animList in pairs(categories) do
		local localize = language.GetPhrase("fazhunt.adminpanel.categories." .. categoryName:lower())
	
		local bettername = localize ~= "fazhunt.adminpanel.categories." .. categoryName:lower() and localize or categoryName
		local cat = CatList:Add(bettername)

		for _, animData in pairs(animList) do
			local name = animData.fh_data and animData.fh_data.fullname
		
			local button = cat:Add(name and language.GetPhrase(name) or animData.name)
			
			button.DoClick = function()
				currentAnimatronic = animData.name
				
				local image = killers.GetAvatar(currentAnimatronic)
				if image then
					anim_avatar:SetMaterial(image)
				else
					anim_avatar:SetImage("tools/toolsblack.vmt")
				end

				if animData.pill_data then
					local speed = animData.pill_data.moveSpeed
					if speed then
						walkTxt:SetText("Walk Speed: " .. (speed.walk or "???"))
						runTxt:SetText("Run Speed: " .. (speed.run or "???"))
						crouchTxt:SetText("Crouched Speed: " .. (speed.ducked or "???"))
					else
						walkTxt:SetText("Walk Speed: ???")
						runTxt:SetText("Run Speed: ???")
						crouchTxt:SetText("Crouched Speed: ???")
					end
				else
					walkTxt:SetText("ERROR! No Data presents.")
					runTxt:SetText("")
					crouchTxt:SetText("")
				end
				
				for _, pnl in pairs(animSetList:GetCanvas():GetChildren()) do
					pnl:SetParent(nil)
					pnl:SetVisible(false)
				end
				
				if animSettings[currentAnimatronic] then
					for _, panelInfo in ipairs(animSettings[currentAnimatronic]) do
						if not istable(panelInfo) then continue end

						local newPanel = vgui.Create(panelInfo.class, animSetList)
						local panelText = nil
						if panelInfo.setup and isfunction(panelInfo.setup) then
							panelInfo.setup(newPanel)
						end
						if panelInfo.description then
							panelText = vgui.Create("DLabel", animSetList)
						end
						if panelText then
							panelText:SetText(panelInfo.description)
							panelText:SetDark(true)
							panelText:SetTextColor(Color(66, 140, 255))
							panelText:Dock( TOP )
							panelText:DockMargin( 5, 0, 5, 5 )
						end
						newPanel:Dock( TOP )
						newPanel:DockMargin( 5, 5, 5, 5 )
						animSetList:AddItem(newPanel)
					end
				end
			end
			button:SetName(animData.name)
		end
	end

    sheet:AddSheet(language.GetPhrase("fazhunt.animatronics_team"), animPanel, "icon16/freddy.png")
	
    local modPanel = vgui.Create("DPanel")
    modPanel:Dock(FILL)

    sheet:AddSheet(language.GetPhrase("fazhunt.adminpanel.modifiers"), modPanel, "icon16/lightning.png")

    if IsValid(sheet) and sheet.Items[lastSelectedTab] then
        sheet:SetActiveTab(sheet.Items[lastSelectedTab].Tab)
    end

    fh_admin_panel.OnHidden = function()
		actionBox:CloseMenu()
		weaponryBox:CloseMenu()
		if dermaActionMenu and IsValid(dermaActionMenu) then
			dermaActionMenu:Hide()
		end
    end
end

function createListPlayers()
    if not IsValid(fh_admin_panel) then return end
    if IsValid(PlayerList) then
		local lastSelected = GetSelectedPlayers()
		
		myself = myself or LocalPlayer()
	
        PlayerList:Clear()
        for _, v in player.Iterator() do
            local line = PlayerList:AddLine(v:Nick(), getTeam(v:Team()))
            line.Player = v
			
			if #lastSelected >= 1 and table.HasValue(lastSelected,v) or #lastSelected <= 0 and v == myself then
				PlayerList:SelectItem(line)
			end
		
			line.OnRightClick = function()
				local menu = DermaMenu()
				
				local players = GetSelectedPlayers()
				if #players == 1 then
					menu:AddOption( "#spawnmenu.menu.copy", function() SetClipboardText( v:Nick() ) end ):SetIcon( "icon16/page_copy.png" )
				end
				for _, a in ipairs(playerActions) do
					if a.superadmin and !myself:IsSuperAdmin() then continue end
					
					local function optionFunc(self, index)
						local players = GetSelectedPlayers()
						if #players == 0 then
							chat.AddText(errorClr, language.GetPhrase("fazhunt.adminpanel.error"))
							return
						end
								
						net.Start("AdminAction")
						net.WriteString(a.action)
						net.WriteUInt(#players, 8)
						for _, ply in ipairs(players) do
							net.WriteEntity(ply)
						end
						net.SendToServer()
					end
					
					local panel = menu:AddOption( language.GetPhrase(a.text), optionFunc):SetIcon(a.icon and "icon16/" .. a.icon .. ".png" or nil)
				end
				menu:Open()
				dermaActionMenu = menu
			end
        end
    end
end

function updatePlayer(ply, team)
    if IsValid(PlayerList) then
        for _, line in ipairs(PlayerList:GetLines()) do
            if line.Player == ply then
                line:SetValue(2, getTeam(team))
            end
        end
    end
end

-- Selected
local clrs = {
	[0] = Color(70,0,0,200), -- Unpreferred
	[1] = Color(0,125,155,200), -- Preferred
	[2] = Color(190,92,0,200), -- Preferred Secondary
}

-- UnSelected
local clrs_d = {
	[0] = Color(238,49,49,40), -- Unpreferred
	[1] = Color(20,238,90,50), -- Preferred
	[2] = Color(210,130,0,200), -- Preferred Secondary
}

function createListAnimatronics()
    if !IsValid(AnimatronicList) then return end
    AnimatronicList:Clear()
    local killers_ = killers.GetAll()
    local preferred = table.GetKeys(killers.GetAllPreferables(true))

    for k, v in pairs(killers_) do
        local line = AnimatronicList:AddLine(language.GetPhrase(v.fullname), k, v.category or "")
		local hasPref = v.preferable == true
		local isSecondary = v.secondary == true
        function line:Paint(w, h)
            local bg = self:IsLineSelected() and (hasPref and (isSecondary and clrs[2] or clrs[1]) or clrs[0]) or (hasPref and (isSecondary and clrs_d[2] or clrs_d[1]) or clrs_d[0])
            draw.RoundedBox(0, 0, 0, w, h, bg)
        end
		
		line.OnRightClick = function()
			local menu = DermaMenu()
			menu:AddOption( "#spawnmenu.menu.copy", function() SetClipboardText( k ) end ):SetIcon( "icon16/page_copy.png" )
			menu:Open()
		end
    end
	
	AnimatronicList:SortByColumn(3)
end

-- Команды

concommand.Add("open_admin_panel", function()
    if LocalPlayer():IsAdmin() then OpenAdminPanel() end
end)

hook.Add("OnSpawnMenuOpen", "BindAdminPanel", function()
    if not gui.IsConsoleVisible() and LocalPlayer():IsAdmin() then OpenAdminPanel() end
end)

-- Автообновление списка

gameevent.Listen("player_connect")
hook.Add("player_connect", "fh_adminpanel_update_connect", function()
    timer.Simple(1, createListPlayers)
end)

gameevent.Listen("player_disconnect")
hook.Add("player_disconnect", "fh_adminpanel_update_disconnect", function()
    timer.Simple(1, createListPlayers)
end)
