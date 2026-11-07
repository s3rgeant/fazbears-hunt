local surface = surface
local draw = draw
local Color = Color

local USE_GRADIENT	= true
local FRAME_BORDER	= 2	
local TITLE_HEIGHT	= 24

local COL = {
	red			= Color( 238, 49, 49 ),
	red_hover	= Color( 255, 90, 90 ),
	red_off		= Color( 120, 30, 30 ),			-- обводка неактивного окна
	red_dim		= Color( 238, 49, 49, 110 ),	-- тонкие рамки внутри окна
	red_fill	= Color( 238, 49, 49, 70 ),		-- выделение
	red_faint	= Color( 238, 49, 49, 35 ),		-- hover
	gradient	= Color( 238, 49, 49, 5 ),		-- цвет градиента на фоне окна

	black		= Color( 0, 0, 0, 255 ),
	bg			= Color( 0, 0, 0, 245 ),
	panel		= Color( 10, 10, 10, 255 ),
	field		= Color( 5, 5, 5, 255 ),
	header		= Color( 22, 8, 8, 255 ),
	row_alt		= Color( 255, 122, 122, 4 ),

	text		= Color( 230, 230, 230 ),
	text_bright	= Color( 255, 255, 255 ),
	text_dim	= Color( 140, 140, 140 ),
	disabled	= Color( 80, 80, 80 ),
}

local function CreateFonts()

	surface.CreateFont( "FH.Derma", {
		font = "Share Tech Mono", size = 16, weight = 500, extended = true
	} )

	surface.CreateFont( "FH.Derma.Title", {
		font = "Share Tech Mono", size = 18, weight = 500, extended = true
	} )

end

CreateFonts()

local matGradient = Material( "gui/gradient_down" )

local function Box( x, y, w, h, fill, line, thick )

	if ( fill ) then
		surface.SetDrawColor( fill )
		surface.DrawRect( x, y, w, h )
	end

	if ( line ) then
		surface.SetDrawColor( line )
		surface.DrawOutlinedRect( x, y, w, h, thick || 1 )
	end

end

local function Arrow( cx, cy, dir, col, s )

	s = s || 4
	local pts

	if ( dir == "up" ) then
		pts = { { x = cx, y = cy - s + 1 }, { x = cx + s, y = cy + s - 2 }, { x = cx - s, y = cy + s - 2 } }
	elseif ( dir == "down" ) then
		pts = { { x = cx - s, y = cy - s + 2 }, { x = cx + s, y = cy - s + 2 }, { x = cx, y = cy + s - 1 } }
	elseif ( dir == "left" ) then
		pts = { { x = cx - s + 1, y = cy }, { x = cx + s - 2, y = cy - s }, { x = cx + s - 2, y = cy + s } }
	else
		pts = { { x = cx + s - 1, y = cy }, { x = cx - s + 2, y = cy + s }, { x = cx - s + 2, y = cy - s } }
	end

	draw.NoTexture()
	surface.SetDrawColor( col )
	surface.DrawPoly( pts )

end

local function ArrowColor( panel )

	if ( !panel:IsEnabled() ) then return COL.disabled end
	if ( panel.Depressed || ( panel.IsSelected && panel:IsSelected() ) ) then return COL.text_bright end
	if ( panel.Hovered ) then return COL.red_hover end

	return COL.red

end

local function ScrollButton( panel, w, h, dir )

	if ( !panel.m_bBackground ) then return end

	Box( 0, 0, w, h, COL.field )

	if ( panel.Depressed || ( panel.IsSelected && panel:IsSelected() ) ) then
		Box( 0, 0, w, h, COL.red_fill )
	end

	Arrow( math.floor( w / 2 ), math.floor( h / 2 ), dir, ArrowColor( panel ), 3 )

end

local SKIN = {}

SKIN.PrintName		= "FazbearsHunt"
SKIN.Author			= "sergeant"
SKIN.DermaVersion	= 1

SKIN.bg_color					= Color( 10, 10, 10, 255 )
SKIN.bg_color_sleep				= Color( 5, 5, 5, 255 )
SKIN.bg_color_dark				= Color( 0, 0, 0, 255 )
SKIN.bg_color_bright			= Color( 30, 30, 30, 255 )
SKIN.frame_border				= COL.red

SKIN.fontFrame					= "FH.Derma.Title"
SKIN.fontTab					= "FH.Derma"
SKIN.fontCategoryHeader			= "FH.Derma.Title"

