local AdminPanel = nil
local PlayerList = nil
local AnimatronicList = nil

local function OpenAdminPanel()
	local selectedAnimatron = nil
	
    if IsValid(AdminPanel) then AdminPanel:Remove() end

    AdminPanel = vgui.Create("DFrame")
    AdminPanel:SetSize(600, 400)
    AdminPanel:Center()
	AdminPanel:SetScreenLock(true)
    AdminPanel:SetTitle("Админ-Панель")
	gui.EnableScreenClicker(true)
	
	AdminPanel.OnClose = function()
		gui.EnableScreenClicker(false)
	end

    -- Левая сторона: список игроков
    PlayerList = vgui.Create("DListView", AdminPanel)
    PlayerList:SetPos(10, 30)
    PlayerList:SetSize(180, 360)
    PlayerList:AddColumn("Игроки")
    PlayerList:AddColumn("Команда")
	PlayerList:SetMultiSelect(true)
	updateListPlayers()
	
    AnimatronicList = vgui.Create("DListView", AdminPanel)
    AnimatronicList:SetPos(490, 30)
    AnimatronicList:SetSize(100, 240)
    AnimatronicList:AddColumn("Аниматроники")
	AnimatronicList:SetMultiSelect(false)
	AnimatronicList.OnRowSelected = function( panel, rowIndex, row )
		selectedAnimatron = row:GetValue( 1 )
	end
	updateListAnimatronics()

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
        {text = language.GetPhrase("fuppr.adminpanel.startgame"), action = "start_round"},
        {text = language.GetPhrase("fuppr.adminpanel.hl_everyone"), action = "highlight_all"},
        {text = language.GetPhrase("fuppr.adminpanel.endgame"), action = "end_round"}
    }

    local yPos = 30
    for _, btn in ipairs(actions) do
        local button = vgui.Create("DButton", AdminPanel)
        button:SetPos(200, yPos)
        button:SetSize(280, 30)
        button:SetText(btn.text)
        button.DoClick = function()
			if btn.action == "give_animatronic" or btn.action == "resurrect" or btn.action == "kill" then
				local targets = GetSelectedByList(PlayerList)
				if targets and #targets > 0 then
					net.Start("AdminAction")
					net.WriteString(btn.action)
					net.WriteUInt(#targets, 8)
					for _, target in pairs(targets) do
						net.WriteEntity(target)
					end
					if btn.action == 'give_animatronic' then
						if selectedAnimatron == nil then
							chat.AddText(Color(255,0,0), language.GetPhrase("fuppr.adminpanel.error_give"))
						else
							net.WriteString(tostring(selectedAnimatron))
						end
					end
					net.SendToServer()
				else
					chat.AddText(Color(255,0,0), language.GetPhrase("fuppr.adminpanel.error"))
				end
			else
				net.Start("AdminAction")
				net.WriteString(btn.action)
				net.SendToServer()
			end
		end
        yPos = yPos + 40
    end

    local sliders = {
        {label = language.GetPhrase("fuppr.highlight.cooldown"), action = "set_highlight_delay", min = 10, max = 240, default = GetConVar('halo_cooldown'):GetInt(), decimals = 0},
        {label = language.GetPhrase("fuppr.highlight.time"), action = "set_highlight_duration", min = 3, max = 30, default = GetConVar('halo_time'):GetInt(), decimals = 0},
        {label = language.GetPhrase("fuppr.highlight.radius"), action = "set_highlight_distance", min = 100, max = 4000, default = GetConVar('halo_radius'):GetInt(), decimals = 0}
    }

    local sliderY = 270
    for _, sld in ipairs(sliders) do
        local slider = vgui.Create("DNumSlider", AdminPanel)
        slider:SetPos(200, sliderY)
        slider:SetSize(390, 30)
        slider:SetText(sld.label)
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
end
	
function updateListPlayers()
	PlayerList:Clear()

	for _, v in pairs(player.GetAll()) do
		local team = 'Выжившие'
		
		if v:Team() == 2701 then 
			team = 'Аниматроники'
		elseif v:Team() == TEAM_SPECTATOR then 
			team = ' '
		end
		
		local line = PlayerList:AddLine(v:Nick(), team)
		line.Player = v
	end
end
	
function updateListAnimatronics()
	AnimatronicList:Clear()
	
	local killers = killerInfo
	local duoKillers = duoKillerInfo
	
	for k, v in pairs(duoKillers) do
		killers[k] = v
	end

	for _, v in pairs(killers) do
		local line = AnimatronicList:AddLine(v.name)
	end
end

concommand.Add("open_admin_panel", function()
    if LocalPlayer():IsAdmin() then
        OpenAdminPanel()
    end
end)

hook.Add("PlayerButtonDown", "BindAdminPanel", function(ply, button)
	if button == KEY_Q and !gui.IsConsoleVisible() and LocalPlayer():IsAdmin() then
		OpenAdminPanel()
	end
end)