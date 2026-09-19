
-- запоминание за кого играл игронк
local playedkillers = {}

if file.Exists("fh_playedkillers.txt", "DATA") then
	local data = file.Read("fh_playedkillers.txt", "DATA") or ""
	
	if data != "" then 
		local lines = string.Split(data, "\n")
		
		for k, v in pairs(lines) do
			table.insert(playedkillers, v)
		end
	end
end

local function rememberPlayedAnimatronic(anim)
	if !table.HasValue(playedkillers, anim) then
		table.insert(playedkillers, anim)

		file.Write("fh_playedkillers.txt", table.concat(playedkillers, "\n"))
	end
end

function NeverPlayedAs(anim)
	if table.IsEmpty(playedkillers) then return true end
	
	return !table.HasValue(playedkillers,anim)
end

-- #### ВЫБИРАЛКА АНИМАТРОНОВ!!!

local select_title = Material("vgui/selector/select_title.png")

local selector_window = Material("vgui/selector/selector_window.png")

local anim_box = Material("vgui/selector/anim_box.png")
local anim_box_hover = Material("vgui/selector/anim_box_hover.png")
local new_anim_box = Material("vgui/selector/new_anim_box.png")
local new_anim_box_hover = Material("vgui/selector/new_anim_box_hover.png")
local anim_box_stolen = Material("vgui/selector/anim_box_stolen.png")

local side_window = Material("vgui/selector/side_window.png")
local select_button = Material("vgui/selector/select_button.png")

local availableKillers 		= {}
local selector_panel	= false
local model_viewer 		= false
local description_panel = false
local desc_scroll 		= false
local selectorTitle 	= false
local grid 				= false

local curSelected = ""
local animTooltipText = ""

surface.CreateFont("animNameFont", { font = "Share Tech Mono", size = 32, extended = true, antialias = true, shadow = true })
surface.CreateFont("animDescriptionFont", { font = "Share Tech Mono", size = 22, extended = true, antialias = true, shadow = true })

selector = selector or {}

local descriptionPanels = {}

function selector.AddDescriptionPanel(name, panel_data)
	if !descriptionPanels[name] then descriptionPanels[name] = {} end
	
	table.insert(descriptionPanels[name], panel_data)
end

function selector.ClearDescriptionPanels(name)
	descriptionPanels[name] = nil
end

local createdPanels = {}
local function createDescriptionPanels(name, descScroll)
	if descriptionPanels[name] then
		for _, panelInfo in ipairs(descriptionPanels[name]) do
			if not istable(panelInfo) then continue end

			local newPanel = vgui.Create(panelInfo.class, descScroll)
			local panelText = nil
			if panelInfo.setup and isfunction(panelInfo.setup) then
				panelInfo.setup(newPanel, desc_scroll)
			end
			newPanel:Dock( TOP )
			newPanel:DockMargin( 5, 5, 5, 5 )
			descScroll:AddItem(newPanel)
			
			table.insert(createdPanels, newPanel)
		end
	end
end

hook.Run("FH_SelectorInit")