SKIN.control_color				= Color( 255, 20, 20, 255 )
SKIN.control_color_highlight	= Color( 40, 15, 15, 255 )
SKIN.control_color_active		= COL.red
SKIN.control_color_bright		= COL.red_hover
SKIN.control_color_dark			= Color( 5, 5, 5, 255 )

SKIN.bg_alt1					= Color( 10, 10, 10, 255 )
SKIN.bg_alt2					= Color( 16, 16, 16, 255 )

SKIN.listview_hover				= COL.red_faint
SKIN.listview_selected			= COL.red_fill

SKIN.text_bright				= COL.text_bright
SKIN.text_normal				= COL.text
SKIN.text_dark					= COL.text_dim
SKIN.text_highlight				= COL.red

SKIN.texGradientUp				= Material( "gui/gradient_up" )
SKIN.texGradientDown			= Material( "gui/gradient_down" )

SKIN.combobox_selected			= SKIN.listview_selected

SKIN.panel_transback			= Color( 0, 0, 0, 120 )
SKIN.tooltip					= COL.black

SKIN.colPropertySheet			= COL.panel
SKIN.colTab						= SKIN.colPropertySheet
SKIN.colTabInactive				= COL.field
SKIN.colTabShadow				= Color( 0, 0, 0, 170 )
SKIN.colTabText					= COL.text_bright
SKIN.colTabTextInactive			= COL.text_dim

SKIN.colCollapsibleCategory		= Color( 255, 255, 255, 10 )

SKIN.colCategoryText			= COL.text_bright
SKIN.colCategoryTextInactive	= COL.text_dim

SKIN.colNumberWangBG			= COL.field
SKIN.colTextEntryBG				= COL.field
SKIN.colTextEntryBorder			= COL.red
SKIN.colTextEntryText			= COL.text_bright
SKIN.colTextEntryTextHighlight	= Color( 238, 49, 49, 140 )
SKIN.colTextEntryTextCursor		= COL.red
SKIN.colTextEntryTextPlaceholder= Color( 110, 110, 110, 255 )

SKIN.colNumSliderNotch			= Color( 238, 49, 49, 140 )

SKIN.colMenuBG					= COL.bg
SKIN.colMenuBorder				= COL.red

SKIN.colButtonText				= COL.text
SKIN.colButtonTextDisabled		= Color( 255, 255, 255, 40 )
SKIN.colButtonBorder			= COL.red
SKIN.colButtonBorderHighlight	= Color( 238, 49, 49, 60 )
SKIN.colButtonBorderShadow		= Color( 0, 0, 0, 100 )

-- Цвета текста. Нельзя заменять вложенные таблицы частично: базовый скин
-- подставится только на верхнем уровне, поэтому тут есть ВСЕ ключи.
SKIN.Colours = {}

SKIN.Colours.Window = {
	TitleActive		= COL.red,
	TitleInactive	= COL.red,
}

SKIN.Colours.Button = {
	Normal		= COL.text,
	Hover		= COL.text_bright,
	Down		= COL.black,			-- на залитой красной кнопке
	Disabled	= COL.disabled,
}

SKIN.Colours.Tab = {
	Active = {
		Normal		= COL.text_bright,
		Hover		= COL.text_bright,
		Down		= COL.text_bright,
		Disabled	= COL.disabled,
	},
	Inactive = {
		Normal		= COL.text_dim,
		Hover		= COL.red_hover,
		Down		= COL.red,
		Disabled	= COL.disabled,
	},
}

SKIN.Colours.Label = {
	Default		= COL.text,
	Bright		= COL.text_bright,
	Dark		= Color( 200, 200, 200 ),	-- SetDark(true) используется стандартными панелями, на тёмном фоне он должен быть светлым
	Highlight	= COL.text_bright,
}

SKIN.Colours.Tree = {
	Lines		= Color( 238, 49, 49, 90 ),
	Normal		= COL.text,
	Hover		= COL.text_bright,
	Selected	= COL.text_bright,
}

SKIN.Colours.Properties = {
	Line_Normal		= Color( 10, 10, 10 ),
	Line_Selected	= Color( 60, 15, 15 ),
	Line_Hover		= Color( 30, 10, 10 ),
	Title			= COL.red,
	Column_Normal	= Color( 20, 20, 20 ),
	Column_Selected	= Color( 70, 18, 18 ),
	Column_Hover	= Color( 35, 12, 12 ),
	Column_Disabled	= Color( 12, 12, 12 ),
	Border			= Color( 238, 49, 49, 90 ),
	Label_Normal	= COL.text,
	Label_Selected	= COL.text_bright,
	Label_Hover		= COL.text_bright,
	Label_Disabled	= COL.disabled,
}

