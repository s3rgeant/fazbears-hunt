
if ( SERVER ) then 
	AddCSLuaFile() 
	util.AddNetworkString( "FH_ApplyPlayermodel" )
	
	local waitboys = {}
	
	net.Receive("FH_ApplyPlayermodel", function(len, ply)
		
		if waitboys[ply] and CurTime() - waitboys[ply] < 1.5 then
			ply:ChatPrint("Wait a few seconds before applying player model.")
			return
		end
		
		local mdlName = net.ReadString()
		local clr = net.ReadVector()
		
		waitboys[ply] = CurTime()
		
		if isstring(mdl) and mdl:len() > 0 then
			if !ply:IsAnimatronic() then
				local modelPath = player_manager.TranslatePlayerModel(mdlName)
			
				ply:SetModel(modelPath)
				ply:SetPlayerColor(clr)
			end
		end
	end)
	
	return 
end

local default_animations = { "idle_all_01", "menu_walk" }

local hover_CLR = Color(220,0,0)
local unhover_CLR = Color(150,0,0)
local click_CLR = Color(100,0,0)

list.Set( "DesktopWindows", "PlayerEditor", {

	title		= "#smwidget.playermodel",
	icon		= "icon64/playermodel.png",
	width		= 960,
	height		= 700,
	onewindow	= true,

	init = function( widgetIcon, window )

		window:SetTitle( "#smwidget.playermodel_title" )
		window:SetSize( math.min( ScrW() - 16, window:GetWide() ), math.min( ScrH() - 16, window:GetTall() ) )
		window:SetSizable( true )
		window:Center()

		window.Paint = function(self, w, h)
			surface.SetDrawColor(10, 10, 10, 245)
			surface.DrawRect(0, 0, w, h)

			surface.SetDrawColor(180, 0, 0, 255)
			surface.DrawOutlinedRect(0, 0, w, h, 3)
		end

		local mdl = window:Add( "DModelPanel" )
		mdl:Dock( FILL )
		mdl:SetFOV( 40 )
		mdl:SetCamPos( vector_origin )
		mdl:SetDirectionalLight( BOX_RIGHT, Color( 255, 100, 100 ) )
		mdl:SetDirectionalLight( BOX_LEFT, Color( 100, 100, 255 ) )
		mdl:SetAmbientLight( Vector( -64, -64, -64 ) )
		mdl:SetAnimated( true )
		mdl.Angles = angle_zero
		mdl:SetLookAt( Vector( -100, 0, -22 ) )

		local ApplyButton = mdl:Add("DButton")
		ApplyButton:Dock(BOTTOM)
		ApplyButton:SetTall(40)
		ApplyButton:SetText("ПРИМЕНИТЬ МОДЕЛЬ")
		ApplyButton:SetDark(true)
		
		ApplyButton:SetTextColor(Color(255,255,255))

		ApplyButton.Paint = function(self, w, h)
			local col = self:IsHovered() and hover_CLR or unhover_CLR
			if self:IsHovered() and input.IsMouseDown( 107 ) then col = click_CLR end
			surface.SetDrawColor(col)
			surface.DrawRect(0,0,w,h)
			surface.SetDrawColor(0,0,0)
			surface.DrawOutlinedRect(0,0,w,h,2)
		end

		ApplyButton.DoClick = function()
			local model = LocalPlayer():GetInfo( "cl_playermodel" )
			--local modelname = player_manager.TranslatePlayerModel( model )
			
			net.Start("FH_ApplyPlayermodel")
			net.WriteString(model)
			net.WriteVector( Vector( GetConVarString( "cl_playercolor" ) ) )
			net.SendToServer()
		end

		local sheet = window:Add( "DPropertySheet" )
		sheet:Dock( RIGHT )
		sheet:SetWide( 430 )

		sheet.Paint = function(self, w, h)
			surface.SetDrawColor(15, 15, 15, 255)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(150, 0, 0, 255)
			surface.DrawOutlinedRect(0, 0, w, h, 2)
		end

		local modelListPnl = window:Add( "DPanel" )
		modelListPnl:DockPadding( 8, 8, 8, 8 )

		modelListPnl.Paint = function(self, w, h)
			surface.SetDrawColor(15, 15, 15, 255)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(150, 0, 0, 255)
			surface.DrawOutlinedRect(0, 0, w, h, 2)
		end

		local SearchBar = modelListPnl:Add( "DTextEntry" )
		SearchBar:Dock( TOP )
		SearchBar:DockMargin( 0, 0, 0, 8 )
		SearchBar:SetUpdateOnType( true )

		local selectedModel = nil

		local PanelSelect = modelListPnl:Add( "DPanelSelect" )
		PanelSelect:Dock( FILL )

		for name, model in SortedPairs( player_manager.AllValidModels() ) do

			local icon = vgui.Create( "SpawnIcon" )
			icon:SetModel( model )
			icon:SetSize( 64, 64 )
			icon:SetTooltip( name )
			icon.playermodel = name
			icon.model_path = model
			icon.OpenMenu = function( button )
				local menu = DermaMenu()
				menu:AddOption( "#spawnmenu.menu.copy", function() SetClipboardText( model ) end ):SetIcon( "icon16/page_copy.png" )
				menu:Open()
			end

			PanelSelect:AddPanel( icon, { cl_playermodel = name } )

		end

		SearchBar.OnValueChange = function( s, str )
			str = string.lower(str)

			for _, pnl in pairs( PanelSelect:GetItems() ) do
				if not string.find(string.lower(pnl.playermodel), str, 1, true) and
				   not string.find(string.lower(pnl.model_path), str, 1, true) then
					pnl:SetVisible(false)
				else
					pnl:SetVisible(true)
				end
			end

			PanelSelect:InvalidateLayout()
		end

		local sh = sheet:AddSheet( "#smwidget.model", modelListPnl, "icon16/user.png" )
		
		local Tab = sh["Tab"]
		Tab.Paint = function(self, w, h)
			surface.SetDrawColor(15, 15, 15, 255)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(150, 0, 0, 255)
			surface.DrawOutlinedRect(0, 0, w, h + 4, 2)
		end

		local controls = window:Add( "DPanel" )
		controls:DockPadding( 8, 8, 8, 8 )
		
		controls.Paint = function(self, w, h)
			surface.SetDrawColor(15, 15, 15, 255)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(150, 0, 0, 255)
			surface.DrawOutlinedRect(0, 0, w, h, 2)
		end

		local lbl = controls:Add( "DLabel" )
		lbl:SetText( "#smwidget.color_plr" )
		lbl:SetTextColor( Color( 255, 255, 255, 255 ) )
		lbl:Dock( TOP )

		local plycol = controls:Add( "DColorMixer" )
		plycol:SetAlphaBar( false )
		plycol:SetPalette( false )
		plycol:Dock( TOP )
		plycol:SetSize( 200, math.min( window:GetTall() / 3, 260 ) )

		local sh = sheet:AddSheet( "#smwidget.colors", controls, "icon16/color_wheel.png" )
		
		local Tab = sh["Tab"]
		Tab.Paint = function(self, w, h)
			surface.SetDrawColor(15, 15, 15, 255)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(150, 0, 0, 255)
			surface.DrawOutlinedRect(0, 0, w, h + 4, 2)
		end

		local function UpdateFromConvars()
			local model = LocalPlayer():GetInfo( "cl_playermodel" )
			local modelname = player_manager.TranslatePlayerModel( model )
			util.PrecacheModel( modelname )
			mdl:SetModel( modelname )
			mdl.Entity.GetPlayerColor = function() return Vector( GetConVarString( "cl_playercolor" ) ) end
			mdl.Entity:SetPos( Vector( -100, 0, -61 ) )

			plycol:SetVector( Vector( GetConVarString( "cl_playercolor" ) ) )
			mdl.Entity:SetPos( Vector( -100, 0, -61 ) )
			
		end

		local function UpdateFromControls()
			RunConsoleCommand( "cl_playercolor", tostring( plycol:GetVector() ) )
		end

		plycol.ValueChanged = UpdateFromControls

		UpdateFromConvars()

		function PanelSelect:OnActivePanelChanged( old, new )

			if ( old ~= new ) then -- Only reset if we changed the model
				RunConsoleCommand( "cl_playerbodygroups", "0" )
				RunConsoleCommand( "cl_playerskin", "0" )
			end

			timer.Simple( 0.1, function() UpdateFromConvars() end )

		end

		function mdl:DragMousePress()
			self.PressX = gui.MouseX()
			self.Pressed = true
		end

		function mdl:DragMouseRelease()
			self.Pressed = false
		end

		function mdl:LayoutEntity( ent )
			if self.Pressed then
				local mx = gui.MouseX()
				self.Angles = self.Angles - Angle( 0, ( self.PressX - mx ) / 2, 0 )
				self.PressX = mx
			end

			ent:SetAngles( self.Angles )
		end

	end
} )

