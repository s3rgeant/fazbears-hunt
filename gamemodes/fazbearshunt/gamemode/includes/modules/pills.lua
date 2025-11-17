AddCSLuaFile()
-- Module starts here...
module("pills", package.seeall)
-- Load files
file.CreateDir("pill_config")

-- Pack Registration
local packString = ""
local packs = {}
local currentPack

team.SetUp(TEAM_PILLS, 'PILLS', Color(255, 0, 0))

function packStart(name, id, icon)
    currentPack = {}
    currentPack.name = name
    currentPack.icon = icon or "icon16/pill.png"
    currentPack.headers = {}
    currentPack.items = {}
    table.insert(packs, currentPack)
    id = id:gsub("%W", "-"):lower()
    packString = packString .. id .. " "
end

-- Pill Registration
local forms = {}

function register(name, t)
    t.name = name

    if t.printName then
        table.insert(currentPack.items, {
            type = "pill",
            name = name,
            printName = t.printName
        })
    end

    if (t.sounds) then
        for _, s in pairs(t.sounds) do
            if (isstring(s)) then
                util.PrecacheSound(s)
            elseif (istable(s)) then
                for k, s2 in pairs(s) do
                    if s2 == false then
                        s[k] = nil
                    else
                        util.PrecacheSound(s2)
                    end
                end
            end
        end
    end

    forms[name] = t
end

function clone(newname, name, t)
	if not forms[name] then return end
	
	local function deepCopy(orig)
		if istable(orig) then
			local copy = {}
			for k, v in pairs(orig) do
				copy[k] = deepCopy(v)
			end
			return copy
		else
			return orig
		end
	end
	
	local base = deepCopy(forms[name])
	
	if istable(t) then
		for k, v in pairs(t) do
			base[k] = v
		end
	end
	
	register(newname, base)
end


function editPillTable(name, func, newfunc)
	forms[name][func] = newfunc
end

function getPillTable(typ)
    if !forms[typ] then
        Msg("Can't find Pill Table for " .. typ)
        return
    end
    return table.Copy(forms[typ])
end

function getAllPills()
    return table.Copy(forms)
end

function getFormCount()
    return table.Count(forms)
end

function getRandomForm()
    local v, k = table.Random(forms)

    return k
end

-- Player to Pill Entity Mapping
function mapEnt(ply, ent)
    ply.fh_pill_ent = ent
end

function unmapEnt(ply, ent)
    if ply.fh_pill_ent == ent then
        ply.fh_pill_ent = nil
    elseif IsValid(ply.fh_pill_ent) then
        return ply.fh_pill_ent.formTable.type
    end
end

function getMappedEnt(ply)
    return ply.fh_pill_ent
end

local PLAYER = FindMetaTable("Player")

if PLAYER then
	function PLAYER:GetPill()
		return self.fh_pill_ent
	end
end

-- Concommands, Convars, etc.
if SERVER then
    concommand.Add("pills_apply", function(ply, cmd, args, str)
		if IsValid(ply) and !ply:IsAdmin() then return end
        apply(args[1], args[2], "user", tonumber(args[3]))
    end)

    concommand.Add("pills_restore", function(ply, cmd, args, str)
		if IsValid(ply) and !ply:IsAdmin() then return end
        restore(args[1])
    end)

    concommand.Add("pills_restore_force", function(ply, cmd, args, str)
		if IsValid(ply) and !ply:IsAdmin() then return end
        restore(ply, true)
    end)
end

-- NW Strings
if SERVER then
    util.AddNetworkString("pk_pill_morphsound")
else
    local snd_pillSet = Sound("Friends/friend_online.wav")
    local snd_pillFail = Sound("buttons/button2.wav")

    net.Receive("pk_pill_morphsound", function(len, pl)
        local success = net.ReadBit()

        if success == 1 then
            surface.PlaySound(snd_pillSet)
        else
            surface.PlaySound(snd_pillFail)
        end
    end)
end

-- Apply/Restore
if SERVER then
    --[[
		Modes:
		DEFAULT - Force, but don't change locking settings
		user - Obey restrictions
		force - force, change locking settings
	]]
    function apply(ply, name, mode, option)
        if CLIENT then return end
		
		local found = false
		for _, plyr in player.Iterator() do
			if plyr:Nick() == ply then
				ply = plyr
				found = true
				break
			end
		end
		if not found then return end
		
        t = forms[name]

        if not t then
            print("Player '" .. ply:Name() .. "' attempted to use nonexistent pill '" .. name .. "'.")
            ply:PrintMessage(HUD_PRINTCONSOLE, "Attempted to use nonexistent pill '" .. name .. "'.")

            return
        end

        local old = getMappedEnt(ply)

        local overridePos
        local overrideAng

        --restriction logic
        if mode == "user" then
            local success = true

            if not t.printName then
                ply:ChatPrint("You cannot use this pill directly.")
                success = false
            end

            net.Start("pk_pill_morphsound")
            net.WriteBit(success)
            net.Send(ply)
            if not success then return end
        end

        local e

		if t.type == "ply" then
            e = ents.Create("pill_costume")
        else
            ply:ChatPrint("WARNING: Attempted to use invalid pill type.")

            return
        end

        local oldvel

        if IsValid(old) and old.formTable.type == "phys" then
            local phys = old:GetPhysicsObject()
            oldvel = IsValid(phys) and phys:GetVelocity() or Vector(0, 0, 0)
        else
            oldvel = ply:GetVelocity()
        end

        --Remove old AFTER we had a chance to set the new
        if IsValid(old) then
            old:Remove()
        end

		e:SetPillForm(name)
		e:SetPillUser(ply)
		e.option = option
		e:Spawn()
		e:Activate()
		
		ply:SetTeam(TEAM_PILLS)

        hook.Run("PillServerApply", ply, e.formTable.name)

		if t.type == "phys" then
			local phys = e:GetPhysicsObject()

			if IsValid(phys) then
				phys:SetVelocity(oldvel)
			end
		end

		--end
		if t.type ~= "ply" then
			ply:SetLocalVelocity(Vector(0, 0, 0))
		end

		return e
    end
