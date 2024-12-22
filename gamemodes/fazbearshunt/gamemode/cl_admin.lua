local AdminPanel = nil
local PlayerList = nil
local AnimatronicList = nil
local lastSelectedTab = 1

local function OpenAdminPanel()
    local selectedAnimatron = nil

    if IsValid(AdminPanel) then 
        AdminPanel:Remove()
        gui.EnableScreenClicker(false)
        return
    end

    AdminPanel = vgui.Create("DFrame")
    AdminPanel:SetSize(600, 500)
    AdminPanel:Center()
    AdminPanel:SetScreenLock(true)
    AdminPanel:SetTitle("Админ-Панель")
    gui.EnableScreenClicker(true)

    AdminPanel.OnClose = function()
        gui.EnableScreenClicker(false)
    end

    -- Создаем PropertySheet для вкладок
    local PropertySheet = vgui.Create("DPropertySheet", AdminPanel)
    PropertySheet:Dock(FILL)

    -- Первая вкладка: управление игроками
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
        selectedAnimatron = row:GetValue(1)
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
					if btn.action != "highlight" then
						updatePlayer(target, btn.action)
					end
                end
                if btn.action == "give_animatronic" then
                    if selectedAnimatron == nil then
                        chat.AddText(Color(255, 0, 0), "Выберите аниматроника!")
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
        {text = language.GetPhrase("fuppr.adminpanel.endpostround"), action = "end_post_round"}
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
        {label = language.GetPhrase("fuppr.highlight.cooldown"), action = "set_highlight_delay", min = 10, max = 240, default = GetConVar('halo_cooldown'):GetInt(), decimals = 0},
        {label = language.GetPhrase("fuppr.highlight.time"), action = "set_highlight_duration", min = 3, max = 30, default = GetConVar('halo_time'):GetInt(), decimals = 0},
        {label = language.GetPhrase("fuppr.highlight.radius"), action = "set_highlight_distance", min = 100, max = 4000, default = GetConVar('halo_radius'):GetInt(), decimals = 0}
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
			net.WriteEntity(nil)
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
		net.WriteEntity(nil)
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
    local killers = killerInfo
    local duoKillers = duoKillerInfo

    for k, v in pairs(duoKillers) do
        killers[k] = v
    end

    for _, v in pairs(killers) do
        AnimatronicList:AddLine(v.name)
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