concommand.Add( "open_playermodel_selector", function()

	for _, icon in pairs( g_ContextMenu.DesktopWidgets:GetChildren() ) do
		if ( icon.WidgetClass ~= "PlayerEditor" ) then continue end

		g_ContextMenu:SetMouseInputEnabled( true )

		icon:DoClick()
		icon.Window:SetParent()
		icon.Window:MakePopup()
		icon.Window:Center()

		break
	end

end )

list.Set( "PlayerOptionsAnimations", "gman", { "menu_gman" } )

list.Set( "PlayerOptionsAnimations", "hostage01", { "idle_all_scared" } )
list.Set( "PlayerOptionsAnimations", "hostage02", { "idle_all_scared" } )
list.Set( "PlayerOptionsAnimations", "hostage03", { "idle_all_scared" } )
list.Set( "PlayerOptionsAnimations", "hostage04", { "idle_all_scared" } )

list.Set( "PlayerOptionsAnimations", "zombine", { "menu_zombie_01" } )
list.Set( "PlayerOptionsAnimations", "corpse", { "menu_zombie_01" } )
list.Set( "PlayerOptionsAnimations", "zombiefast", { "menu_zombie_01" } )
list.Set( "PlayerOptionsAnimations", "zombie", { "menu_zombie_01" } )
list.Set( "PlayerOptionsAnimations", "skeleton", { "menu_zombie_01" } )

list.Set( "PlayerOptionsAnimations", "combine", { "menu_combine" } )
list.Set( "PlayerOptionsAnimations", "combineprison", { "menu_combine" } )
list.Set( "PlayerOptionsAnimations", "combineelite", { "menu_combine" } )
list.Set( "PlayerOptionsAnimations", "police", { "menu_combine" } )
list.Set( "PlayerOptionsAnimations", "policefem", { "menu_combine" } )

list.Set( "PlayerOptionsAnimations", "css_arctic", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_gasmask", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_guerilla", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_leet", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_phoenix", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_riot", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_swat", { "pose_standing_02", "idle_fist" } )
list.Set( "PlayerOptionsAnimations", "css_urban", { "pose_standing_02", "idle_fist" } )
