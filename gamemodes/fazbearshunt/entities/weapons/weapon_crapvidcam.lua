AddCSLuaFile()

sound.Add({
	name = "CrapVidCam.ToggleCamera",
	channel = CHAN_WEAPON,
	volume = 0.5,
	level = 70,
	pitch = 112,
	sound = "buttons/lightswitch2.wav",
})

SWEP.PrintName = "Crappy Video Camera"

if CLIENT then
SWEP.Instructions = [[
<color=green>[]].. language.GetPhrase("keys.lmb") ..[[]</color> ]].. language.GetPhrase("crapvidcam.camstart") ..[[

<color=#00ffff> ]].. language.GetPhrase("crapvidcam.camsave") ..[[ </color>]]
end

if CLIENT then
	SWEP.WepSelectIcon = surface.GetTextureID("crapvidcam/vidcamicon")
end

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.HoldType = "rpg"

SWEP.WorldModel = Model("models/dav0r/camera.mdl")
SWEP.ViewModel = Model("models/dav0r/camera.mdl")
SWEP.ViewModelFOV = 55
SWEP.UseHands = false

SWEP.Slot = 4
SWEP.SlotPos = 3

SWEP.Primary.Sound = Sound("CrapVidCam.ToggleCamera")
SWEP.Primary.Recoil = 8.5
SWEP.Primary.Damage = 60
SWEP.Primary.NumShots = 1
SWEP.Primary.Cone = 0.02
SWEP.Primary.Delay = 0.15

SWEP.Primary.Ammo = "none"
SWEP.Primary.Automatic = false
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1

SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Automatic = false
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1

SWEP.Spread = {}
SWEP.Spread.Min = 0
SWEP.Spread.Max = 0.25
SWEP.Spread.IronsightsMod = 0.2
SWEP.Spread.CrouchMod = 0.6
SWEP.Spread.AirMod = 1.2
SWEP.Spread.RecoilMod = 0.05
SWEP.Spread.VelocityMod = 0.5

SWEP.IronsightsPos = Vector(16, 30, -6)
SWEP.IronsightsAng = Angle(0, 0, 0)
SWEP.IronsightsFOV = 0.8
SWEP.IronsightsSensitivity = 0.8
SWEP.IronsightsCrosshair = false
SWEP.UseIronsightsRecoil = true

SWEP.LoweredPos = Vector(16, 30, -6)
SWEP.LoweredAng = Angle(0, 0, 0)
SWEP.SelectFont = "HudDefault"
SWEP.IronAnimSpeed = 0.05
SWEP.NoEmptyAnims = true
SWEP.ReloadSpeed = 1.6
SWEP.IronAdjust = 0.5

SWEP.DefaultPos = Vector(16, 30, -6)
--SWEP.DefaultPos = Vector(0, 20, 0)

SWEP.DrawCrosshair = false

function SWEP:Initialize()
	self:SetHoldType("rpg")
end

if SERVER then
	util.AddNetworkString("crapvidcam")

	hook.Add("PlayerSpawn", "CrapVidCam", function(ply, t)
		net.Start("crapvidcam")
		net.Send(ply)
	end)

	hook.Add("PlayerDeath", "CrapVidCam", function(ply, wep, killer)
		if IsValid(ply) then
			timer.Simple(0.2, function()
				if not IsValid(ply) then return end
				net.Start("crapvidcam")
				net.Send(ply)
			end)
		end
	end)
else
	VIDCAM_RECORDING = false
	VIDCAM_CONFIG = {
		container = "webm",
		video = "vp8",
		audio = "vorbis",
		quality = 24,
		bitrate = 80,
		fps = 24,
		lockfps = false,
		width = 480,
		height = 360,
	}

	function VIDCAM_TOGGLE()
		local myself = LocalPlayer()
		VIDCAM_RECORDING = not VIDCAM_RECORDING
		if VIDCAM_RECORDING then
			VIDCAM_CONFIG.name = "vidcam-" .. util.DateStamp()
			VIDCAM_CONFIG.height = math.Round(VIDCAM_CONFIG.width * (ScrH() / ScrW()))
			VIDCAM_WRITER, VIDCAM_ERROR = video.Record(VIDCAM_CONFIG)
			if not VIDCAM_WRITER then
				MsgN("Couldn't record video: ", VIDCAM_ERROR)
				return
			end
			VIDCAM_WRITER:SetRecordSound(true)
			hook.Add("PreDrawViewModels", "CrapVidCam", function()
				VIDCAM_WRITER:AddFrame(FrameTime(), true)
				myself:SetDSP(38, true)
			end)
		else
			hook.Remove("PreDrawViewModels", "CrapVidCam")
			chat.AddText(Color(0, 255, 255), "Видео сохранено по пути: garrysmod/videos/" .. VIDCAM_CONFIG.name .. ".webm")
			VIDCAM_WRITER:Finish()
			VIDCAM_WRITER = nil -- memory leak! whoops
			myself:SetDSP(myself.outworld and 16 or 0, true)
		end
	end

	net.Receive("crapvidcam", function(len)
		if VIDCAM_RECORDING then
			VIDCAM_TOGGLE()
		end
	end)

	local recColor = Color(255, 100, 100)
	local recColorBack = Color(20, 20, 20)

	hook.Add("HUDPaint", "CrapVidCam", function()
		if VIDCAM_RECORDING then
			if math.sin(CurTime() * 8) > 0 then
				draw.SimpleTextOutlined("СЪЁМКА", "DermaLarge", ScrW() * 0.5, 0, recColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, recColorBack)
			end
			return
		end
	end)

	hook.Add("CalcView", "CrapVidCam", function(ply, pos, angles, fov)
		if VIDCAM_RECORDING then
			return {
				origin = pos,
				angles = angles,
				fov = fov * 0.65
			}
		end
	end)
end

function SWEP:CanSecondaryAttack() return false end

function SWEP:PrimaryAttack()
	if SERVER and game.SinglePlayer() then
		self:CallOnClient("PrimaryAttack")
		return
	end

	local curtime = CurTime()
	if curtime < self:GetNextPrimaryFire() then return end
	self:SetNextPrimaryFire(curtime + 0.1)
	self:EmitSound("CrapVidCam.ToggleCamera")

	if CLIENT and (IsFirstTimePredicted() or game.SinglePlayer()) then
		VIDCAM_TOGGLE()
	end
end

function SWEP:Holster()
	if CLIENT and (IsFirstTimePredicted() or game.SinglePlayer()) and LocalPlayer() == self:GetOwner() and VIDCAM_RECORDING then
		VIDCAM_TOGGLE()
	end

	if game.SinglePlayer() then
		self:CallOnClient("PrimaryAttack")
	end

	return true
end

function SWEP:OnRemove()
	if CLIENT and VIDCAM_RECORDING then
		VIDCAM_TOGGLE()
	end

	if game.SinglePlayer() then
		self:CallOnClient("PrimaryAttack")
	end
end

function SWEP:DrawWorldModel()
	local ply = self:GetOwner()
	
	if not IsValid(ply) or not ply:LookupAttachment("anim_attachment_RH") then
		self:DrawModel()
		return
	end

	local att = ply:GetAttachment(ply:LookupAttachment("anim_attachment_RH"))
	if att then 
		local ang = att.Ang
		self:SetPos(att.Pos + ang:Up() * 10 + ang:Right() + ang:Forward() * 2)
		self:SetAngles(ang)
	end

	self:SetupBones()
	self:DrawModel()
end


local camPos = Vector(16, 30, -6)

function SWEP:GetViewModelPosition(pos, ang)
	pos:Add(camPos[1] * ang:Right())
	pos:Add(camPos[2] * ang:Forward())
	pos:Add(camPos[3] * ang:Up())
	return pos, ang
end