SKIN.Colours.Category = {
	Header			= COL.text_bright,
	Header_Closed	= COL.text_dim,
	Line = {
		Text			= COL.text,
		Text_Hover		= COL.text_bright,
		Text_Selected	= COL.black,
		Text_Disabled	= COL.disabled,
		Button			= Color( 14, 14, 14 ),
		Button_Hover	= Color( 60, 18, 18 ),
		Button_Selected	= COL.red,
		Button_Disabled	= Color( 8, 8, 8 ),
	},
	LineAlt = {
		Text			= COL.text,
		Text_Hover		= COL.text_bright,
		Text_Selected	= COL.black,
		Text_Disabled	= COL.disabled,
		Button			= Color( 20, 20, 20 ),
		Button_Hover	= Color( 60, 18, 18 ),
		Button_Selected	= COL.red,
		Button_Disabled	= Color( 8, 8, 8 ),
	},
}

SKIN.Colours.TooltipText = COL.text_bright

--[[---------------------------------------------------------
	Panel
-----------------------------------------------------------]]
function SKIN:PaintPanel( panel, w, h )

	if ( !panel.m_bBackground ) then return end

	Box( 0, 0, w, h, panel.m_bgColor || COL.panel --[[, COL.red_dim ]] )

end

function SKIN:PaintShadow( panel, w, h )

	local wasEnabled = DisableClipping( true )

	for i = 1, 4 do
		surface.SetDrawColor( 0, 0, 0, 70 / i )
		surface.DrawOutlinedRect( -i, -i, w + i * 2, h + i * 2, 1 )
	end

	DisableClipping( wasEnabled )

end

function SKIN:PaintFrame( panel, w, h )

	local focused = panel:HasHierarchicalFocus()
	local accent = focused && COL.red || COL.red_off

	--[[ if ( panel.m_bPaintShadow ) then

		local wasEnabled = DisableClipping( true )

		for i = 1, 6 do
			surface.SetDrawColor( 238, 49, 49, 14 - i * 2 )
			surface.DrawOutlinedRect( -i, -i, w + i * 2, h + i * 2, 1 )
		end

		DisableClipping( wasEnabled )

	end ]]

	Box( 0, 0, w, h, COL.bg )

	if ( USE_GRADIENT ) then
		surface.SetMaterial( matGradient )
		surface.SetDrawColor( COL.gradient )
		surface.DrawTexturedRect( 0, 0, w, h )
	end

	surface.SetDrawColor( COL.red_dim )
	surface.DrawRect( FRAME_BORDER, TITLE_HEIGHT, w - FRAME_BORDER * 2, 1 )

	Box( 0, 0, w, h, nil, accent, FRAME_BORDER )

end

function SKIN:PaintButton( panel, w, h )

	if ( !panel.m_bBackground ) then return end

	if ( panel.Depressed || panel:IsSelected() || panel:GetToggle() ) then
		return Box( 0, 0, w, h, COL.red, COL.red )
	end

	if ( !panel:IsEnabled() ) then
		return Box( 0, 0, w, h, COL.field, COL.disabled )
	end

	if ( panel.Hovered ) then
		return Box( 0, 0, w, h, COL.red_faint, COL.red_hover )
	end

	Box( 0, 0, w, h, COL.gradient, COL.red_hover )

end

--[[---------------------------------------------------------
	Tree
-----------------------------------------------------------]]
function SKIN:PaintTree( panel, w, h )

	if ( !panel.m_bBackground ) then return end

	Box( 0, 0, w, h, panel.m_bgColor || COL.field, COL.red_dim )

end

--[[---------------------------------------------------------
	CheckBox
-----------------------------------------------------------]]
function SKIN:PaintCheckBox( panel, w, h )

	local col = panel:IsEnabled() && COL.red || COL.disabled

	Box( 0, 0, w, h, COL.field, col )

	if ( panel:GetChecked() ) then
		surface.SetDrawColor( col )
		surface.DrawRect( 3, 3, w - 6, h - 6 )
	end

end

--[[---------------------------------------------------------
	RadioButton
-----------------------------------------------------------]]
function SKIN:PaintRadioButton( panel, w, h )

	local col = panel:IsEnabled() && COL.red || COL.disabled
	local r = math.floor( math.min( w, h ) / 2 )

	draw.RoundedBox( r, 0, 0, w, h, col )
	draw.RoundedBox( r, 1, 1, w - 2, h - 2, COL.field )

	if ( panel:GetChecked() ) then
		draw.RoundedBox( math.max( r - 4, 1 ), 4, 4, w - 8, h - 8, col )
	end

