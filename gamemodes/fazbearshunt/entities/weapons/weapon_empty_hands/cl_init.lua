include( 'shared.lua' )

SWEP.PrintName        = "Empty Hands"
SWEP.Author           = "sergeant"
SWEP.Purpose          = "yo?"

SWEP.Slot             = 0
SWEP.SlotPos          = 0

SWEP.DrawAmmo         = false
SWEP.DrawCrosshair    = false

SWEP.WepSelectIcon    = surface.GetTextureID( "weapons/empty_hands" )
SWEP.BounceWeaponIcon = false

CreateClientConVar( "emptyhands_showcrosshair", "1", false, false )

function SWEP:DrawWeaponSelection( x, y, wide, tall, alpha )

	surface.SetDrawColor( 255, 255, 255, alpha )
	surface.SetTexture( self.WepSelectIcon )

	local fsin = 0

	if ( self.BounceWeaponIcon == true ) then
		fsin = math.sin( CurTime() * 10 ) * 5
	end

	y = y + 10
	x = x + 10
	wide = wide - 20

	surface.DrawTexturedRect( x + (fsin), y - (fsin),  wide-fsin*2 , ( wide / 2 ) + (fsin) )

	self:PrintWeaponInfo( x + wide + 20, y + tall * 0.95, alpha )
end