function draw_killer_selector()
    if not istable(availableKillers) then return end

    if IsValid(fh_admin_panel) then 
        fh_admin_panel:Remove()
    end

    selector_panel = vgui.Create("DFrame")
    selector_panel:SetTitle("")
    selector_panel:SetDraggable(false)
    selector_panel:ShowCloseButton(false)
    selector_panel:SetSize(600, 527)
    selector_panel:Center()
	selector_panel.Paint=function(self, w, h)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(selector_window)
		surface.DrawTexturedRect(0, 0, w, h)
	end
	selector_panel.Think=function(delta)
        gui.EnableScreenClicker(true)
	end
	gui.EnableScreenClicker(true)
	
    selector_panel.OnClose = function()
        gui.EnableScreenClicker(false)
    end

	-- скролл хуйня
    local scroll = vgui.Create("DScrollPanel", selector_panel)
    scroll:SetPos(25, 9)
    scroll:SetSize(549, 513)
	
	local sbar = scroll:GetVBar()
	
	local sX, wM = 2, 0.35
	
	local color_swag1, color_swag2 = Color(83, 0, 0), Color(152, 2, 2)
	function sbar:Paint(w, h)
		draw.RoundedBox(24, sX, 0, w*wM, h, Color(0, 0, 0, 100))
	end
	function sbar.btnGrip:Paint(w, h)
		draw.RoundedBox(4, sX, 1, w*wM, h - 2, color_swag2)
	end
	function sbar.btnUp:Paint(w, h)
		draw.RoundedBox(4, sX, 0, w*wM, h, color_swag1)
	end
	function sbar.btnDown:Paint(w, h)
		draw.RoundedBox(4, sX, 0, w*wM, h, color_swag1)
	end

    grid = vgui.Create("DGrid", scroll)
    grid:SetCols(3)
    grid:SetColWide(191)
    grid:SetRowHeight(171)
    grid:Dock(TOP)
    grid:DockMargin(0, 0, 0, 0)

    local rowCount = math.ceil(#availableKillers / 3)
    grid:SetTall(rowCount * 150)
	
	local killerData = killers.getAll()
	local entiretyOfPills = pills.getAllPills()

    for i, animName in ipairs(availableKillers) do
		local animImage = nil
		local storedAvatar = killers.GetAvatar(animName)
		if storedAvatar then
			animImage = storedAvatar
		end

        local box = vgui.Create("DButton")
		box:SetText( "" )
        box:SetSize(167, 167)
        box.name = animName

		box.DoClick = function()
			
			local key = "fazhunt.availableKillers.description." .. killerData[box.name].name
			local fullname = killerData[box.name].fullname
			local localized = language.GetPhrase(key)
			
			animTooltipText = ""
			
			if localized ~= key then
				animTooltipText = localized
			end
			
			if box.Stolen then
				curSelected = ""
			else
				curSelected = animName
			end
			
			for _, panel in ipairs(createdPanels) do -- TODO: мейби сделать кеширование?
				panel:Remove()
			end
			
			if not descriptionPanels[animName] then
				descriptionLabel:SetText(animTooltipText)
				animNameLabel:SetText(language.SafeGetPhrase(fullname):upper())
				
			else
				descriptionLabel:SetText("")
				animNameLabel:SetText("")
				
				createDescriptionPanels(animName, desc_scroll)
			end
			
			for k, v in pairs(entiretyOfPills) do
				if v.name == animName and v.model then
					local oldent = modelpanel:GetEntity()
				
					modelpanel:SetModel(v.model)

					local ent = modelpanel:GetEntity()
					if IsValid(ent) then
					
						if v.modelScale then
							ent:SetModelScale(v.modelScale)
						end
						local idleanim = v.anims.default.idle or "idle"
						ent:SetSequence(ent:LookupSequence(idleanim))
						modelpanel:RunAnimation()
			
						local model = v.model
						local skin = v.skin
						local attachments = v.attachments
						local bodyGroups = v.bodyGroups

						if v.options then
							local options = v.options()
							local pickedOption

							if v.option and options[v.option] then
								pickedOption = options[v.option]
							else
								pickedOption = table.Random(options)
							end

							if pickedOption.model then
								model = pickedOption.model
							end

							if pickedOption.skin then
								skin = pickedOption.skin
							end

							if pickedOption.attachments then
								attachments = pickedOption.attachments
							end

							if pickedOption.bodyGroups then
								bodyGroups = pickedOption.bodyGroups
							end
						end

						if v.boneMorphs then
							for bone, dab in pairs(v.boneMorphs) do
								local b = ent:LookupBone(bone)

								if b then
									if dab.pos then
										ent:ManipulateBonePosition(b, dab.pos)
									end

									if dab.rot then
										ent:ManipulateBoneAngles(b, dab.rot)
									end

									if dab.scale then
										ent:ManipulateBoneScale(b, dab.scale)
									end
								end
							end
						end
						
						if skin then
							ent:SetSkin(skin)
						end

						if bodyGroups then
							for k, v in pairs(bodyGroups) do
								if isnumber(k) then
									ent:SetBodygroup(k, v)
								elseif isstring(k) then
									local id = ent:FindBodygroupByName(k)
									if id >= 0 then
										ent:SetBodygroup(id, v)
									end
								elseif isnumber(v) then
									ent:SetBodygroup(v, 1)
								end
							end
						end
						
						local mn, mx = ent:GetModelBounds()
						local center = (mn + mx) * 0.5
						
						local camPos = Vector(-125, 125, 70)
						local lookAt = Vector(0, 0, 60)

						modelpanel:SetFOV(35)
						modelpanel:SetCamPos(camPos)
						modelpanel:SetLookAt(lookAt)

						local dir = (camPos - lookAt):Angle()
						ent:SetAngles(Angle(0, dir.y, 0))
					end

					break
				end
			end
		end

        if animImage then
            box.Paint = function(self, w, h)
				draw.RoundedBox(8, 0, 0, w, h, Color(0, 0, 0, 200))
				surface.SetMaterial(animImage)
				surface.SetDrawColor(255, 255, 255, self.Stolen and 100 or 255)
				surface.DrawTexturedRect(4, 4, w - 8, h - 8)
			end
        else
            box.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(0, 0, 0))
                draw.SimpleText(language.SafeGetPhrase(killerData[animName].fullname), "timerFontSmall", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
		
		box.PaintOver = function(self,w,h)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(self.Stolen and anim_box_stolen or NeverPlayedAs(box.name) and (self:IsHovered() and new_anim_box_hover or new_anim_box) or self:IsHovered() and anim_box_hover or anim_box)
			surface.DrawTexturedRect(0, 0, w, h)
		end

		grid:AddItem(box)
    end
	scroll:SetWide(570)
	scroll:Rebuild()
	
	model_viewer = vgui.Create("DFrame")
	model_viewer:SetTitle("")
	model_viewer:SetDraggable(false)
	model_viewer:ShowCloseButton(false)
	model_viewer:SetSize(355, 500)
	model_viewer:Center()
	
	model_viewer:SetX(selector_panel:GetX() + selector_panel:GetWide() + 5)
	
	model_viewer.Paint=function(self, w, h)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(side_window)
		surface.DrawTexturedRect(0, 0, w, h)
	end
	
		local myself = LocalPlayer()
		
	modelpanel = vgui.Create( "DModelPanel", model_viewer )
	modelpanel:SetSize(300,400)
	if IsValid(myself) then
		modelpanel:SetModel( LocalPlayer():GetModel() )
	else
		modelpanel:SetModel( "models/props_farm/scenes/bananana_peel.mdl" )
	end
    modelpanel:Dock(TOP)
	
	modelpanel:SetDirectionalLight(BOX_TOP, Color(255, 255, 255))
	modelpanel:SetDirectionalLight(BOX_FRONT, Color(230, 230, 230))
	modelpanel:SetDirectionalLight(BOX_LEFT, Color(180, 180, 180))
	modelpanel:SetDirectionalLight(BOX_RIGHT, Color(100, 100, 100))
	modelpanel:SetDirectionalLight(BOX_BOTTOM, Color(60, 60, 60))
	modelpanel:SetAmbientLight(Color(40, 40, 40))

	function modelpanel:DragMousePress()
		self.PressX, self.PressY = gui.MousePos()
		self.Pressed = true
	end
	function modelpanel:DragMouseRelease()
		self.Pressed = false
	end
	function modelpanel:LayoutEntity(ent)
		if self.Pressed then
			local mx = gui.MouseX()
			ent:SetAngles(Angle(0, ent:GetAngles().y - (self.PressX - mx) * 0.5, 0))
			self.PressX = mx
		else
			ent:SetAngles(Angle(0, ent:GetAngles().y, 0))
		end
		ent:FrameAdvance(FrameTime())
	end
	
	local buttonSelect = vgui.Create("DButton", model_viewer)
	buttonSelect:SetText( "" )
	buttonSelect:SetFont( "timerFontUpper" )
	buttonSelect:SetSize(243, 42)
	buttonSelect:Center()
	buttonSelect:SetY(model_viewer:GetTall() - 60)
	
	local depressed = Color(255,255,255)
	local hovered = Color(255,180,80)
	local selected = Color(255,148,20)
	
	buttonSelect.Paint = function(self, w, h)
		surface.SetDrawColor(255, 255, 255, 250)
		surface.SetMaterial(select_button)
		surface.DrawTexturedRect(0, 0, w, h)

		local textColor = depressed
		if self:IsDown() then
			textColor = selected
		elseif self:IsHovered() then
			textColor = hovered
		end
		local selecttxt = language.SafeGetPhrase("select")
		draw.SimpleText(selecttxt:upper(), "timerFontUpper", w / 2, h / 2, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	buttonSelect.DoClick = function()
		if string.len(curSelected) < 1 then return end
		
		net.Start("fh_selected_killer")
		net.WriteString(curSelected)
		net.SendToServer()
	end
	
	description_panel = vgui.Create("DFrame")
	description_panel:SetTitle("")
	description_panel:SetDraggable(false)
	description_panel:ShowCloseButton(false)
	description_panel:SetSize(355, 500)
	description_panel:Center()
	description_panel:SetX(selector_panel:GetX() - description_panel:GetWide() - 5)
	
	description_panel.Paint = function(self, w, h)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(side_window)
		surface.DrawTexturedRect(0, 0, w, h)
	end

	desc_scroll = vgui.Create("DScrollPanel", description_panel)
	desc_scroll:SetPos(15, 15)
	desc_scroll:SetSize(description_panel:GetWide() - 20, description_panel:GetTall() - 40)

	local sbar = desc_scroll:GetVBar()
	local sX, wM = 2, 0.35
	local color_swag1, color_swag2 = Color(83, 0, 0), Color(152, 2, 2)

	function sbar:Paint(w, h)
		draw.RoundedBox(24, sX, 0, w * wM, h, Color(0, 0, 0, 100))
	end
	function sbar.btnGrip:Paint(w, h)
		draw.RoundedBox(4, sX, 1, w * wM, h - 2, color_swag2)
	end
	function sbar.btnUp:Paint(w, h)
		draw.RoundedBox(4, sX, 0, w * wM, h, color_swag1)
	end
	function sbar.btnDown:Paint(w, h)
		draw.RoundedBox(4, sX, 0, w * wM, h, color_swag1)
	end

	descriptionLabel = vgui.Create("DLabel", desc_scroll)
	descriptionLabel:SetPos(0, 30)
	descriptionLabel:SetSize(desc_scroll:GetWide() - 10, 10)
	descriptionLabel:SetFont("animDescriptionFont")
	descriptionLabel:SetTextColor(Color(255, 255, 255))
	descriptionLabel:SetWrap(true)
	descriptionLabel:SetAutoStretchVertical(true)
	descriptionLabel:SetContentAlignment(7)
	descriptionLabel:SetText("")

	animNameLabel = vgui.Create("DLabel", desc_scroll)
	animNameLabel:SetPos(0, 0)
	animNameLabel:SetSize(desc_scroll:GetWide() - 10, 30)
	animNameLabel:SetFont("animNameFont")
	animNameLabel:SetTextColor(Color(255, 0, 0))
	animNameLabel:SetContentAlignment(8)
	animNameLabel:SetText("")
	
	-- Плашка сверху "Выберите аниматроника"
	selectorTitle = vgui.Create("DFrame")
	selectorTitle:SetTitle("")
	selectorTitle:SetDraggable(false)
	selectorTitle:ShowCloseButton(false)
	selectorTitle:SetSize(357, 42)
	selectorTitle:Center()
	selectorTitle:SetY(selector_panel:GetY() - selectorTitle:GetTall() - 5)
	
	selectorTitle.Paint=function(self, w, h)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(select_title)
		surface.DrawTexturedRect(0, 0, w, h)
	end

	local selectPls = vgui.Create("DLabel", selectorTitle)
	selectPls:SetFont("animDescriptionFont")
	selectPls:SetTextColor(Color(255, 255, 255))
	selectPls:SetSize(selectorTitle:GetWide() - 8, selectorTitle:GetTall())
	selectPls:SetContentAlignment(5)
	selectPls:SetText(language.GetPhrase("fazhunt.selector.select_animatronic"))
end

local function closeSelector()
	if IsValid(selector_panel) then 
		selector_panel:Close()
		model_viewer:Close()
		description_panel:Close()
		selectorTitle:Close()
	end
end

net.Receive("fh_let_killers_choose", function()
    availableKillers = net.ReadTable()
    draw_killer_selector()
end)

net.Receive("fh_update_killer_selector", function()
    local ply = net.ReadPlayer()
    local killer = net.ReadString()

    if ply == LocalPlayer() then
        closeSelector()
			
		rememberPlayedAnimatronic(killer)
        return
    end

    if IsValid(selector_panel) and IsValid(grid) then
        for _, v in pairs(grid:GetItems()) do
            if v.name == killer then
				v.Stolen = true
				
				if curSelected == killer then
					curSelected = ""
				end
            end
        end
    end
end)