end

--[[---------------------------------------------------------
	ExpandButton
-----------------------------------------------------------]]
function SKIN:PaintExpandButton( panel, w, h )

	Box( 2, 2, w - 4, h - 4, COL.field, COL.red )

	surface.SetDrawColor( COL.red )
	surface.DrawRect( 5, math.floor( h / 2 ), w - 10, 1 )

	if ( !panel:GetExpanded() ) then
		surface.DrawRect( math.floor( w / 2 ), 5, 1, h - 10 )
	end

end

--[[---------------------------------------------------------
	TextEntry
-----------------------------------------------------------]]
function SKIN:PaintTextEntry( panel, w, h )

	if ( panel.m_bBackground ) then

		if ( !panel:IsEnabled() ) then
			Box( 0, 0, w, h, COL.field, COL.disabled )
		elseif ( panel:HasFocus() ) then
			Box( 0, 0, w, h, COL.field, COL.red )
		else
			Box( 0, 0, w, h, COL.field, COL.red_dim )
		end

	end

	if ( panel.GetPlaceholderText && panel.GetPlaceholderColor && panel:GetPlaceholderText() && panel:GetPlaceholderText():Trim() != "" && panel:GetPlaceholderColor() && ( !panel:GetText() || panel:GetText() == "" ) ) then

		local oldText = panel:GetText()

		local str = panel:GetPlaceholderText()
		if ( str:StartsWith( "#" ) ) then str = str:sub( 2 ) end
		str = language.GetPhrase( str )

		panel:SetText( str )
		panel:DrawTextEntryText( panel:GetPlaceholderColor(), panel:GetHighlightColor(), panel:GetCursorColor() )
		panel:SetText( oldText )

		return
	end

	panel:DrawTextEntryText( panel:GetTextColor(), panel:GetHighlightColor(), panel:GetCursorColor() )

end

--[[---------------------------------------------------------
	Menu
-----------------------------------------------------------]]
function SKIN:PaintMenu( panel, w, h )

	Box( 0, 0, w, h, COL.bg, COL.red )

end

function SKIN:PaintMenuSpacer( panel, w, h )

	surface.SetDrawColor( COL.red_dim )
	surface.DrawRect( 0, 0, w, h )

end

local clr = Color( 0, 0, 0, 80 )
function SKIN:PaintMenuOption( panel, w, h )

	if ( panel.m_bBackground && !panel:IsEnabled() ) then
		Box( 0, 0, w, h, clr )
	end

	if ( panel.m_bBackground && panel:IsEnabled() ) then

		if ( panel.Depressed ) then
			Box( 0, 0, w, h, COL.red )
		elseif ( panel.Hovered || panel.Highlight ) then
			Box( 0, 0, w, h, COL.red_faint )
			Box( 0, 0, 2, h, COL.red )
		end

	end

	local col = panel:IsEnabled() && COL.red || COL.disabled

	if ( panel:GetRadio() ) then

		if ( panel:GetChecked() ) then
			draw.RoundedBox( 3, 9, h / 2 - 3, 7, 7, col )
		end

	elseif ( panel:GetChecked() ) then

		surface.SetDrawColor( col )
		surface.DrawRect( 9, h * .5 - 3, 7, 7 )
	--elseif ( not panel:GetChecked() ) then
	
	--	surface.SetDrawColor( COL.disabled )
	--	surface.DrawRect( 11, h * .5 - 2, 3, 3 )
	end

end

function SKIN:PaintMenuRightArrow( panel, w, h )

	Arrow( math.floor( w / 2 ), math.floor( h / 2 ), "right", COL.red, 3 )

end

function SKIN:PaintMenuBar( panel, w, h )

	Box( 0, 0, w, h, COL.bg )

	surface.SetDrawColor( COL.red )
	surface.DrawRect( 0, h - 1, w, 1 )

end

--[[---------------------------------------------------------
	PropertySheet / Tab
-----------------------------------------------------------]]
function SKIN:PaintPropertySheet( panel, w, h )

	local ActiveTab = panel:GetActiveTab()
	local Offset = 0
	if ( ActiveTab ) then Offset = ActiveTab:GetTall() - 8 end

	Box( 0, Offset, w, h - Offset, COL.panel )
	
	surface.SetMaterial( matGradient )
	surface.SetDrawColor( COL.gradient )
	surface.DrawTexturedRect( 0, 0, w, h )

