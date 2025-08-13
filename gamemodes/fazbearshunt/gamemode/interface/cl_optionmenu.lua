
local menuData = { title = "", options = {}, text = {}, visible = false }

function sel_menu_add_text(text)
    table.insert(menuData.text, text)
    menuData.visible = true
end

function sel_menu_add_title(text)
	menuData.title = text
end

function sel_menu_add_option(text, func)
    local index = #menuData.options + 1
    menuData.options[index] = { text = text, func = func }
    menuData.visible = true
end

function sel_menu_close()
    menuData.text = {}
    menuData.options = {}
    menuData.visible = false
end

local function wrapText(text, font, maxWidth)
    surface.SetFont(font)
    local words = string.Explode(" ", text)
    local lines = {}
    local currentLine = ""

    for _, word in ipairs(words) do
        local testLine = currentLine == "" and word or (currentLine .. " " .. word)
        local textWidth = surface.GetTextSize(testLine)
        
        if textWidth > maxWidth then
            table.insert(lines, currentLine)
            currentLine = word
        else
            currentLine = testLine
        end
    end
    
    if currentLine ~= "" then
        table.insert(lines, currentLine)
    end

    return lines
end

hook.Add("HUDPaint", "DrawSelMenu", function()
    if not menuData.visible then return end
	
	local x = ScrW() * 0.015
	local y = ScrH() * 0.3
    
	local x, y = x, y
    local boxWidth, boxHeight = 300, 500
    draw.RoundedBox(10, x, y, boxWidth, boxHeight, Color(0, 0, 0, 200))
    
    y = y + 15
    local wrappedTitle = wrapText(menuData.title, "timerFontUpper", boxWidth - 20)
    for _, line in ipairs(wrappedTitle) do
        draw.SimpleText(line, "timerFontUpper", x + 10, y, color_white, TEXT_ALIGN_LEFT)
        y = y + 25
    end
	
	y = y + 25
    for _, text in ipairs(menuData.text) do
        local wrappedText = wrapText(text, "timerFontUpper", boxWidth - 20)
        for _, line in ipairs(wrappedText) do
            draw.SimpleText(line, "timerFontUpper", x + 10, y, color_white, TEXT_ALIGN_LEFT)
            y = y + 25
        end
    end

    for i, option in ipairs(menuData.options) do
        local wrappedOption = wrapText(i .. ". " .. option.text, "timerFontUpper", boxWidth - 20)
        for _, line in ipairs(wrappedOption) do
            draw.SimpleText(line, "timerFontUpper", x + 10, y, color_white, TEXT_ALIGN_LEFT)
            y = y + 25
        end
    end
end)

hook.Add("PlayerButtonDown", "SelMenu_Input", function(ply, button)
    local key = button - 1
    if key >= 1 and menuData.options[key] then
        menuData.options[key].func()
        sel_menu_close()
    end
end)

net.Receive("fh_sel_menu_close", function()
	sel_menu_close()
end)

net.Receive("st_request_get", function()
	local ply = net.ReadPlayer()
	
	if #menuData.options == 9 then return end
	
	sel_menu_add_title(language.GetPhrase("fazhunt.optionmenu.plushtrap") .. ":")
	sel_menu_add_option(ply:Nick(), 
	function()
		return pt_request_complete(ply)
	end)
end)

function pt_request_complete(ply)
	net.Start("pt_request_complete")
	net.WritePlayer(ply)
	net.SendToServer()
end

hook.Add("PostCleanupMap", "fh_cleanup_optionmenu", function(ply)
	sel_menu_close()
end)

--[[
concommand.Add("fh_menu_test", function(ply, cmd, args)
	if ply:IsAdmin() then
		sel_menu_add_title("Замени Плюштрапа игроком:")
		sel_menu_add_option("заебал", function() end)
	end
end)
]]--