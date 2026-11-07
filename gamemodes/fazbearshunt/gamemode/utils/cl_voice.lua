
local PANEL = {}
local PlayerVoicePanels = {}

local voice_bar = Material("vgui/base/voice_bar.png")
local voice_w, voice_h = voice_bar:Width(), voice_bar:Height()

local voice_gradient = Material("vgui/base/voice_gradient.png")
local voiceg_w, voiceg_h = voice_gradient:Width(), voice_gradient:Height()

function PANEL:Init()

	self.LabelName = vgui.Create( "DLabel", self )
	self.LabelName:SetFont( "GModNotify" )
	self.LabelName:Dock( FILL )
	self.LabelName:DockMargin( 8, 0, 0, 0 )
	self.LabelName:SetTextColor( color_white )

	self.Avatar = vgui.Create( "AvatarImage", self )
	self.Avatar:Dock( LEFT )
	self.Avatar:SetSize( 32, 32 )

	self.AnimAvatar = vgui.Create( "DImage", self )
	self.AnimAvatar:Dock( LEFT )
	self.AnimAvatar:DockMargin( -32, 0, 0, 0 )
	self.AnimAvatar:SetSize( 32, 32 )

	self.Color = color_transparent

	self:SetSize( 250, 32 + 8 )
	self:DockPadding( 10, 4, 4, 4 )
	self:DockMargin( 2, 2, 2, 2 )
	self:Dock( BOTTOM )

end

function PANEL:Setup( ply )
	self.ply = ply
	self.LabelName:SetText( ply:Nick() )
	self.Avatar:SetPlayer( ply )
	
	if self.AnimAvatar and IsValid(ply:GetPill()) then
		local pillName = ply:GetPill():GetPillName()
		local image = killers.GetAvatar(pillName)
		
		if image then
			self.AnimAvatar:SetMaterial(image)
			self.AnimAvatar:SetAlpha(255)
			self.Avatar:SetAlpha(0)
		else
			self.AnimAvatar:SetAlpha(0)
			self.Avatar:SetAlpha(255)
		end
	end

	self.Color = hook.Run( "GetTeamColor", ply )

	self:InvalidateLayout()

end

function PANEL:Paint( w, h )

	if ( !IsValid( self.ply ) ) then return end
	--draw.RoundedBox( 4, 0, 0, w, h, Color( 0, self.ply:VoiceVolume() * 255, 0, 240 ) )
	
	surface.SetMaterial( voice_bar )
	surface.SetDrawColor( 255, 255, 255, 255 )
	surface.DrawTexturedRect( 0, 0, voice_w, voice_h )
	
	local vv = self.ply:VoiceVolume()
	local red = math.Remap(vv, 0.3, 1, 0, 255)
	surface.SetMaterial( voice_gradient )
	surface.SetDrawColor( red, 255, 0, Lerp(math.ease.OutQuad(vv * 2), 0, vv * 255 * 2) )
	surface.DrawTexturedRect( 55, 0, voiceg_w, voiceg_h )

end

function PANEL:Think()

	if ( IsValid( self.ply ) ) then
		self.LabelName:SetText( self.ply:Nick() )
	end

	if ( self.fadeAnim ) then
		self.fadeAnim:Run()
	end

end

function PANEL:FadeOut( anim, delta, data )

	if ( anim.Finished ) then

		if ( IsValid( PlayerVoicePanels[ self.ply ] ) ) then
			PlayerVoicePanels[ self.ply ]:Remove()
			PlayerVoicePanels[ self.ply ] = nil
			return
		end

	return end

	self:SetAlpha( 255 - ( 255 * delta ) )

end

derma.DefineControl( "VoiceNotify", "", PANEL, "DPanel" )