end

--set breakout to true to break out of any locks
--returns true if the player was using a pill
--shared because it goes in the noclip function, I guess
function restore(ply, breakout)
		
	local found = false
	for _, plyr in player.Iterator() do
		if plyr:Nick() == ply then
			ply = plyr
			found = true
			break
		end
	end
	if not found then return end
		
    local ent = getMappedEnt(ply)

    if IsValid(ent) then
		unmapEnt(ply, ent)
		
        if SERVER then
			ent.notDead = true
			ent:Remove()
			
            ply:SetViewOffset(Vector(0, 0, 64))
            ply:SetViewOffsetDucked(Vector(0, 0, 28))
            ply:SetStepSize(18)
            -- Not sure if this chunk is needed... leaving it for now.
            ply:Freeze(false)

            if ply:Alive() then
                ply:SetMoveType(MOVETYPE_WALK)

				ply:SetNotSolid(false)
            end
            ply:SetRenderMode(RENDERMODE_NORMAL)

            if ply:Alive() then
				-- Just respawn the player to reset most stuff.
				local angs = ply:EyeAngles()
				local pos = ply:GetPos()
				local vel = ply:GetVelocity()
				local hp = ply:Health()
				local wasCrouching = ply:Crouching()
				ply:StripWeapons()
				ply:StripAmmo()
				ply:Spawn()
				ply:SetEyeAngles(angs)
				ply:SetMaterial("")
				ply:DrawShadow(true)
				ply:SetPos(pos)
				ply:SetVelocity(vel)
				ply:SetHealth(hp)
				if wasCrouching then
					ply:ConCommand("+duck")
					timer.Simple(0.1, function()
						ply:ConCommand("-duck")
					end)
				end
            end

            if not breakout then
                net.Start("pk_pill_morphsound")
                net.WriteBit(ent.notDead)
                net.Send(ply)
            end
        end

        return true
    end
end

hook.Add("KeyPress", "pk_pill_keypress_shared", function(ply, key)
	local ent = getMappedEnt(ply)

	if IsValid(ent) then
		ply:LagCompensation( true )
		ent:DoKeyPressShared(ply, key)
		ply:LagCompensation( false )
	end
end)

-- Shared attack2 hook with no lag compensation
hook.Add("KeyPress", "pk_pill_keypress_nolc_shared", function(ply, key)
	local ent = getMappedEnt(ply)

	if IsValid(ent) then
		ent:DoKeyPressShared_NoLagCompensation(ply, key)
	end
end)

