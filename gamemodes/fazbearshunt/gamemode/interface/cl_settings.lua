settings = settings or {}
settings.categories = {}
settings.catOrder = {}

local color_fazbearshunt = Color(238, 49, 49)
local clr_fh_r = color_fazbearshunt.r
local clr_fh_g = color_fazbearshunt.g
local clr_fh_b = color_fazbearshunt.b

local _font = "Share Tech Mono"
local fonts =

surface.CreateFont("settings.Tab", 
	{font = _font, size = 18, weight = 500, extended = true})
surface.CreateFont("settings.Label", 
	{font = _font, size = 16, weight = 500, extended = true})
surface.CreateFont("settings.Divider", 
	{font = _font, size = 32, weight = 500, extended = true})
surface.CreateFont("settings.Value", 
	{font = _font, size = 16, weight = 500, extended = true})
surface.CreateFont("settings.Small", 
	{font = _font, size = 12, weight = 500, extended = true})
surface.CreateFont("settings.BtnON", 
	{font = _font, size = 16, weight = 500, extended = true})
surface.CreateFont("settings.BtnOFF", 
	{font = _font, size = 14, weight = 500, extended = true})

local C = {
	border = Color(65, 68, 68, 255),
	text = Color(235, 235, 235),
}

local panelTypes = {
	["slider"] = "FHSettingsSlider",
	["toggle"] = "FHSettingsToggle",
	["combo"] = "FHSettingsCombo",
	["button"] = "FHSettingsButton",
	
	["divider"] = "FHSettingsDivider",
}

local color_surv = team.GetColor( TEAM_SURVIVOR )
local surv_r, surv_g, surv_b = color_surv.r, color_surv.g, color_surv.b

local function ReadSetting(setting)
	if not setting.convar then return setting.default end
	local cv = GetConVar(setting.convar)
	if not cv then return setting.default end
	if setting.type == "toggle" then return cv:GetBool() end
	if setting.type == "slider" then return tonumber(cv:GetString()) or setting.default or 0 end
	return cv:GetString()
end

local function WriteSetting(setting, value)
	if setting.convar then
		local output = value
		if isbool(value) then output = value and "1" or "0" end
		RunConsoleCommand(setting.convar, tostring(output))
	end
	if setting.onChanged then setting.onChanged(value) end
end

local function lerpit(a,b,c)
	return Lerp(FrameTime() * c, a, b)
end