end

local TabCLR = COL.field:Copy()
TabCLR.a = 255
function SKIN:PaintTab( panel, w, h )

	if ( panel:IsActive() ) then
		return self:PaintActiveTab( panel, w, h )
	end

	if ( panel.Hovered ) then
		return Box( 0, 0, w, h, COL.red_faint, COL.red_hover )
	end

	Box( 0, 0, w, h, TabCLR, COL.red_dim )

end

function SKIN:PaintActiveTab( panel, w, h )

	Box( 0, 0, w, h, COL.panel )

	surface.SetDrawColor( COL.red )

end

local function WindowButtonColors( panel )

	if ( !panel:IsEnabled() ) then return nil, COL.disabled end
	if ( panel.Depressed || panel:IsSelected() ) then return COL.red_hover, COL.black end
	if ( panel.Hovered ) then return COL.red, COL.black end

	return nil, COL.red

end

function SKIN:PaintWindowCloseButton( panel, w, h )

	if ( !panel.m_bBackground ) then return end

	local fill, fg = WindowButtonColors( panel )

	if ( fill ) then
		Box( 0, FRAME_BORDER, w, h - FRAME_BORDER, fill )
	end

	local cx, cy = math.floor( w / 2 ), math.floor( h / 2 )

	surface.SetDrawColor( fg )
	surface.DrawLine( cx - 5, cy - 5, cx + 5, cy + 5 )
	surface.DrawLine( cx - 4, cy - 5, cx + 6, cy + 5 )
	surface.DrawLine( cx - 5, cy + 5, cx + 5, cy - 5 )
	surface.DrawLine( cx - 4, cy + 5, cx + 6, cy - 5 )

end

function SKIN:PaintWindowMinimizeButton( panel, w, h )

	if ( !panel.m_bBackground ) then return end

	local fill, fg = WindowButtonColors( panel )

	if ( fill ) then
		Box( 0, FRAME_BORDER, w, h - FRAME_BORDER, fill )
	end

	surface.SetDrawColor( fg )
	surface.DrawRect( math.floor( w / 2 ) - 5, math.floor( h / 2 ) + 3, 10, 2 )

end

function SKIN:PaintWindowMaximizeButton( panel, w, h )

	if ( !panel.m_bBackground ) then return end

	local fill, fg = WindowButtonColors( panel )

	if ( fill ) then
		Box( 0, FRAME_BORDER, w, h - FRAME_BORDER, fill )
	end

	Box( math.floor( w / 2 ) - 5, math.floor( h / 2 ) - 4, 10, 9, nil, fg, 2 )

end

--[[---------------------------------------------------------
	Scrollbars
-----------------------------------------------------------]]
function SKIN:PaintVScrollBar( panel, w, h )

	Box( 0, 0, w, h, COL.field )

	surface.SetDrawColor( COL.red_dim )
	surface.DrawRect( 0, 0, 1, h )

end

function SKIN:PaintHScrollBar( panel, w, h )

	Box( 0, 0, w, h, COL.field )

	surface.SetDrawColor( COL.red_dim )
	surface.DrawRect( 0, 0, w, 1 )

end

function SKIN:PaintScrollBarGrip( panel, w, h )

	local col

	if ( !panel:IsEnabled() ) then
		col = Color( 80, 80, 80, 120 )
	elseif ( panel.Depressed ) then
		col = COL.red
	elseif ( panel.Hovered ) then
		col = Color( 238, 49, 49, 170 )
	else
		col = Color( 238, 49, 49, 100 )
	end

	surface.SetDrawColor( col )
	surface.DrawRect( 2, 2, w - 4, h - 4 )

end

function SKIN:PaintButtonDown( panel, w, h )	ScrollButton( panel, w, h, "down" )		end
function SKIN:PaintButtonUp( panel, w, h )		ScrollButton( panel, w, h, "up" )		end
function SKIN:PaintButtonLeft( panel, w, h )	ScrollButton( panel, w, h, "left" )		end
function SKIN:PaintButtonRight( panel, w, h )	ScrollButton( panel, w, h, "right" )	end

--[[---------------------------------------------------------
	ComboBox / ListBox
-----------------------------------------------------------]]
function SKIN:PaintComboDownArrow( panel, w, h )

	local col = COL.red

	if ( !panel.ComboBox:IsEnabled() ) then
		col = COL.disabled
	elseif ( panel.ComboBox.Hovered || panel.ComboBox:IsMenuOpen() ) then
		col = COL.red_hover
	end

	Arrow( math.floor( w / 2 ), math.floor( h / 2 ), "down", col, 4 )

