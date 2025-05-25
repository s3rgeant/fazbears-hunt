fh_admin_panel = nil
local PlayerList = nil
local AnimatronicList = nil
local lastSelectedTab = 1

local function OpenAdminPanel()
    local selectedAnimatron = nil

    if IsValid(fh_admin_panel) then
		fh_admin_panel:Remove()
		gui.EnableScreenClicker(false)
		return
    end

	--[[
    if IsValid(fh_admin_panel) then
		if fh_admin_panel:IsVisible() then 
			fh_admin_panel:Hide()
			gui.EnableScreenClicker(false)
			return
		else
			createListPlayers()
			fh_admin_panel:Show()
			gui.EnableScreenClicker(true)
			return
		end
    end
	]]--

    fh_admin_panel = vgui.Create("DFrame")
    fh_admin_panel:SetSize(600, 500)
    fh_admin_panel:Center()
    fh_admin_panel:SetScreenLock(true)
    fh_admin_panel:SetTitle("Админ-Панель")
    gui.EnableScreenClicker(true)

    fh_admin_panel.OnClose = function()
        gui.EnableScreenClicker(false)
    end

    local PropertySheet = vgui.Create("DPropertySheet", fh_admin_panel)
    PropertySheet:Dock(FILL)

    local PlayerManagementPanel = vgui.Create("DPanel")
    PlayerManagementPanel:Dock(FILL)

    PlayerList = vgui.Create("DListView", PlayerManagementPanel)
    PlayerList:Dock(LEFT)
    PlayerList:SetWidth(200)
    PlayerList:AddColumn("Игроки")
    PlayerList:AddColumn("Команда")
    PlayerList:SetMultiSelect(true)
    createListPlayers()

    AnimatronicList = vgui.Create("DListView", PlayerManagementPanel)
    AnimatronicList:SetPos(210, 10)
    AnimatronicList:SetSize(180, 360)
    AnimatronicList:AddColumn("Аниматроники")
    AnimatronicList:SetMultiSelect(false)
    AnimatronicList.OnRowSelected = function(panel, rowIndex, row)
        selectedAnimatron = row:GetValue(2)
		
		print(selectedAnimatron)
    end
    createListAnimatronics()

    local function GetSelectedByList(list)
        local selectedLines = list:GetSelected()
        local players = {}
        if selectedLines and #selectedLines > 0 then
            for _, line in pairs(selectedLines) do
                if IsValid(line.Player) then
                    table.insert(players, line.Player)
                end
            end
            return players
        else
            return nil
        end
    end

    local actions = {
        {text = language.GetPhrase("fuppr.adminpanel.give_killer"), action = "give_animatronic"},
        {text = language.GetPhrase("fuppr.adminpanel.revive"), action = "resurrect"},
        {text = language.GetPhrase("fuppr.adminpanel.kill"), action = "kill"},
        {text = language.GetPhrase("fuppr.adminpanel.highlight"), action = "highlight"}
    }

    local yPos = 10
    for _, btn in ipairs(actions) do
        local button = vgui.Create("DButton", PlayerManagementPanel)
        button:SetPos(400, yPos)
        button:SetSize(180, 30)
        button:SetText(btn.text)
        button.DoClick = function()
            local targets = GetSelectedByList(PlayerList)
            if targets and #targets > 0 then
                net.Start("AdminAction")
                net.WriteString(btn.action)
                net.WriteUInt(#targets, 8)
                for _, target in pairs(targets) do
                    net.WriteEntity(target)
					if (btn.action == "give_animatronic" and selectedAnimatron != nil) or btn.action == "resurrect" or btn.action == "kill" then
						updatePlayer(target, btn.action)
					end
                end
                if btn.action == "give_animatronic" then
                    if selectedAnimatron == nil then
                        chat.AddText(Color(255, 0, 0), "Выберите аниматроника!")
                        net.WriteString(tostring(""))
                    else
                        net.WriteString(tostring(selectedAnimatron))
                    end
                end
                net.SendToServer()
            else
                chat.AddText(Color(255, 0, 0), "Выберите игроков!")
            end
        end
        yPos = yPos + 40
    end

    PropertySheet:AddSheet("Игроки", PlayerManagementPanel, "icon16/user.png")

    local RoundManagementPanel = vgui.Create("DPanel")
    RoundManagementPanel:Dock(FILL)

    local roundActions = {
        {text = language.GetPhrase("fuppr.adminpanel.startgame"), action = "start_round"},
        {text = language.GetPhrase("fuppr.adminpanel.endgame"), action = "end_round"},
        {text = language.GetPhrase("fuppr.adminpanel.endroundstartup"), action = "end_post_round"},
        {text = language.GetPhrase("fuppr.adminpanel.endlobbytimer"), action = "end_lobby_timer"}
    }

    local roundY = 10
    for _, btn in ipairs(roundActions) do
        local button = vgui.Create("DButton", RoundManagementPanel)
        button:SetPos(10, roundY)
        button:SetSize(280, 30)
        button:SetText(btn.text)
        button.DoClick = function()
            net.Start("AdminAction")
            net.WriteString(btn.action)
            net.SendToServer()
        end
        roundY = roundY + 40
    end

    local sliders = {
        {label = language.GetPhrase("fuppr.highlight.cooldown"), action = "set_highlight_delay", min = 10, max = 240, default = GetConVar('halo_cooldown'):GetInt(), decimals = 0, callback = "halo_cooldown"},
        {label = language.GetPhrase("fuppr.highlight.time"), action = "set_highlight_duration", min = 3, max = 30, default = GetConVar('halo_time'):GetInt(), decimals = 0, callback = "halo_time"},
        {label = language.GetPhrase("fuppr.highlight.radius"), action = "set_highlight_distance", min = 100, max = 4000, default = GetConVar('halo_radius'):GetInt(), decimals = 0, callback = "halo_radius"}
    }

    local sliderY = roundY
    for _, sld in ipairs(sliders) do
        local slider = vgui.Create("DNumSlider", RoundManagementPanel)
        slider:SetPos(20, sliderY)
        slider:SetSize(390, 30)
        slider:SetText(sld.label)
		slider:SetDark(true)
        slider:SetMin(sld.min)
        slider:SetMax(sld.max)
		slider:SetDefaultValue(sld.default)
		slider:SetValue(sld.default)
        slider:SetDecimals(sld.decimals)
        slider.OnValueChanged = function(self, value)
            net.Start("AdminAction")
            net.WriteString(sld.action)
            net.WriteFloat(value)
            net.SendToServer()
        end
		
        sliderY = sliderY + 40
    end

	local button = vgui.Create("DButton", RoundManagementPanel)
	button:SetPos(10, sliderY)
	button:SetSize(200, 40)
	button:SetText("Автоматическая настройка просвета")
	button:SetDark(true)
	function button:DoClick(bool)
		net.Start("AdminAction")
		net.WriteString('fh_auto_map_hl')
		net.SendToServer()
	end

	local button = vgui.Create("DButton", RoundManagementPanel)
	button:SetPos(235, sliderY)
	button:SetSize(200, 40)
	button:SetText("Сохранить настройки")
	button:SetDark(true)
	function button:DoClick(bool)
		net.Start("AdminAction")
		net.WriteString('fh_auto_map_save')
		net.SendToServer()
	end

    PropertySheet:AddSheet("Раунд", RoundManagementPanel, "icon16/joystick.png")
	
    local fh_events_management = vgui.Create("DPanel")
    fh_events_management:Dock(FILL)

	local button = vgui.Create("DCheckBoxLabel", fh_events_management)
	button:SetPos(10, 14)
	//button:SetSize(280, 30)
	button:SetText("Спавн подарков")
	button:SetDark(true)
	button:SetChecked(conVars.fh_gifts_spawning:GetBool())
	function button:OnChange(bool)
		net.Start("AdminAction")
		net.WriteString('fh_gifts_spawning')
		net.WriteBool(bool)
		net.SendToServer()
	end

	local button = vgui.Create("DButton", fh_events_management)
	button:SetPos(10, 40)
	button:SetSize(150, 40)
	button:SetText("Выдать всем подарки")
	button:SetDark(true)
	function button:DoClick(bool)
		net.Start("AdminAction")
		net.WriteString('fh_spawn_gifts')
		net.SendToServer()
	end
	
	local DLabel = vgui.Create( "DLabel", fh_events_management )
	DLabel:SetPos( 10, 84 )
	DLabel:SetText( "Подарки спавнятся \nс задержкой \nот 1 до 12 секунд.\n\nПодарки спавнятся с \nшансом 77%" )
	DLabel:SetDark(true)
	DLabel:SetSize(150, 100)

    PropertySheet:AddSheet("Ивенты", fh_events_management, "icon16/cog.png")

    local ExperimentalPanel = vgui.Create("DPanel")
    ExperimentalPanel:Dock(FILL)

	local button = vgui.Create("DCheckBoxLabel", ExperimentalPanel)
	button:SetPos(10, 15)
	//button:SetSize(280, 30)
	button:SetText("Урон по аниматроникам")
	button:SetDark(true)
	button:SetChecked(!conVars.fh_animatronic_immortal:GetBool())
	function button:OnChange(bool)
		net.Start("AdminAction")
		net.WriteString('fh_animatronic_immortal')
		net.WriteBool(!bool)
		net.SendToServer()
	end

	local button = vgui.Create("DCheckBoxLabel", ExperimentalPanel)
	button:SetPos(10, 35)
	button:SetText("Полёт Шедоу Фредди")
	button:SetDark(true)
	button:SetChecked(shadow_freddyability:GetBool())
	function button:OnChange(bool)
		net.Start("AdminAction")
		net.WriteString('fuppr_sfreddy_noclip')
		net.WriteBool(bool)
		net.SendToServer()
	end

	local button = vgui.Create("DCheckBoxLabel", ExperimentalPanel)
	button:SetPos(10, 55)
	button:SetText("Тихие аниматроники")
	button:SetDark(true)
	button:SetChecked(conVars.fh_less_steps:GetBool())
	function button:OnChange(bool)
		net.Start("AdminAction")
		net.WriteString('fh_less_steps')
		net.WriteBool(bool)
		net.SendToServer()
	end

	local button = vgui.Create("DNumSlider", ExperimentalPanel)
	button:SetPos(10, 75)
	button:SetText("Максимум Кексов")
	button:SetMin( 3 )	
	button:SetMax( 10 )	
	button:SetDecimals( 0 )		
	button:SetDark(true)
	button:SetSize(220, 10)
	button:SetDefaultValue(3)
	button:SetValue(conVars.fh_max_cupcakes:GetInt())
	
	button.OnValueChanged = function( self, value )
		net.Start("AdminAction")
		net.WriteString('fh_max_cupcakes')
		net.WriteFloat(value)
		net.SendToServer()
	end
	
	local DLabel = vgui.Create( "DLabel", ExperimentalPanel )
	DLabel:SetPos( 220, 1 )
	DLabel:SetText( "- Если выключить полёт Шедоу Фредди, \nон всё ещё сможет использовать способность ухода под пол, \nно не сможет летать, но будет передвигаться по полу как игрок, \nи будет уметь проходить сквозь двери.\n" ..
	"\n- Если включить тихих аниматроников, \nто звуки шагов аниматроников будут играть только тогда, \nкогда аниматроник будет рендериться. \n(У аниматроников начнутся сложности с \nпрослеживанием своих тиммейтов через стены)")
	DLabel:SetDark(true)
	DLabel:SetSize(345, 200)

    PropertySheet:AddSheet("Эксперименты", ExperimentalPanel, "icon16/chart_line.png")
	
    if IsValid(PropertySheet) then
        PropertySheet:SetActiveTab(PropertySheet.Items[lastSelectedTab].Tab)
    end
	
    PropertySheet.OnActiveTabChanged = function(sheet, newTab)
		timer.Simple(0, function()
			for i, item in ipairs(PropertySheet.Items) do
				if item.Tab == sheet:GetActiveTab() then
					lastSelectedTab = i -- Сохраняем индекс текущей вкладки
					break
				end
			end
		end)
    end
	
end

function createListPlayers()
	if !IsValid(fh_admin_panel) then return end
    PlayerList:Clear()
    for _, v in pairs(player.GetAll()) do
        local team = getTeam(v:Team())
        local line = PlayerList:AddLine(v:Nick(), team)
        line.Player = v
    end
end

function updatePlayer(ply, team)
    for _, line in pairs(PlayerList:GetLines()) do
        if line.Player == ply then
            line:SetValue(2, getTeam(team))
        end
    end
end

function createListAnimatronics()
    AnimatronicList:Clear()
    local killers = table.Copy(killerData)

    for k, v in pairs(killers) do
        AnimatronicList:AddLine(language.GetPhrase(v.fullname), k)
    end
end

concommand.Add("open_admin_panel", function()
    if LocalPlayer():IsAdmin() then
        OpenAdminPanel()
    end
end)

hook.Add("OnSpawnMenuOpen", "BindAdminPanel", function()
    if not gui.IsConsoleVisible() and LocalPlayer():IsAdmin() then
		OpenAdminPanel()
    end
end)

gameevent.Listen( "player_connect" )
hook.Add("player_connect", "sexmortalcombat", function( data )
	timer.Simple(1, function()
		createListPlayers()
	end)
end)

gameevent.Listen( "player_disconnect" )
hook.Add( "player_disconnect", "player_disconnect_example", function( data )
	timer.Simple(1, function()
		createListPlayers()
	end)
end )