-- THEM HOOKS
if SERVER then
    hook.Add("KeyPress", "pk_pill_keypress", function(ply, key)
        local ent = getMappedEnt(ply)

        if IsValid(ent) then
			ply:LagCompensation( true )
            ent:DoKeyPress(ply, key)
			ply:LagCompensation( false )
        end
    end)

    hook.Add("PlayerSwitchFlashlight", "pk_pill_flashlight", function(ply, on)
        local ent = getMappedEnt(ply)

        if IsValid(ent) and on then
            if ent.formTable.flashlight and not ent.animFreeze then
                ent.formTable.flashlight(ply, ent)
            end
        end
    end)

    hook.Add("SetupPlayerVisibility", "pk_pill_pvs", function(ply)
        if IsValid(getMappedEnt(ply)) and getMappedEnt(ply).formTable.type == "phys" then
            AddOriginToPVS(getMappedEnt(ply):GetPos())
        end
    end)

    hook.Add("PlayerDeathThink", "pk_pill_nospawn", function(ply)
        if getMappedEnt(ply) then return false end
    end)
	
	hook.Add("HandlePlayerJumping", "pk_pill_canjump", function(ply)
        local ent = getMappedEnt(ply)
		if ent.animFreeze then
			return true
		end
	end)

    hook.Add("DoAnimationEvent", "pk_pill_triggerAnims", function(ply, event, data)
        local ent = getMappedEnt(ply)
        if IsValid(ent) and ent.formTable.type == "ply" then
            if event == PLAYERANIMEVENT_JUMP and !ent.animFreeze and ent.formTable.jumpPower > 0 then
                ent:PillAnim("jump")
                ent:DoJump()
            end

            if event == PLAYERANIMEVENT_ATTACK_PRIMARY then
                ent:PillGesture("attack")
            end

            if event == PLAYERANIMEVENT_ATTACK_SECONDARY then
                ent:PillGesture("attack2")
            end

            if event == PLAYERANIMEVENT_RELOAD then
               ent:PillGesture("reload")
            end
        end
    end)

    hook.Add("OnPlayerHitGround", "pk_pill_hitground", function(ply, iW, oF, speed)
        local ent = getMappedEnt(ply)

        if IsValid(ent) then
            if ent.formTable.land and !ply:IsFlagSet(FL_FROZEN) then
                ent.formTable.land(ply, ent)
                ent:PillSound("land", false)
            end

            if ent.formTable.noFallDamage or ent.formTable.type == "phys" then return true end
        end
    end)

    hook.Add("DoPlayerDeath", "pk_pill_death", function(ply)
        if IsValid(getMappedEnt(ply)) then
            if SERVER then
				ply:SuppressRagdollSpawn()
                getMappedEnt(ply):PillDie()
            end
        end
    end)
	
    hook.Add("PlayerCanPickupWeapon", "pk_pill_pickupWeapon", function(ply, wep)
        if IsValid(getMappedEnt(ply)) then
            if getMappedEnt(ply).formTable.type == "ply" then
                if (getMappedEnt(ply).formTable.validHoldTypes and table.HasValue(getMappedEnt(ply).formTable.validHoldTypes, wep:GetHoldType())) or string.StartWith(wep:GetClass(), "v_") then return true end

                return false
            else
                return false
            end
        end
    end)

    hook.Add("PlayerSpawn", "pk_pill_force_on_spawn", function(ply)
		local ent = pills.getMappedEnt(ply)
		if IsValid(ent) then
			ent:ResetSpeed(ply)
		end
    end)
	hook.Add( "PlayerUse", "pk_pill_block_use", function( ply, ent )
        local pup = getMappedEnt(ply)

		if IsValid(pup) then
			if pup.cloaked then
				return false
			end
		end
	end )
    --For compatibility with player resizer and God knows what else
	hook.Add("SetPlayerSpeed", "pk_pill_speed_enforcer", function(ply,walk,run)
		if IsValid(getMappedEnt(ply)) then
			return false
		end
	end)

    hook.Add( "PlayerShouldTaunt", "fh_allow_taunt", function( ply, act )
        local ent = getMappedEnt(ply)
		if IsValid(getMappedEnt(ply)) then
            if ent.formTable.taunt and !ply:IsFlagSet(FL_FROZEN) and !ent:GetFrozen() then
                ent.formTable.taunt(ply, ent, act)
            end
            return false
        end
    end )
else -- CLIENT HOOKS
	-- чтобы скачанные базы пилл паков не конфликтовали
    hook.Remove("HUDPaint", "pk_pill_hud")

    -- IGNORE THIS NONSENSE: Just use the default HUD from now on
    hook.Add("HUDShouldDraw", "pk_pill_hideHud", function(name)
        if (getMappedEnt(LocalPlayer()) and (name == "CHudHealth" or name == "CHudBattery")) then return false end
    end)
end

-- Shared hooks
hook.Add("SetupMove", "pk_pill_movemod", function(ply, mv, cmd)
    local ent = getMappedEnt(ply)

    if IsValid(ent) then
        if ent.formTable.moveMod then
            ent.formTable.moveMod(ply, ent, mv, cmd)
        end

        if ent.GetChargeTime and ent:GetChargeTime() ~= 0 then
            local charge = ent.formTable.charge
            --check if we should continue
            local vel = mv:GetVelocity()

            if ent:GetChargeTime() + .1 < CurTime() and vel:Length() < charge.vel * .8 then
                ent:SetChargeTime(0)
                ent:PillLoopStop("charge")
            else
                local angs = ent:GetChargeAngs()
                ply:SetEyeAngles(angs)
                mv:SetVelocity(angs:Forward() * charge.vel)
            end
        end
    end
end)

hook.Add("PlayerFootstep", "pk_pill_step", function(ply, pos, foot, snd, vol, filter)
    local ent = getMappedEnt(ply)

    if IsValid(ent) then
        if ent.formTable.type == "phys" or ent.formTable.muteSteps or ent.animFreeze then
            return true
        else
            return ent:PillSound("step", pos)
        end
    end
end)

hook.Add( "StartCommand", "pk_froze_movement", function( ply, cmd )
    local ent = getMappedEnt(ply)

	if IsValid(ent) then
		if ent:GetFrozen() then
			cmd:ClearMovement()
			cmd:RemoveKey(IN_ATTACK)
			cmd:RemoveKey(IN_ATTACK2)
		end
	end
end )

include("ppp_includes/util.lua")
include("ppp_includes/nocompat.lua")
include("ppp_includes/console.lua")
-- DONE!
print("PILL CORE LOADED")