end

function SKIN:PaintComboBox( panel, w, h )

	if ( !panel:IsEnabled() ) then
		return Box( 0, 0, w, h, COL.field, COL.disabled )
	end

	if ( panel.Depressed || panel:IsMenuOpen() ) then
		return Box( 0, 0, w, h, COL.red_faint, COL.red )
	end

	if ( panel.Hovered ) then
		return Box( 0, 0, w, h, COL.field, COL.red_hover )
	end

	Box( 0, 0, w, h, COL.field, COL.red_dim )

end

function SKIN:PaintListBox( panel, w, h )

	Box( 0, 0, w, h, COL.field, COL.red_dim )

end

--[[---------------------------------------------------------
	NumberWang стрелки
-----------------------------------------------------------]]
function SKIN:PaintNumberUp( panel, w, h )

	Arrow( math.floor( w / 2 ), math.floor( h / 2 ), "up", ArrowColor( panel ), 3 )

end

function SKIN:PaintNumberDown( panel, w, h )

	Arrow( math.floor( w / 2 ), math.floor( h / 2 ), "down", ArrowColor( panel ), 3 )

end

--[[---------------------------------------------------------
	Tree / Selection
-----------------------------------------------------------]]
function SKIN:PaintTreeNodeButton( panel, w, h )

	if ( !panel.m_bSelected ) then return end

	local tw, _ = panel:GetTextSize()

	Box( 38, 0, tw + 6, h, COL.red_fill, COL.red )

end

function SKIN:PaintSelection( panel, w, h )

	Box( 0, 0, w, h, COL.red_fill, COL.red )

end

--[[---------------------------------------------------------
	Слайдер / прогресс
-----------------------------------------------------------]]
function SKIN:PaintSliderKnob( panel, w, h )

	if ( !panel:IsEnabled() ) then
		return Box( 2, 2, w - 4, h - 4, COL.field, COL.disabled )
	end

	if ( panel.Depressed ) then
		return Box( 2, 2, w - 4, h - 4, COL.red, COL.red )
	end

	if ( panel.Hovered ) then
		return Box( 2, 2, w - 4, h - 4, COL.red_fill, COL.red_hover )
	end

	Box( 2, 2, w - 4, h - 4, COL.black, COL.red )

end

function SKIN:PaintProgress( panel, w, h )

	Box( 0, 0, w, h, COL.field, COL.red_dim )

	local fw = math.floor( ( w - 4 ) * math.Clamp( panel:GetFraction(), 0, 1 ) )

	if ( fw > 0 ) then
		surface.SetDrawColor( COL.red )
		surface.DrawRect( 2, 2, fw, h - 4 )
	end

end

--[[---------------------------------------------------------
	Категории
-----------------------------------------------------------]]
function SKIN:PaintCollapsibleCategory( panel, w, h )

	local hh = panel:GetHeaderHeight()

	if ( h <= hh ) then

		Box( 0, 0, w, h, COL.header, COL.red_dim )

		if ( !panel:GetExpanded() ) then
			Arrow( w - 12, math.floor( h / 2 ), "down", COL.red, 4 )
		end

		return
	end

	Box( 0, hh - 1, w, h - hh + 1, COL.panel, COL.red_dim )
	Box( 0, 0, w, hh, COL.red_fill, COL.red )

end

function SKIN:PaintCategoryList( panel, w, h )

	Box( 0, 0, w, h, COL.field, COL.red_dim )

end

--[[---------------------------------------------------------
	ListView
-----------------------------------------------------------]]
function SKIN:PaintListViewLine( panel, w, h )

	if ( panel:IsSelected() ) then

		Box( 0, 0, w, h, COL.red_fill )
		Box( 0, 0, 2, h, COL.red )

	elseif ( panel.Hovered ) then

		Box( 0, 0, w, h, COL.red_faint )

	elseif ( panel.m_bAlt ) then

		Box( 0, 0, w, h, COL.row_alt )

	end

end

function SKIN:PaintListView( panel, w, h )

	if ( !panel.m_bBackground ) then return end

	Box( 0, 0, w, h, COL.field, COL.red_dim )

end

function SKIN:PaintTooltip( panel, w, h )
	Box( 0, 0, w, h, COL.black, COL.red )
end

derma.DefineSkin( "FazbearsHunt", "Derma that looks like most of the gamemodes UI", SKIN )