
-- запоминание за кого играл игронк

local playedkillers = playedkillers or {}

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

local animatronics = animatronics or {}
local selectable = selectable or false
local selector = selector or nil
local grid = grid or nil

local showAnimTooltip = false
local animTooltipText = ""

function draw_killer_selector()
    if not istable(animatronics) then return end

    if IsValid(fh_admin_panel) then 
        fh_admin_panel:Remove()
        gui.EnableScreenClicker(false)
    end

    selector = vgui.Create("DFrame")
    selector:SetTitle("")
    selector:SetDraggable(false)
    selector:ShowCloseButton(false)
    selector:SetSize(600, 600)
    selector:Center()
    selector:MakePopup()

    selector.Paint = function(self, w, h)
        draw.RoundedBox(24, 0, 0, w, h, Color(0, 0, 0, 240))
    end

    local titleLabel = vgui.Create("DLabel", selector)
    titleLabel:SetText(language.GetPhrase("fazhunt.selector.select_animatronic"))
    titleLabel:SetFont("DermaLarge")
    titleLabel:SetTextColor(Color(255, 255, 255))
    titleLabel:SizeToContents()
    titleLabel:CenterHorizontal()
    titleLabel:SetPos(titleLabel:GetX(), 20)

    local duration = 30
    local endTime = CurTime() + duration

    local timerLabel = vgui.Create("DLabel", selector)
    timerLabel:SetFont("DermaLarge")
    timerLabel:SetTextColor(Color(255, 200, 0))
    timerLabel:SetPos(0, 60)
    timerLabel:SizeToContents()
    timerLabel:CenterHorizontal()

    selector.Think = function()
        if not IsValid(timerLabel) then return end

        local timeLeft = math.max(0, math.ceil(endTime - CurTime()))
        timerLabel:SetText(string.format("– %d –", timeLeft))
        timerLabel:SizeToContents()
        timerLabel:CenterHorizontal()

        if timeLeft <= 0 and IsValid(selector) then
            selector:Close()
			showAnimTooltip = false
            selectable = false

            net.Start("fh_selector_nomore")
            net.SendToServer()
        end
    end

    local scroll = vgui.Create("DScrollPanel", selector)
    scroll:SetPos(50, 100)
    scroll:SetSize(500, 450)

    grid = vgui.Create("DGrid", scroll)
    grid:SetCols(3)
    grid:SetColWide(150)
    grid:SetRowHeight(150)
    grid:Dock(TOP)
    grid:DockMargin(0, 0, 0, 0)

    local rowCount = math.ceil(#animatronics / 3)
    grid:SetTall(rowCount * 150)
	
	local killerData = killers.getAll()

    for i, animName in ipairs(animatronics) do
		local animImage = nil
		local storedAvatar = killers.GetAvatar(animName)
		if storedAvatar then
			animImage = storedAvatar
		end

        local box = vgui.Create("DImageButton")
        box:SetSize(140, 140)
        box.name = animName
		
		box.OnCursorEntered = function(self)
			local key = "fazhunt.animatronics.description." .. killerData[self.name].name
			local localized = language.GetPhrase(key)

			if localized == key then
				showAnimTooltip = false
			else
				showAnimTooltip = true
				animTooltipText = localized
			end
		end

		box.OnCursorExited = function(self)
			showAnimTooltip = false
		end

        box.DoClick = function()
            if not selectable then return end
            net.Start("fh_selected_killer")
            net.WriteString(animName)
            net.SendToServer()
        end

        if animImage then
            box:SetMaterial(animImage)
        else
            box.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(0, 0, 0))
                draw.SimpleText(language.SafeGetPhrase(killerData[animName].fullname), "timerFontSmall", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
		
		if NeverPlayedAs(box.name) then
			local new_end_x = 36
			local new_end_y = 118
		
			box.PaintOver = function(self, w, h)
				surface.SetDrawColor(0,0,0,225)
				surface.DrawRect( 0, new_end_y, new_end_x, new_end_x )

				for i = 0, 2 do
				
					surface.SetDrawColor(255, 200, 0, 255)
					surface.DrawOutlinedRect(i, i, w - i*2, h - i*2)
					surface.DrawLine( 0, new_end_y + i, new_end_x, new_end_y + i )
					surface.DrawLine( new_end_x + i, 140, new_end_x + i, new_end_y )
				end
				
				surface.SetFont( "Default" )
				surface.SetTextColor( 255, 200, 0 )
				surface.SetTextPos( 8, new_end_y + 4 ) 
				surface.DrawText( "NEW",  false)
			end
		end

		grid:AddItem(box)
    end
end

hook.Add("PostRenderVGUI", "DrawAnimTooltip", function()
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

net.Receive("fh_let_killers_choose", function()
    animatronics = net.ReadTable()
    draw_killer_selector()
	
	for _, box in pairs(grid:GetItems()) do
		box:SetAlpha(100)
	end

    timer.Simple(1.5, function()
	
		for _, box in pairs(grid:GetItems()) do
			if box:IsEnabled() then
				box:SetAlpha(255)
			end
		end
		
        selectable = true
    end)
end)

net.Receive("fh_update_killer_selector", function()
    local ply = net.ReadPlayer()
    local killer = net.ReadString()

    if ply == LocalPlayer() then
        if IsValid(selector) then 
            selector:Close()
			showAnimTooltip = false
            selectable = false
			
			rememberPlayedAnimatronic(killer)
        end
        return
    end

    if IsValid(selector) and IsValid(grid) then
        for _, v in pairs(grid:GetItems()) do
            if v.name == killer then
                v:SetEnabled(false)
                v:SetAlpha(100)
            end
        end
    end
end)