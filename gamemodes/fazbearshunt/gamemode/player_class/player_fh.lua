
AddCSLuaFile()
DEFINE_BASECLASS( "player_default" )

if ( CLIENT ) then

	CreateConVar( "cl_playercolor", "0.24 0.34 0.41", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The value is a Vector - so between 0-1 - not between 0-255" )
	CreateConVar( "cl_playerskin", "0", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The skin to use, if the model has any" )
	CreateConVar( "cl_playerbodygroups", "0", { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }, "The bodygroups to use, if the model has any" )

end

local PLAYER = {}

PLAYER.DuckSpeed			= 0.2		-- How fast to go from not ducking, to ducking
PLAYER.UnDuckSpeed			= 0.2		-- How fast to go from ducking, to not ducking

--
-- Creates a Taunt Camera
--
PLAYER.TauntCam = TauntCamera()

--
-- See gamemodes/base/player_class/player_default.lua for all overridable variables
--
PLAYER.SlowWalkSpeed		= 100
PLAYER.WalkSpeed 			= 200
PLAYER.RunSpeed				= 420
PLAYER.UseVMHands			= true		-- Uses viewmodel hands

--
-- Set up the network table accessors
--
function PLAYER:SetupDataTables()

	self.Player:NetworkVar( "Entity", 0, "PillCostume" )
	self.Player:NetworkVar( "Entity", 1, "ActualPillCostume" )
	BaseClass.SetupDataTables( self )

end


function PLAYER:Loadout()

	self.Player:RemoveAmmo(9999, "Pistol")
	self.Player:RemoveAmmo(9999, "grenade")

	self.Player:GiveAmmo( 64,	"Pistol", 		true )
	self.Player:GiveAmmo( 5,	"grenade", 		true )

	self.Player:Give( "weapon_pistol" )
	if IsChristmas() then
		self.Player:RemoveAmmo(9999, "snowball")
		self.Player:GiveAmmo( 14,	"snowball", 	true )
		self.Player:Give( "weapon_snowball" )
	end
	self.Player:Give( "weapon_frag" )
	self.Player:Give( "weapon_crowbar" )
	self.Player:Give( "weapon_empty_hands" )

	self.Player:SwitchToDefaultWeapon()

end

function PLAYER:Spawn()

	BaseClass.Spawn( self )

	local plyclr = self.Player:GetInfo( "cl_playercolor" )
	self.Player:SetPlayerColor( Vector( plyclr ) )

end


function PLAYER:SetModel()
	local ply = self.Player
	local cl_playermodel = ply:GetInfo( "cl_playermodel" )
	
	if not player_editor.PassesModelStriction(cl_playermodel, ply) then
		cl_playermodel = ""
	end
	
	local modelname = player_manager.TranslatePlayerModel( cl_playermodel )
	
	
	util.PrecacheModel( modelname )
	ply:SetModel( modelname )

	local skin = ply:GetInfoNum( "cl_playerskin", 0 )
	ply:SetSkin( skin )

	local bodygroups = ply:GetInfo( "cl_playerbodygroups" )
	if ( bodygroups == nil ) then bodygroups = "" end

	local groups = string.Explode( " ", bodygroups )
	for k = 0, ply:GetNumBodyGroups() - 1 do
		ply:SetBodygroup( k, tonumber( groups[ k + 1 ] ) or 0 )
	end

end

--
-- Return true to draw local (thirdperson) camera - false to prevent - nothing to use default behaviour
--
function PLAYER:ShouldDrawLocal()

	if ( self.TauntCam:ShouldDrawLocalPlayer( self.Player, self.Player:IsPlayingTaunt() ) ) then return true end

end

--
-- Allow player class to create move
--
function PLAYER:CreateMove( cmd )

	if ( self.TauntCam:CreateMove( cmd, self.Player, self.Player:IsPlayingTaunt() ) ) then return true end

end

--
-- Allow changing the player's view
--
function PLAYER:CalcView( view )

	if ( self.TauntCam:CalcView( view, self.Player, self.Player:IsPlayingTaunt() ) ) then return true end

	-- Your stuff here

end

--
-- Reproduces the jump boost from HL2 singleplayer
--
local JUMPING

function PLAYER:StartMove( move )
	
	local ply = self.Player

	-- Only apply the jump boost in FinishMove if the player has jumped during this frame
	-- Using a global variable is safe here because nothing else happens between SetupMove and FinishMove
	if bit.band( move:GetButtons(), IN_JUMP ) ~= 0 and bit.band( move:GetOldButtons(), IN_JUMP ) == 0 and ply:OnGround() then
		JUMPING = true
	end

    if ply:Crouching() and ply:OnGround() then
        local targetSpeed = ply:GetWalkSpeed() * ply:GetCrouchedWalkSpeed()
        move:SetMaxSpeed(targetSpeed)
    end
end

function PLAYER:Move( move )

	local ply = self.Player
	
	if bit.band( move:GetButtons(), IN_JUMP ) ~= 0 and bit.band( move:GetOldButtons(), IN_JUMP ) == 0 and ply:OnGround() then
		JUMPING = true
	end
	
    if ply:Crouching() and ply:OnGround() then
        local targetSpeed = ply:GetWalkSpeed() * ply:GetCrouchedWalkSpeed()
        move:SetMaxClientSpeed(targetSpeed)
        move:SetMaxSpeed(targetSpeed)
    end
end

local meta = FindMetaTable("Player")

if meta then
	function meta:GetJumpBoost()
		return self:GetNWFloat("JumpBoost", 1)
	end

	function meta:SetJumpBoost(val)
		self:SetNWFloat("JumpBoost", math.Clamp(val, 0, 1))
	end
	
	function meta:GetJumpBoostMultiplier()
		return self:GetNWFloat("JumpBoostMult", 1)
	end

	function meta:SetJumpBoostMultiplier(val)
		self:SetNWFloat("JumpBoostMult", math.Clamp(val, 0, 1))
	end

	function meta:GetLastJumpTime()
		return self:GetNWFloat("LastJumpTime", 0)
	end

	function meta:SetLastJumpTime(t)
		self:SetNWFloat("LastJumpTime", t)
	end

	function meta:Crouch()
		self:AddFlags(2)
		self:AddFlags(4)
		
		self:SetCollisionBounds(self:GetHullDuck())
		self:SetCurrentViewOffset(self:GetViewOffsetDucked())
	end
end

local function UpdateJumpBoost(ply)
	local curTime = CurTime()
	local lastJump = ply:GetLastJumpTime()

	if lastJump == 0 then return end

	local delta = curTime - lastJump
	
	local regen = delta * 0.10
	
	local newBoost = ply:GetJumpBoostMultiplier() + regen
	
	if newBoost >= 1 then
		newBoost = 1
		ply:SetLastJumpTime(0)
	else
		ply:SetLastJumpTime(curTime)
	end

	ply:SetJumpBoostMultiplier(newBoost)
end

function PLAYER:FinishMove(move)
	local ply = self.Player

	UpdateJumpBoost(ply)

	if JUMPING then
		local boost = ply:GetJumpBoostMultiplier()
		boost = math.Clamp(boost - 0.09, 0, ply:GetJumpBoost())
		
		--print(boost)

		if IsFirstTimePredicted() then
			ply:SetJumpBoostMultiplier(boost)
		end
		ply:SetLastJumpTime(CurTime())

		local forward = move:GetAngles()
		forward.p = 0
		forward = forward:Forward()

		local speedBoostPerc = ((not ply:Crouching()) and 0.5 or 0) * boost

		local speedAddition = math.abs(move:GetForwardSpeed() * speedBoostPerc)
		local maxSpeed = move:GetMaxSpeed() * (1 + speedBoostPerc)
		local newSpeed = speedAddition + move:GetVelocity():Length2D()

		if newSpeed > maxSpeed then
			speedAddition = speedAddition - (newSpeed - maxSpeed)
		end

		if move:GetVelocity():Dot(forward) < 0 then
			speedAddition = -speedAddition
		end

		move:SetVelocity(forward * speedAddition + move:GetVelocity())
	end
	JUMPING = false
end

player_manager.RegisterClass( "player_fh", PLAYER, "player_default" )

local path = "fazbearshunt/gamemode/player_class/subclasses/"
local files, folders = file.Find(path .. "*", "LUA")
	
for _, file_name in ipairs(files) do
	include(path .. file_name)
end