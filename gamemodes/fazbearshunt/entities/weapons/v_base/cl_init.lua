
include( "shared.lua" )

SWEP.Slot				= 0						-- Slot in the weapon selection menu
SWEP.SlotPos			= 0					-- Position in the slot
SWEP.DrawAmmo			= false					-- Should draw the default HL2 ammo counter
SWEP.DrawCrosshair		= true					-- Should draw the default crosshair
SWEP.DrawWeaponInfoBox	= false					-- Should draw the weapon info box
SWEP.BounceWeaponIcon	= false					-- Should the weapon icon bounce?
SWEP.SwayScale			= 1.0					-- The scale of the viewmodel sway
SWEP.BobScale			= 1.0					-- The scale of the viewmodel bob

SWEP.RenderGroup		= RENDERGROUP_OPAQUE

-- Override this in your SWEP to set the icon in the weapon selection
SWEP.WepSelectIcon		= surface.GetTextureID( "weapons/swep" )

-- This is the corner of the speech bubble
SWEP.SpeechBubbleLid	= surface.GetTextureID( "gui/speech_lid" )

--[[---------------------------------------------------------
	You can draw to the HUD here - it will only draw when
	the client has the weapon deployed..
-----------------------------------------------------------]]
function SWEP:DrawHUD()
end

--[[---------------------------------------------------------
	Checks the objects before any action is taken
	This is to make sure that the entities haven't been removed
-----------------------------------------------------------]]
function SWEP:DrawWeaponSelection( x, y, wide, tall, alpha )

	-- Set us up the texture
	surface.SetDrawColor( 255, 255, 255, alpha )
	surface.SetTexture( self.WepSelectIcon )

	-- Lets get a sin wave to make it bounce
	local fsin = 0

	if ( self.BounceWeaponIcon == true ) then
		fsin = math.sin( CurTime() * 10 ) * 5
	end

	-- Borders
	y = y + 10
	x = x + 10
	wide = wide - 20

	-- Draw that mother
	surface.DrawTexturedRect( x + fsin, y - fsin,  wide - fsin * 2 , ( wide / 2 ) + fsin )

	-- Draw weapon info box
	self:PrintWeaponInfo( x + wide + 20, y + tall * 0.95, alpha )

end

--[[---------------------------------------------------------
	This draws the weapon info box
-----------------------------------------------------------]]
function SWEP:PrintWeaponInfo( x, y, alpha )

	if ( self.DrawWeaponInfoBox == false ) then return end

	if ( self.InfoMarkup == nil ) then
		local title_color = "<color=230,230,230,255>"
		local text_color = "<color=150,150,150,255>"

		local str = "<font=HudSelectionText>"
		if ( self.Author != "" ) then str = str .. title_color .. "#entityinfo.author</color>\t" .. text_color .. self.Author .. "</color>\n" end
		if ( self.Contact != "" ) then str = str .. title_color .. "#entityinfo.contact</color>\t" .. text_color .. self.Contact .. "</color>\n\n" end
		if ( self.Purpose != "" ) then str = str .. title_color .. "#entityinfo.purpose</color>\n" .. text_color .. self.Purpose .. "</color>\n\n" end
		if ( self.Instructions != "" ) then str = str .. title_color .. "#entityinfo.instructions</color>\n" .. text_color .. self.Instructions .. "</color>\n" end
		str = str .. "</font>"

		self.InfoMarkup = markup.Parse( str, 250 )
	end

	surface.SetDrawColor( 60, 60, 60, alpha )
	surface.SetTexture( self.SpeechBubbleLid )

	surface.DrawTexturedRect( x, y - 64 - 5, 128, 64 )
	draw.RoundedBox( 8, x - 5, y - 5, 260, self.InfoMarkup:GetHeight() + 18, Color( 60, 60, 60, alpha ) )

	self.InfoMarkup:Draw( x + 5, y + 5, nil, nil, alpha )

end

function SWEP:FreezeMovement()
	return false
end

function SWEP:ViewModelDrawn( vm )
end

function SWEP:PreDrawViewModel( vm )
	local myself = LocalPlayer()
	if vrmod and vrmod.IsPlayerInVR(myself) then
		return true
	end
end
--[[
if vrmod then
	hook.Add("VRMod_PreRender", "fh_viewmodels", function()
		local ply = LocalPlayer()
		
		if IsValid(ply:GetPillCostume()) then
			
		end
	end)
end
--]]

function SWEP:OnRestore()
end

function SWEP:CustomAmmoDisplay()
end

function SWEP:GetViewModelPosition( pos, ang )

	return pos, ang

end

function SWEP:TranslateFOV( current_fov )

	return current_fov

end

function SWEP:DrawWorldModel()

	self:DrawModel()

end

function SWEP:DrawWorldModelTranslucent()

	self:DrawModel()

end

function SWEP:AdjustMouseSensitivity()

	return nil

end

function SWEP:GetTracerOrigin()

--[[
	local ply = self:GetOwner()
	local pos = ply:EyePos() + ply:EyeAngles():Right() * -5
	return pos
--]]

end

function SWEP:FireAnimationEvent( pos, ang, event, options )

	if ( !self.CSMuzzleFlashes ) then return end

end

function SWEP:DoDrawCrosshair(x, y)
	if !self.GetLastAttack then return end

	local nextAttack = self:GetNextPrimaryFire()
	local lastAttack = self:GetLastAttack()
	local now = CurTime()
	
	if lastAttack <= 0 then return end

	local cd = nextAttack - lastAttack
	local fill = 1

	fill = math.Clamp((nextAttack - now) / cd, 0, 1)
	
	local max_width = 88

    surface.SetDrawColor(0,0,0,150)
	if nextAttack-now >= 0 then
		surface.DrawOutlinedRect( x - (max_width/2) * fill - 2, y + 8, max_width * fill + 4, 4, 6 )
		surface.SetDrawColor(255,255,255)
		surface.DrawRect(x - (max_width/2) * fill, y + 8, max_width * fill, 4)
	end
end