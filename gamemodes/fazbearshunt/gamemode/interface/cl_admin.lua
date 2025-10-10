fh_admin_panel = fh_admin_panel or nil
local PlayerList, AnimatronicList
local lastSelectedTab = 1

local function AddNetActionButton(parent, x, y, w, h, text, action, onClick)
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
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
    local checkbox = vgui.Create("DCheckBoxLabel", parent)
    checkbox:SetPos(x, y)
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

local function OpenAdminPanel()
    local selectedAnimatron = nil

    if IsValid(fh_admin_panel) then
        fh_admin_panel:Remove()
        gui.EnableScreenClicker(false)
        return
    end

    fh_admin_panel = vgui.Create("DFrame")
    fh_admin_panel:SetSize(600, 500)
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
    PlayerList:SetWidth(200)
    PlayerList:AddColumn(language.GetPhrase("fazhunt.players"))
    PlayerList:AddColumn(language.GetPhrase("fazhunt.team"))
    PlayerList:SetMultiSelect(true)
    createListPlayers()

    AnimatronicList = vgui.Create("DListView", panelPlayers)
    AnimatronicList:SetPos(210, 10)
    AnimatronicList:SetSize(180, 360)
    AnimatronicList:AddColumn(language.GetPhrase("fazhunt.animatronics_team"))
    AnimatronicList:SetMultiSelect(false)
    AnimatronicList.OnRowSelected = function(_, _, row)
        selectedAnimatron = row:GetValue(2)
    end
    createListAnimatronics()

    local actions = {
        {text = "fazhunt.adminpanel.give_killer", action = "give_animatronic"},
        {text = "fazhunt.adminpanel.revive", action = "resurrect"},
        {text = "fazhunt.adminpanel.kill", action = "kill"},
        {text = "fazhunt.adminpanel.highlight", action = "highlight"},
        {},
        {text = "fazhunt.adminpanel.addplayable", action = "addplayable", superadmin = true},
        {text = "fazhunt.adminpanel.removeplayable", action = "removeplayable", superadmin = true}
    }

    local y = 10
    for _, a in ipairs(actions) do
        if a.text then
            if a.superadmin and not LocalPlayer():IsSuperAdmin() then continue end

            local phrase = language.GetPhrase(a.text)
            AddNetActionButton(panelPlayers, 400, y, 180, 30, phrase, a.action, function()
                if a.action:find("playable") then
                    net.Start("AdminAction")
                    net.WriteString(a.action)
                    net.WriteString(selectedAnimatron or "")
                    net.SendToServer()
                    return
                end

                local players = GetSelectedPlayers()
                if #players == 0 then
                    chat.AddText(Color(255, 0, 0), language.GetPhrase("fazhunt.adminpanel.error"))
                    return
                end
				
				if a.action == "give_animatronic" and (!selectedAnimatron or selectedAnimatron:len() < 1) then
                    chat.AddText(Color(255, 0, 0), language.GetPhrase("fazhunt.adminpanel.error_give"))
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
                end
                net.SendToServer()
            end)
        end
        y = y + 40
    end

    sheet:AddSheet(language.GetPhrase("fazhunt.adminpanel.players"), panelPlayers, "icon16/user.png")

    -- === Панель раунда === --
    local roundPanel = vgui.Create("DPanel")
    roundPanel:Dock(FILL)

    local roundActions = {
        {"startgame", "start_round"},
        {"endgame", "end_round"},
        {"endroundstartup", "end_post_round"},
        {"endlobbytimer", "end_lobby_timer"}
    }

    local ry = 10
    for _, a in ipairs(roundActions) do
        AddNetActionButton(roundPanel, 10, ry, 280, 30, language.GetPhrase("fazhunt.adminpanel." .. a[1]), a[2])
        ry = ry + 40
    end

    local sliders = {
        {"highlight.cooldown", "set_highlight_delay", 10, 240, GetConVar("halo_cooldown"):GetInt()},
        {"highlight.time", "set_highlight_duration", 3, 30, GetConVar("halo_time"):GetInt()},
        {"highlight.radius", "set_highlight_distance", 100, 4000, GetConVar("halo_radius"):GetInt()}
    }

    for _, s in ipairs(sliders) do
        AddSlider(roundPanel, 10, ry, language.GetPhrase("fazhunt." .. s[1]), s[3], s[4], s[5], 0, s[2])
        ry = ry + 25
    end

    AddNetActionButton(roundPanel, 10, ry + 10, 150, 40, language.GetPhrase("fazhunt.adminpanel.save_settings"), "fh_auto_map_save")
    AddCheckbox(roundPanel, 170, ry + 25, language.GetPhrase("fazhunt.adminpanel.auto_hl"), conVars.fh_automatic_highlight, "fh_automatic_highlight")
    AddNetActionButton(roundPanel, 10, ry + 60, 150, 40, language.GetPhrase("fazhunt.adminpanel.use_map_settings"), "fh_auto_map_hl")

    sheet:AddSheet(language.GetPhrase("fazhunt.adminpanel.round"), roundPanel, "icon16/joystick.png")

    -- === Панель ивенты === --
    local eventsPanel = vgui.Create("DPanel")
    eventsPanel:Dock(FILL)

    AddCheckbox(eventsPanel, 10, 14, language.GetPhrase("fazhunt.adminpanel.gift_spawning"), conVars.fh_gifts_spawning, "fh_gifts_spawning")
    AddNetActionButton(eventsPanel, 10, 40, 150, 40, language.GetPhrase("fazhunt.adminpanel.spawn_gifts"), "fh_spawn_gifts")

    local lbl = vgui.Create("DLabel", eventsPanel)
    lbl:SetPos(10, 84)
    lbl:SetText(language.GetPhrase("fazhunt.adminpanel.gifts_description"))
    lbl:SetDark(true)
    lbl:SetSize(150, 100)

    sheet:AddSheet(language.GetPhrase("fazhunt.adminpanel.events"), eventsPanel, "icon16/cog.png")

    -- === Экспериментальная панель === --
    local expPanel = vgui.Create("DPanel")
    expPanel:Dock(FILL)

    local ey = 15
    local function step(n) ey = ey + n return ey - n end
	local function justget(n) return ey + n end

    AddCheckbox(expPanel, 10, step(20), language.GetPhrase("fazhunt.adminpanel.damage_animatronics"), conVars.fh_animatronic_immortal, "fh_animatronic_immortal", true)
    AddCheckbox(expPanel, 10, step(20), language.GetPhrase("fazhunt.adminpanel.sfreddy_noclip"), shadow_freddyability, "fuppr_sfreddy_noclip")
    AddCheckbox(expPanel, 10, step(15), language.GetPhrase("fazhunt.adminpanel.quiet_animatronics"), conVars.fh_less_steps, "fh_less_steps")
    AddSlider(expPanel, 10, step(30), language.GetPhrase("fazhunt.adminpanel.max_cupcakes"), 3, 10, conVars.fh_max_cupcakes:GetInt(), 0, "fh_max_cupcakes")
    AddCheckbox(expPanel, 10, step(20), language.GetPhrase("fazhunt.adminpanel.silent_highlight"), conVars.fh_silent_highlight, "fh_silent_highlight")
    AddCheckbox(expPanel, 10, step(20), language.GetPhrase("fazhunt.adminpanel.fh_respawn_dead_animatronics"), conVars.fh_respawn_dead_animatronics, "fh_respawn_dead_animatronics")
	AddSlider(expPanel, 10, step(40), language.GetPhrase("fazhunt.adminpanel.game_duration"), 1, 20, conVars.fh_round_duration:GetInt(), 0, "fh_round_duration")
	
	local DermaList = vgui.Create( "DScrollPanel", expPanel )
	DermaList:SetPos( 10, justget(15) )
	DermaList:SetBackgroundColor( Color(50,50,80) )
	DermaList:SetDrawBackground( true )
	DermaList:SetSize( 570, 220 )

    local lblExp = vgui.Create("DLabel")
	lblExp:SetPos( 10, 5 )
	lblExp:SetSize( 550, 5 )
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
			chat.AddText(Color(255, 0, 0), language.GetPhrase("fazhunt.adminpanel.error_give"))
			return
		end
	
		net.Start("AdminAction")
		net.WriteString("morph_myself")
		net.WriteString(currentAnimatronic or "")
		net.SendToServer()
		
		updatePlayer(LocalPlayer(), "give_animatronic")
	end)

	local w, h = fh_admin_panel:GetSize()
	local CatList = vgui.Create( "DCategoryList", animPanel )
	CatList:SetSize(200, h - 120)
	CatList:SetPos(w - 230, 20)
	
	--[[
		категории для ёбанных аниматроников
	]]
	local entiretyOfPills = pills.getAllPills()
	local registeredPills = killers.getAll()
	
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
		local cat = CatList:Add(categoryName)

		for _, animData in pairs(animList) do
			local button = cat:Add(animData.name)
			button.DoClick = function()
				currentAnimatronic = animData.name
				
				local image = killers.GetAvatar(animData.name)
				if image then
					anim_avatar:SetMaterial(image)
				else
					anim_avatar:SetImage("tools/toolsblack.vmt")
				end
				
				if animData.pill_data then
					local speed = animData.pill_data.moveSpeed
					
					if speed then
						if speed.walk then
							walkTxt:SetText("Walk Speed: " .. speed.walk)
						else
							walkTxt:SetText("Walk Speed: ???")
						end
						if speed.run then
							runTxt:SetText("Run Speed: " .. speed.run)
						else
							runTxt:SetText("Run Speed: ???")
						end
						if speed.ducked then
							crouchTxt:SetText("Crouched Speed: " .. speed.ducked)
						else
							crouchTxt:SetText("Crouched Speed: ???")
						end
					end
				else
					walkTxt:SetText("Walk Speed: ???")
					runTxt:SetText("Run Speed: ???")
					crouchTxt:SetText("Crouched Speed: ???")
				end
			end
		end
	end

    sheet:AddSheet(language.GetPhrase("fazhunt.animatronics_team"), animPanel, "icon16/freddy.png")

    if IsValid(sheet) and sheet.Items[lastSelectedTab] then
        sheet:SetActiveTab(sheet.Items[lastSelectedTab].Tab)
    end
	
    sheet.OnActiveTabChanged = function(p, newTab)
		timer.Simple(0, function()
			for i, item in ipairs(sheet.Items) do
				if item.Tab == p:GetActiveTab() then
					lastSelectedTab = i
					break
				end
			end
		end)
    end
end

function createListPlayers()
    if not IsValid(fh_admin_panel) then return end
    PlayerList:Clear()
    for _, v in player.Iterator() do
        local line = PlayerList:AddLine(v:Nick(), getTeam(v:Team()))
        line.Player = v
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

function createListAnimatronics()
    AnimatronicList:Clear()
    local killers_ = killers.getAll()
    local preferred = table.GetKeys(killers.getAllPreferables(true))

    for k, v in pairs(killers_) do
        local line = AnimatronicList:AddLine(language.GetPhrase(v.fullname), k)
        local hasPref = table.HasValue(preferred, k)
        function line:Paint(w, h)
            local bg = self:IsLineSelected() and (hasPref and Color(0,125,155,200) or Color(255,0,155,200)) or (hasPref and Color(0,255,0,100) or Color(255,0,0,100))
            draw.RoundedBox(0, 0, 0, w, h, bg)
        end
    end
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
