fh_admin_panel = nil
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
    checkbox:SetChecked(invert and not val or val)
    function checkbox:OnChange(b)
        net.Start("AdminAction")
        net.WriteString(action)
        net.WriteBool(invert and not b or b)
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
    AnimatronicList:AddColumn(language.GetPhrase("fuppr.animatronics_team"))
    AnimatronicList:SetMultiSelect(false)
    AnimatronicList.OnRowSelected = function(_, _, row)
        selectedAnimatron = row:GetValue(2)
    end
    createListAnimatronics()

    local actions = {
        {text = "fuppr.adminpanel.give_killer", action = "give_animatronic"},
        {text = "fuppr.adminpanel.revive", action = "resurrect"},
        {text = "fuppr.adminpanel.kill", action = "kill"},
        {text = "fuppr.adminpanel.highlight", action = "highlight"},
        {},
        {text = "fuppr.adminpanel.addplayable", action = "addplayable", superadmin = true},
        {text = "fuppr.adminpanel.removeplayable", action = "removeplayable", superadmin = true}
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
                    chat.AddText(Color(255, 0, 0), language.GetPhrase("fuppr.adminpanel.error"))
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
        AddNetActionButton(roundPanel, 10, ry, 280, 30, language.GetPhrase("fuppr.adminpanel." .. a[1]), a[2])
        ry = ry + 40
    end

    local sliders = {
        {"highlight.cooldown", "set_highlight_delay", 10, 240, GetConVar("halo_cooldown"):GetInt()},
        {"highlight.time", "set_highlight_duration", 3, 30, GetConVar("halo_time"):GetInt()},
        {"highlight.radius", "set_highlight_distance", 100, 4000, GetConVar("halo_radius"):GetInt()}
    }

    for _, s in ipairs(sliders) do
        AddSlider(roundPanel, 10, ry, language.GetPhrase("fuppr." .. s[1]), s[3], s[4], s[5], 0, s[2])
        ry = ry + 25
    end

    AddNetActionButton(roundPanel, 10, ry + 10, 150, 40, language.GetPhrase("fazhunt.adminpanel.save_settings"), "fh_auto_map_save")
    AddCheckbox(roundPanel, 170, ry + 25, language.GetPhrase("fazhunt.adminpanel.auto_hl"), conVars.fh_automatic_highlight, "fh_automatic_highlight")
    AddNetActionButton(roundPanel, 10, ry + 60, 150, 40, language.GetPhrase("fazhunt.adminpanel.use_map_settings"), "fh_auto_map_hl")

    sheet:AddSheet(language.GetPhrase("fazhunt.adminpanel.round"), roundPanel, "icon16/joystick.png")

    -- === Панель событий === --
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
    AddCheckbox(expPanel, 10, step(20), language.GetPhrase("fazhunt.adminpanel.fh_respawn_dead_animatronics"), conVars.fh_respawn_dead_animatronics, "fh_respawn_dead_animatronics", true)
	--AddNumberWang(expPanel, 10, step(40), "Game Duration", fh.GetGameDuration(), 0, "set_game_duration")
	
	local DCollapsible = vgui.Create( "DCollapsibleCategory", expPanel )
	DCollapsible:SetLabel( "READ ME" )	
	DCollapsible:SetPos( 10, justget(15) )
	DCollapsible:SetSize( 400, 25 )
	DCollapsible:SetExpanded( false )

    local lblExp = vgui.Create("DLabel", DCollapsible)
    lblExp:SetPos(10, 1)
    lblExp:SetSize(345, 200)
    lblExp:SetDark(true)
    lblExp:SetText(language.GetPhrase("fazhunt.adminpanel.experiments_description01") .. language.GetPhrase("fazhunt.adminpanel.experiments_description02"))

    sheet:AddSheet(language.GetPhrase("fazhunt.adminpanel.experiments"), expPanel, "icon16/chart_line.png")

    if IsValid(sheet) and sheet.Items[lastSelectedTab] then
        sheet:SetActiveTab(sheet.Items[lastSelectedTab].Tab)
    end
	
    sheet.OnActiveTabChanged = function(p, newTab)
		timer.Simple(0, function()
			for i, item in ipairs(sheet.Items) do
				if item.Tab == p:GetActiveTab() then
					lastSelectedTab = i -- Сохраняем индекс текущей вкладки
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
    for _, line in ipairs(PlayerList:GetLines()) do
        if line.Player == ply then
            line:SetValue(2, getTeam(team))
        end
    end
end

function createListAnimatronics()
    AnimatronicList:Clear()
    local killers = table.Copy(killerData)
    local preferred = table.GetKeys(getAllPreferables(true))

    for k, v in pairs(killers) do
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