function settings.RegisterCategory(id, title)
	if not isstring(id) or not isstring(title) then return end
	if not settings.categories[id] then
		settings.categories[id] = {id = id, title = title, settings = {}}
		settings.catOrder[#settings.catOrder + 1] = id
	else
		settings.categories[id].title = title
	end
end

function settings.RegisterSetting(categoryID, setting)
	local category = settings.categories[categoryID]
	if not category or not istable(setting) or not isstring(setting.label) or not isstring(setting.type) then return false end
	if not panelTypes[setting.type] then return false end
	if setting.default == nil then
		if setting.type == "toggle" then setting.default = false
		elseif setting.type == "slider" then setting.default = 0
		else setting.default = "" end
	end
	if setting.convar and not GetConVar(setting.convar) then
		local default = isbool(setting.default) and (setting.default and "1" or "0") or tostring(setting.default)
		CreateClientConVar(setting.convar, default, true, false)
	end
	category.settings[#category.settings + 1] = setting
	return true
end

local set_rec = Material("vgui/base/settings/set_rec.png", "smooth")
local function DrawRow(panel, label)
	local w, h = panel:GetSize()
	
	surface.SetMaterial( set_rec )
	surface.SetDrawColor( color_surv )
	surface.DrawTexturedRect( 0, 0, w, h)
	
	draw.SimpleText(label or "", "settings.Label", 12, h * 0.5, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

local function ReadNumber(value, decimals)
	decimals = decimals or 0
	if decimals <= 0 then return tostring(math.Round(tonumber(value) or 0)) end
	return string.format("%0." .. decimals .. "f", tonumber(value) or 0)
end

local function ApplyValue(panel, value)
	panel.Value = value
	WriteSetting(panel.Setting, value)
end

local function SyncPanel(panel)
	if not panel.Setting then return end
	if CurTime() < (panel.NextSync or 0) then return end
	panel.NextSync = CurTime() + 0.2
	local value = ReadSetting(panel.Setting)
	if value ~= panel.Value then panel.Value = value end
end

local exacts = Material("vgui/base/settings/exact_settings.png", "smooth")
--local exacts_w, exacts_h = exacts:Width(), exacts:Height()
local apply = Material("vgui/base/settings/apply_button.png", "smooth")
local apply_w, apply_h = apply:Width(), apply:Height()

	-- САМО ЕБУЧЕЕ НАСТРОЙКО ГЛАВНОЕ
local WINDOW = {}
function WINDOW:Init()
	self:SetTitle("")
	self:ShowCloseButton(false)
	self:SetDraggable(false)
	self:SetSizable(false)
	self:SetDeleteOnClose(true)
	self:SetSize(math.min(ScrW() - 32, 1022), math.min(ScrH() - 32, 702))
	self:Center()
	self:MakePopup()
	self.Tabs = {}
	--self:SetAlpha(0)

	local tabOrder = {}
	for _, id in ipairs(settings.catOrder) do
		tabOrder[#tabOrder + 1] = {id = id, width = id == "performance" and 210 or 137}
	end

	local totalW = 0
	for _, item in ipairs(tabOrder) do
		if settings.categories[item.id] then totalW = totalW + item.width end
	end

	local availableCount = 0
	for _, item in ipairs(tabOrder) do if settings.categories[item.id] then availableCount = availableCount + 1 end end
	totalW = totalW + math.max(0, availableCount - 1) * 16
	local scale = math.min(1, (self:GetWide() - 36) / math.max(totalW, 1))
	local x = (self:GetWide() - totalW * scale) * 0.5

	for _, item in ipairs(tabOrder) do
		local category = settings.categories[item.id]
		if category then
			local tab = vgui.Create("FHSettingsTab", self)
			tab:SetTab(category.title, item.id, self)
			local width = item.width * scale
			tab:SetPos(x, 18)
			tab:SetSize(width, 37)
			self.Tabs[#self.Tabs + 1] = tab
			x = x + width + 16 * scale
		end
	end

	self.ContentPanel = vgui.Create("DPanel", self)
	self.ContentPanel:SetPos(math.floor(self:GetWide() * 0.142), 86)
	self.ContentPanel:SetSize(math.floor(self:GetWide() * 0.716), self:GetTall() - 25)
	self.ContentPanel.Paint = function(pnl, w, h)
		surface.SetMaterial( exacts )
		surface.SetDrawColor( 255, 255, 255 )
		surface.DrawTexturedRect( 0, 0, w, h)
	end
	
	local x, y = self:GetPos()
	local esc = vgui.Create("DButton")
	esc:SetPos(x+self:GetWide() - apply_w, y+ (-apply_h - 4))
	esc:SetSize(apply_w, apply_h)
	esc:SetText("#fazhunt.apply")
	esc:SetFont("settings.Value")
	esc.DoClick = function() settings.Close() end
	esc.Paint = function(pnl, w, h)
		surface.SetMaterial( apply )
		surface.SetDrawColor( 255, 255, 255 )
		surface.DrawTexturedRect( 0, 0, w, h)
	end
	
	self.EscButton = esc

	self:SetCategory(settings.categories.gameplay and "gameplay" or settings.catOrder[1])
end

function WINDOW:OnRemove()
	if self.EscButton then
		self.EscButton:Remove()
	end
end

local c1, c2 = Color(10, 12, 12), Color(70, 74, 74)
function WINDOW:SetCategory(categoryID)
	if not settings.categories[categoryID] then return end
	self.ActiveCategory = categoryID
	for _, tab in ipairs(self.Tabs) do tab.Active = tab.CategoryID == categoryID end
	
	if IsValid(self.Scroll) then self.Scroll:Remove() end
	self.Scroll = vgui.Create("DScrollPanel", self.ContentPanel)
	self.Scroll:Dock(FILL)
	self.Scroll:DockMargin(0, 0, 0, 0)
	local bar = self.Scroll:GetVBar()
	bar:SetWide(5)
	bar.Paint = function(pnl, w, h) draw.RoundedBox(2, 0, 0, w, h, c1) end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(pnl, w, h) draw.RoundedBox(2, 0, 0, w, h, c2) end
	
	local category = settings.categories[categoryID]
	for index, setting in ipairs(category.settings) do
		local panelType = panelTypes[setting.type]
		
		local otstup = 4
		
		if setting.type == "divider" then
			otstup = 32
		elseif category.settings[index - 1] and category.settings[index - 1].type and category.settings[index - 1].type == "divider" then
			otstup = 30
		elseif index == 1 then
			otstup = 20
		end
		
		local row = vgui.Create(panelType, self.Scroll:GetCanvas())
		row:SetSetting(setting)
		row:Dock(TOP)
		row:DockMargin(35, otstup, 35, 0)
		--row:SetTall(42)
	end
end

function WINDOW:PerformLayout(w, h)
	if IsValid(self.ContentPanel) then
		self.ContentPanel:SetPos(math.floor(w * 0.142), 86)
		self.ContentPanel:SetSize(math.floor(w * 0.716), h - 111)
	end
end

--function WINDOW:Think()
	--local a = self:GetAlpha()
	--self:SetAlpha(Lerp(FrameTime() * 15, a, 255))
--end

local wholew = Material("vgui/base/settings/wholewindow.png", "smooth")
local susline = Material("vgui/base/settings/susline.png", "smooth")
local sus_w, sus_h = susline:Width(), susline:Height()
function WINDOW:Paint(w, h)
	surface.SetMaterial( wholew )
	surface.SetDrawColor( 255, 255, 255, 250 )
	surface.DrawTexturedRect( 0, 0, w, h)
	
	surface.SetMaterial( susline )
	surface.SetDrawColor( 255, 255, 255, 250 )
	surface.DrawTexturedRect( w * .5 - (sus_w * .5), 68, sus_w, sus_h)
end
vgui.Register("FHSettingsWindow", WINDOW, "DFrame")


	-- КАТЕГОРИИ СТРОЙКА
local TAB = {}
function TAB:Init()
    self:SetText("")
    self:SetMouseInputEnabled(true)
end

function TAB:SetTab(title, categoryID, parent)
    self.Title = title
    self.CategoryID = categoryID
    self.Owner = parent
end

function TAB:DoClick()
    if IsValid(self.Owner) then self.Owner:SetCategory(self.CategoryID) end
	surface.PlaySound("ui/hover.wav")
end

local tab_mat = Material("vgui/base/settings/tab.png", "smooth")
local gr = Material("gui/gradient_down", "smooth")
function TAB:Paint(w, h)
	local active = self.Owner and self.Owner.ActiveCategory == self.CategoryID
	
	surface.SetMaterial( tab_mat )
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawTexturedRect( 0, 0, w, h)
	
	if active then
		surface.SetMaterial( gr )
		surface.SetDrawColor( clr_fh_r, clr_fh_g, clr_fh_b, 15 )
		surface.DrawTexturedRect( 1, 1, w - 2, h * .5)
	end
	
	draw.SimpleText(self.Title or "", "settings.Tab", w * 0.5, h * 0.5, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end
vgui.Register("FHSettingsTab", TAB, "DButton")


	-- ПЕРЕКЛЮЧАЛКА
local TOGGLE = {}
function TOGGLE:Init()
	self:SetTall(42)
	self:SetText("")
	self:SetMouseInputEnabled(true)
	self.Value = false
	self.Animation = {}
end

function TOGGLE:SetSetting(setting)
	self.Setting = setting
	self.Label = setting.label or ""
	self.Value = tobool(ReadSetting(setting))
end

function TOGGLE:OnMousePressed(code)
	if code ~= MOUSE_LEFT then return end
	ApplyValue(self, not tobool(self.Value))
	surface.PlaySound("ui/click.wav")
end

function TOGGLE:Think()
	SyncPanel(self)
end

local switch_off = Material("vgui/base/settings/switch_off.png", "smooth")
local switch_on = Material("vgui/base/settings/switch_on.png", "smooth")
local toggleW, toggleH = switch_off:Width(), switch_off:Height()
local color_gray = Color(125,125,125)

function TOGGLE:Paint(w, h)
	DrawRow(self, self.Label)
	local x = w * 0.4
	local y = (h - 30) * 0.5
	
	local isvalue = self.Value
	
	local invert = self.Setting.invert
	if invert then isvalue = !isvalue end
	
	local curMat = isvalue and switch_on or switch_off
	local l_txtClr = isvalue and color_white or color_gray
	local r_txtClr = isvalue and color_gray or color_white
	local lFont = isvalue and "settings.BtnON" or "settings.BtnOFF"
	local rFont = isvalue and "settings.BtnOFF" or "settings.BtnON"
	
	surface.SetMaterial( curMat )
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawTexturedRect( x, y, toggleW, toggleH)
	
	local h_h = h*.5
	draw.SimpleText("#fazhunt.on", lFont, x + toggleW * .25, h_h, l_txtClr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText("#fazhunt.off", rFont, x + toggleW * .75, h_h, r_txtClr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end
vgui.Register("FHSettingsToggle", TOGGLE, "DButton")


	-- КНОПКА КНОПОНЬКА
local BUTTON = {}
function BUTTON:Init()
	self:SetTall(42)
	self:SetText("")
	self:SetMouseInputEnabled(true)
	self.Value = false
	self.Animation = {}
end

function BUTTON:SetSetting(setting)
	self.Setting = setting
	self.Label = setting.label or ""
	self.Value = setting.Default
	self.Func = setting.func
end

function BUTTON:OnMousePressed(code)
	if code ~= MOUSE_LEFT then return end
	if self.Func then self.Func(self, self.Setting) end
	surface.PlaySound("ui/click.wav")
end

function BUTTON:Think()
	SyncPanel(self)
end

local editor = Material("vgui/base/settings/editor.png", "smooth")
local editorW, editorH = editor:Width(), editor:Height()

function BUTTON:Paint(w, h)
	DrawRow(self, self.Label)
	local x = w * 0.4
	local y = (h - 30) * 0.5
	
	local value = self.Value
	
	surface.SetMaterial( editor )
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawTexturedRect( x, y, editorW, editorH)
	
	local h_h = h*.5
	draw.SimpleText(value, "settings.BtnOFF", x + (editorW * .5), h_h, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end
vgui.Register("FHSettingsButton", BUTTON, "DButton")


	-- ДЕВАЙДЕР ДЛЯ НАСТРОЕК
local DIVIDER = {}
function DIVIDER:Init()
	self:SetTall(54)
	self:SetText("")
	self.Value = false
	self.Animation = {}
end

function DIVIDER:SetSetting(setting)
	self.Setting = setting
	self.Label = setting.label or ""
end

function DIVIDER:Think()
	SyncPanel(self)
end

local set_div = Material("vgui/base/settings/settings_divider.png", "smooth")
function DIVIDER:Paint(w, h)
	local w, h = self:GetSize()
	
	surface.SetMaterial( set_div )
	surface.SetDrawColor( 255,255,255 )
	surface.DrawTexturedRect( 0, 0, w, 2)
	
	draw.SimpleText(self.Label or "", "settings.Divider", 16, h * .5, color_fazbearshunt, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end
vgui.Register("FHSettingsDivider", DIVIDER, "DPanel")


	-- СЛАЙДЕР
local SLIDER = {}
function SLIDER:Init()
	self:SetTall(42)
	self:SetMouseInputEnabled(true)
	self.Value = 0
	self.Dragging = false
end

function SLIDER:SetSetting(setting)
	self.Setting = setting
	self.Label = setting.label or ""
	self.Value = ReadSetting(setting)
	self.Min = setting.min or 0
	self.Max = setting.max or 1
	self.Step = setting.step or 0.01
end

function SLIDER:SetFromCursor(x)
	local w = self:GetWide()
	local startX = w * 0.4
	local trackW = w * 0.48
	local fraction = math.Clamp((x - startX) / trackW, 0, 1)
	local value = self.Min + (self.Max - self.Min) * fraction
	value = math.Round(value / self.Step) * self.Step
	value = math.Clamp(value, self.Min, self.Max)
	local decimals = self.Setting.decimals or 0
	value = tonumber(string.format("%0." .. decimals .. "f", value)) or value
	if value ~= self.Value then 
		ApplyValue(self, value)
		sound.PlayFile( "sound/ui/slider.wav", "noplay", function( station, errCode, errStr )
			if ( IsValid( station ) ) then
				station:Play()
			end
		end )
	end
end

function SLIDER:OnMousePressed(code)
	if code ~= MOUSE_LEFT then return end
	local x = self:CursorPos()
	local startX = self:GetWide() * 0.4
	local endX = startX + self:GetWide() * 0.48
	if x < startX - 5 or x > endX + 5 then return end
	self.Dragging = true
	self:MouseCapture(true)
	self:SetFromCursor(x)
	self:SetCursor("sizewe")
end

function SLIDER:OnCursorMoved(x, y)
	if self.Dragging then self:SetFromCursor(x) end
end

function SLIDER:OnMouseReleased(code)
	if code ~= MOUSE_LEFT then return end
	self.Dragging = false
	self:MouseCapture(false)
	self:SetCursor("arrow")
end

function SLIDER:Think()
	SyncPanel(self)
	
	if not self:IsHovered() then return end
	
	if not self.Dragging then
		self:SetCursor("arrow")
	end
	
	local x = self:CursorPos()
	local startX = self:GetWide() * 0.4
	local endX = startX + self:GetWide() * 0.48
	if x < startX - 5 or x > endX + 5 then return end
	
	self:SetCursor("sizewe")
end

function SLIDER:Paint(w, h)
	DrawRow(self, self.Label)
	local startX = w * 0.4
	local trackW = w * 0.48
	local trackH = 14
	local trackY = (h - trackH) * 0.5
	local range = math.max(self.Max - self.Min, 0.000001)
	local fraction = math.Clamp(((tonumber(self.Value) or self.Min) - self.Min) / range, 0, 1)
	draw.RoundedBox(7, startX, trackY, trackW, trackH, color_fazbearshunt)
	draw.RoundedBox(7, startX + 1, trackY + 1, trackW - 2, trackH - 2, color_black)
	draw.RoundedBox(6, startX + 3, trackY + 3, math.max(0, (trackW - 6) * fraction), trackH - 6, color_fazbearshunt)
	draw.RoundedBox(2, startX + trackW - 8, (trackY + trackH * .5) - 1, 2, 2, color_fazbearshunt)
	--surface.SetDrawColor(235, 235, 235, 255)
	--surface.DrawOutlinedRect(startX, trackY, trackW, trackH, 1)
	local valueText
	if self.Setting.format == "percent" then
		valueText = tostring(math.Round((tonumber(self.Value) or 0) * 100)) .. "%"
	elseif self.Setting.format then
		valueText = string.format(self.Setting.format, tonumber(self.Value) or 0)
	else
		valueText = ReadNumber(self.Value, self.Setting.decimals or 0)
	end
	draw.SimpleText(valueText, "settings.Value", w - 10, h * 0.5, C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end
vgui.Register("FHSettingsSlider", SLIDER, "DPanel")


	-- КОМБО МЕНЮ
local COMBO = {}
function COMBO:Init()
	self:SetTall(42)
	self:SetMouseInputEnabled(true)
	self.Value = ""
end

function COMBO:SetSetting(setting)
	self.Setting = setting
	self.Label = setting.label or ""
	self.Value = tostring(ReadSetting(setting) or "")
end

function COMBO:GetChoiceLabel(value)
	for _, choice in ipairs(self.Setting.choices or {}) do
		if istable(choice) and tostring(choice.value) == tostring(value) then return choice.label or tostring(value) end
		if not istable(choice) and tostring(choice) == tostring(value) then return tostring(choice) end
	end
	return tostring(value)
end

function COMBO:OpenMenu()
	if not self.Setting then return end
	if self.LastMenu then
		self.LastMenu:Remove()
		self.LastMenu = nil
		return
	end
	local menu = DermaMenu()
	menu:SetMinimumWidth(math.min(270, self:GetWide() * 0.36))
	menu.Paint = function(pnl, w, h)
		draw.RoundedBox(4, 0, 0, w, h, Color(6, 8, 8, 255))
		surface.SetDrawColor(C.border)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end
	for _, item in ipairs(self.Setting.choices or {}) do
		local value = istable(item) and item.value or item
		local label = istable(item) and (item.label or tostring(item.value)) or tostring(item)
		local option = menu:AddOption(label, function()
			if tostring(self.Value) ~= tostring(value) then ApplyValue(self, tostring(value)) end
		end)
		option:SetFont("settings.Small")
		option:SetTextColor(C.text)
		option.Paint = function(pnl, w, h)
			local active = tostring(self.Value) == tostring(value)
			if pnl:IsHovered() then
				draw.RoundedBox(2, 2, 1, w - 4, h - 2, Color(50, 54, 54))
			elseif active then
				draw.RoundedBox(2, 2, 1, w - 4, h - 2, Color(28, 31, 31))
			end
		end
	end
	menu:Open()
	
	--local x, y = self:GetPos()
	--menu:SetPos(x, y)
	
	self.LastMenu = menu
end

function COMBO:OnMousePressed(code)
	if code == MOUSE_LEFT then self:OpenMenu() end
end

function COMBO:Think()
	SyncPanel(self)
	self:SetCursor("hand")
end

function COMBO:OnRemove()
	if self.LastMenu then self.LastMenu:Remove() end
end

local dd_triangle = Material("vgui/base/settings/dd_triangle.png", "smooth")
function COMBO:Paint(w, h)
	DrawRow(self, self.Label)
	local x = w * 0.4
	local boxW = math.min(270, w * 0.36)
	local boxH = 23
	local y = (h - boxH) * 0.5
	draw.RoundedBox(5, x, y, boxW, boxH, Color(0, 0, 0, 255))
	surface.SetDrawColor(125,125,125)
	surface.DrawOutlinedRect(x, y, boxW, boxH, 1)

	draw.SimpleText(self:GetChoiceLabel(self.Value), "settings.Small", x + 11, h * 0.5, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	surface.SetDrawColor(195, 199, 199, 255)
	
	surface.SetMaterial( dd_triangle )
	surface.SetDrawColor( 255,255,255 )
	surface.DrawTexturedRect( x + boxW - 20, y + boxH * .5 - 2.5, 10, 5)
end
vgui.Register("FHSettingsCombo", COMBO, "DPanel")

local closew = Material("vgui/base/settings/closewin.png", "smooth")
function settings.Open()
	if IsValid(settings.Frame) then settings.Frame:Remove() end
	settings.Frame = vgui.Create("FHSettingsWindow")
end

function settings.Close()
	if IsValid(settings.Frame) then settings.Frame:Remove() end
end

include("settings/pills_fov_editor.lua")

local function loadSettings()
	settings.RegisterCategory("gameplay", "#fazhunt.gameplay")
	settings.RegisterCategory("audio", "#fazhunt.audio")
	settings.RegisterCategory("interface", "#fazhunt.interface")
	settings.RegisterCategory("performance", "#fazhunt.performance")

	settings.RegisterSetting("gameplay", {type = "toggle", label = "#fazhunt.thirperson", convar = "fh_thirdperson", default = GetConVarNumber("fh_thirdperson")})
	settings.RegisterSetting("gameplay", {type = "toggle", label = "#fazhunt.opt_out", convar = "fh_opt_out_anim", default = GetConVarNumber("fh_opt_out_anim")})

	settings.RegisterSetting("audio", {type = "toggle", label = "#fazhunt.mute_spectators", convar = "proximity_hear_spectators", default = GetConVarNumber("proximity_hear_spectators"), invert = true})
	settings.RegisterSetting("audio", {type = "toggle", label = "#fazhunt.fh_voicelines", convar = "fh_voicelines", default = GetConVarNumber("fh_voicelines")})
	settings.RegisterSetting("audio", {type = "divider", label = "#fazhunt.terror_radius"})
	settings.RegisterSetting("audio", {type = "toggle", label = "#fazhunt.terror_radius_enable", convar = "fh_terror_enabled", default = GetConVarNumber("fh_terror_enabled")})
	settings.RegisterSetting("audio", {type = "slider", label = "#fazhunt.terror_radius_volume", convar = "fh_terror_volume", default = GetConVarNumber("fh_terror_volume"), 
		min = 0, 
		max = 1, 
		step = 0.05, 
		decimals = 2, 
		format = "percent"})
	settings.RegisterSetting("audio", {type = "toggle", label = "#fazhunt.terror_radius_spectators", convar = "fh_terror_spectators", default = GetConVarNumber("fh_terror_spectators")})

	settings.RegisterSetting("interface", {type = "divider", label = "#fazhunt.context.animatronics_only"})
	settings.RegisterSetting("interface", {type = "slider", label = "#fazhunt.ui_scale", convar = "fh_ui_scale", default = GetConVarNumber("fh_ui_scale"), 
		min = 0.1, 
		max = 1, 
		step = 0.1, 
		decimals = 2, 
		format = "percent"})
	settings.RegisterSetting("interface", {type = "toggle", label = "#fazhunt.halo_teammates", convar = "fh_halo_teammates", default = GetConVarNumber("fh_halo_teammates")})
	--settings.RegisterSetting("interface", {type = "button", label = "#fazhunt.anims_vm_fov", default = "#fazhunt.open_editor", func = settings.OpenPillsFovEditor})
	settings.RegisterSetting("interface", {type = "divider", label = "#other"})
	settings.RegisterSetting("interface", {type = "toggle", label = "#fazhunt.min_viewmodels", convar = "cl_use_min_viewmodels", default = GetConVarNumber("cl_use_min_viewmodels")})
	settings.RegisterSetting("interface", {type = "toggle", label = "#fazhunt.dark_blindness", convar = "fh_dark_blindness", default = GetConVarNumber("fh_dark_blindness")})

	settings.RegisterSetting("performance", {type = "combo", label = "#fazhunt.highlight_quality", convar = "fh_highlight_quality", default = GetConVarNumber("fh_highlight_quality"), choices = {
		{label = "#fazhunt.settings.default", value = "0"},
		{label = "#fazhunt.settings.auto", value = "1"},
		{label = "#fazhunt.settings.lowest", value = "2"}
	}})
	settings.RegisterSetting("performance", {type = "toggle", label = "#fazhunt.r_WaterDrawReflection", convar = "r_WaterDrawReflection", default = GetConVarNumber("r_WaterDrawReflection")})
	settings.RegisterSetting("performance", {type = "toggle", label = "#fazhunt.r_WaterDrawRefraction", convar = "r_WaterDrawRefraction", default = GetConVarNumber("r_WaterDrawRefraction")})
	settings.RegisterSetting("performance", {type = "toggle", label = "#fazhunt.r_3dsky", convar = "r_3dsky", default = GetConVarNumber("r_3dsky")})
end

hook.Add("PostGamemodeLoaded", "cl_settings", function()
	loadSettings()
	hook.Run("FH_PostRegisterSettings")
end)
hook.Add("OnReloaded", "cl_settings", function()
	loadSettings()
	hook.Run("FH_PostRegisterSettings")
end)

concommand.Add("fh_settings_open", function()
    settings.Open()
end)

concommand.Add("fh_settings_close", function()
    settings.Close()
end)