function GM:PlayerStartVoice( ply )

	if ( !IsValid( g_VoicePanelList ) ) then return end

	-- There'd be an exta one if voice_loopback is on, so remove it.
	GAMEMODE:PlayerEndVoice( ply )

	local curPanel = PlayerVoicePanels[ ply ]

	if ( IsValid( curPanel ) ) then

		if curPanel.fadeAnim then
			curPanel.fadeAnim:Stop()
			curPanel.fadeAnim = nil
		end

		curPanel:SetAlpha( 255 )
		return
	end

	if ( !IsValid( ply ) ) then return end

	local pnl = g_VoicePanelList:Add( "VoiceNotify" )
	pnl:Setup( ply )

	PlayerVoicePanels[ ply ] = pnl

end

local function VoiceClean()

	for k, v in pairs( PlayerVoicePanels ) do

		if ( !IsValid( k ) ) then
			GAMEMODE:PlayerEndVoice( k )
		end

	end

end
timer.Create( "VoiceClean", 10, 0, VoiceClean )

function GM:PlayerEndVoice( ply )

	if ( IsValid( PlayerVoicePanels[ ply ] ) ) then
		if ( PlayerVoicePanels[ ply ].fadeAnim ) then return end

		PlayerVoicePanels[ ply ].fadeAnim = Derma_Anim( "FadeOut", PlayerVoicePanels[ ply ], PlayerVoicePanels[ ply ].FadeOut )
		PlayerVoicePanels[ ply ].fadeAnim:Start( 2 )
	end
end

local function CreateVoiceVGUI()
	g_VoicePanelList = vgui.Create( "DPanel" )

	g_VoicePanelList:ParentToHUD()
	g_VoicePanelList:SetPos( ScrW() - 300, 100 )
	g_VoicePanelList:SetSize( 250, ScrH() - 200 )
	g_VoicePanelList:SetPaintBackground( false )
end

hook.Add( "InitPostEntity", "CreateVoiceVGUI", CreateVoiceVGUI )

local speaker = Material("voice/icntlk_pl.vtf")
local speaker_mute = Material("voice/muted_speaker.png")

local clr_background = Color(0,0,0,166)
hook.Add("PlayerStartVoice", "HideVoicePanels", function(ply)
    local listener = LocalPlayer()
	
	if !IsValid(listener) then return end
	
    if ply == listener and listener:Team() ~= 2701 and listener:Team() ~= TEAM_SPECTATOR then
		local scrw = ScrW()
		local scrh = ScrH()
        hook.Add("HUDPaint", "DrawLocalPlayerVoiceIcon", function()
            local x, y = (scrw * .5) - (64 * .5), scrh - 50 - (64 * .5)
			local icon = (!listener:GetAudible() and listener:GetPill()) and speaker_mute or speaker
			
			draw.RoundedBox(12, x, y, 64, 64, clr_background)
			
			local size = 48
			local hsize = size * .5
			
			local x, y = (scrw * .5) - hsize, scrh - 50 - hsize
			
			local volume = ply:VoiceVolume()
			
			local a = math.Remap(volume, 0, 1, 150, 255)
			local volsize = math.Remap(volume, 0, 1, 0, 16)
			
			surface.SetMaterial(icon)
			surface.SetDrawColor(a, a, a, 255)
			surface.DrawTexturedRect(x - (volsize*.5), y - (volsize*.5), size+volsize, size+volsize)
        end)
		return false
    end
	if !IsValid(ply) then return end
	
	local proximityEnabled = GetConVar("proximity_enabled"):GetInt()
	
	if proximityEnabled == 0 then
		return
	end
	
    local listenerTeam = listener:Team()
    local speakerTeam = ply:Team() or TEAM_SURVIVOR
	
    if listenerTeam == TEAM_SPECTATOR and speakerTeam == TEAM_SPECTATOR then
        return
    end

    if listenerTeam == 2701 and speakerTeam == 2701 then
        return
    end

    return false
end)

hook.Add("PlayerEndVoice", "HideVoicePanels", function(ply)
    if ply == LocalPlayer() then
        hook.Remove("HUDPaint", "DrawLocalPlayerVoiceIcon")
    end
end)