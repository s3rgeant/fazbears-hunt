AddCSLuaFile()
-- Module starts here...
module("pk_pills", package.seeall)
-- Load files
file.CreateDir("pill_config")
local locked_perma = {}
local locked_game = {}

for k, v in pairs(util.KeyValuesToTable(file.Read("pill_config/permalocked.txt") or "")) do
    locked_perma[string.upper(k)] = v
end

-- Pack Registration
local packString = ""
local packs = {}
local currentPack

TEAM_PILLS = 2701

if SERVER then
	team.SetUp(TEAM_PILLS, 'PILLS', Color(255, 0, 0))
end

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

local function fixParent(name)
    local t = forms[name]
    if t.parent == name then return end
    local t_parent = forms[t.parent]

    if t_parent.parent then
        fixParent(t.parent)
    end

    t_parent = forms[t.parent]

    if t_parent then
        t_parent = table.Copy(t_parent)
        forms[name] = table.Merge(t_parent, t)
        t.parent = nil
    else
        print("Tried to inherit pill from non-existant '" .. t.parent .. "'. Make sure you register the parent first.")
    end
end

function getPillTable(typ)
    return forms[typ]
end

function getFormCount()
    return table.Count(forms)
end

function getRandomForm()
    local v, k = table.Random(forms)

    return k
end

hook.Add("Initialize", "pk_pill_finalize", function()
    for n, t in pairs(forms) do
        if t.parent then
            fixParent(n)
        end
    end
end)

-- Player to Pill Entity Mapping
function mapEnt(ply, ent)
    ply.pk_pill_ent = ent
end

function unmapEnt(ply, ent)
    if ply.pk_pill_ent == ent then
        ply.pk_pill_ent = nil
    elseif IsValid(ply.pk_pill_ent) then
        return ply.pk_pill_ent.formTable.type
    end
end

function getMappedEnt(ply)
    return ply.pk_pill_ent
end

-- Concommands, Convars, etc.
if SERVER then
    concommand.Add("pk_pill_apply", function(ply, cmd, args, str)
		if IsValid(ply) and !ply:IsAdmin() then return end
        apply(args[1], args[2], "user", tonumber(args[3]))
    end)

    concommand.Add("pk_pill_restore", function(ply, cmd, args, str)
		if IsValid(ply) and !ply:IsAdmin() then return end
        restore(args[1])
    end)

    concommand.Add("pk_pill_restore_force", function(ply, cmd, args, str)
		if IsValid(ply) and !ply:IsAdmin() then return end
        restore(ply, true)
    end)

    concommand.Add("pk_pill_spawnent", function(ply, cmd, args, str)
		if IsValid(ply) and !ply:IsAdmin() then return end
        local tr = ply:GetEyeTrace()
        local e = ents.Create("pill_worldent")
        e:SetPos(tr.HitPos + tr.HitNormal * 5)
        e:SetPillForm(args[1])
        e:Spawn()
    end)

    concommand.Add("pk_pill_morphgun_select", function(ply, cmd, args, str)
		if IsValid(ply) and !ply:IsAdmin() then return end
        local pill = args[1]
        local wep = ply:GetWeapon("pill_wep_morphgun")

        if not IsValid(wep) then
            wep = ply:Give("pill_wep_morphgun")
        end

        if not IsValid(wep) then return end
        ply:SelectWeapon("pill_wep_morphgun")
        wep:SetForm(pill)
    end)
end

-- NW Strings
if SERVER then
    util.AddNetworkString("pk_pill_filtercam")
    util.AddNetworkString("pk_pill_morphsound")
    --util.AddNetworkString("pk_pill_init_darkrp")
else
    net.Receive("pk_pill_filtercam", function(len, pl)
        local pill = net.ReadEntity()
        local filtered = net.ReadEntity()

        if IsValid(pill) and IsValid(filtered) then
            table.insert(pill.camTraceFilter, filtered)
        end
    end)

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
		lock-life - force until death
		lock-map - force until map restart
		lock-perma - force forever
	]]
    function apply(ply, name, mode, option)
        if CLIENT then return end
		
		local found = false
		for _, plyr in ipairs(player.GetAll()) do
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

        local locked
        local overridePos
        local overrideAng

        --restriction logic
        if mode == "user" then
            local success = true

            if not t.printName then
                ply:ChatPrint("You cannot use this pill directly.")
                success = false
            end

            if IsValid(old) and old.locked then
                if locked_perma[ply:SteamID()] then
                    ply:ChatPrint("You are locked in your current pill -- FOREVER!")
                elseif locked_game[ply:SteamID()] then
                    ply:ChatPrint("You are locked in your current pill until the map changes.")
                else
                    ply:ChatPrint("You are locked in your current pill until you die.")
                end

                success = false
            end

            if t.type == "phys" and t.userSpawn then
                local tr

                if IsValid(old) and old.formTable.type == "phys" then
                    tr = util.QuickTrace(old:GetPos(), ply:EyeAngles():Forward() * 99999, old)
                else
                    tr = ply:GetEyeTrace()
                end

                if t.userSpawn.type == "ceiling" then
                    if tr.HitNormal.z < -.8 and not tr.HitSky then
                        overridePos = tr.HitPos + tr.HitNormal * (t.userSpawn.offset or 0)
                    else
                        success = false
                        ply:ChatPrint("You need to be looking at a ceiling to use this pill.")
                    end
                elseif t.userSpawn.type == "wall" then
                    if not tr.HitSky then
                        overridePos = tr.HitPos + tr.HitNormal * (t.userSpawn.offset or 0)
                        overrideAng = tr.HitNormal:Angle()

                        if t.userSpawn.ang then
                            overrideAng = overrideAng + t.userSpawn.ang
                        end
                    else
                        success = false
                        ply:ChatPrint("You need to be looking at a wall to use this pill.")
                    end
                end
            end

            net.Start("pk_pill_morphsound")
            net.WriteBit(success)
            net.Send(ply)
            if not success then return end
        elseif mode ~= nil then
            --anything that can change locks
            if mode == "lock-map" then
                locked_game[ply:SteamID()] = name
            else
                locked_game[ply:SteamID()] = nil
            end

            if mode == "lock-perma" then
                locked_perma[ply:SteamID()] = name
            else
                locked_perma[ply:SteamID()] = nil
            end

            file.Write("pill_config/permalocked.txt", util.TableToKeyValues(locked_perma, "permalocked"))

            if mode ~= "force" then
                locked = true
            end
        end

        local e

		if t.type == "ply" then
            e = ents.Create("pill_ent_costume")

            if old and old.formTable.type == "phys" then
                local angs = ply:EyeAngles()
                ply:Spawn()
                ply:SetEyeAngles(angs)
                ply:SetPos(old:GetPos())
            end
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

		timer.Simple(0.01, function()
			e:SetPillForm(name)
			e:SetPillUser(ply)
			e.locked = locked
			e.option = option
			e:Spawn()
			e:Activate()
			
			ply:SetTeam(TEAM_PILLS)
			
			hook.Run("PillApply", ply, name)
	
			--if mode=="user" then
			if t.type == "phys" then
				--ply:SetLocalVelocity(oldvel)
				--else
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
		
		end)
    end

    local driveModes = {}

    function getDrive(typ)
        return driveModes[typ]
    end

    function registerDrive(name, t)
        driveModes[name] = t
    end
end

--set breakout to true to break out of any locks
--returns true if the player was using a pill
--shared because it goes in the noclip function, I guess
function restore(ply, breakout)
		
	local found = false
	for _, plyr in ipairs(player.GetAll()) do
		if plyr:Nick() == ply then
			ply = plyr
			found = true
			break
		end
	end
	if not found then return end
		
    local ent = getMappedEnt(ply)

    if IsValid(ent) then
        if SERVER then
            if ent.locked and not breakout then
                if locked_perma[ply:SteamID()] then
                    ply:ChatPrint("You are locked in your current pill -- FOREVER!")
                elseif locked_game[ply:SteamID()] then
                    ply:ChatPrint("You are locked in your current pill until the map changes.")
                else
                    ply:ChatPrint("You are locked in your current pill until you die.")
                end
            else
                ent.notDead = true
                ent:Remove()
            end

            if not breakout then
                net.Start("pk_pill_morphsound")
                net.WriteBit(ent.notDead)
                net.Send(ply)
            else
                locked_game[ply:SteamID()] = nil
                locked_perma[ply:SteamID()] = nil
                file.Write("pill_config/permalocked.txt", util.TableToKeyValues(locked_perma, "permalocked"))
            end
        end
		
		ply:SetTeam(TEAM_UNASSIGNED)

        return true
    end
end

-- THEM HOOKS
if SERVER then
    hook.Add("KeyPress", "pk_pill_keypress", function(ply, key)
        local ent = getMappedEnt(ply)

        if IsValid(ent) then
            ent:DoKeyPress(ply, key)
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
            if ent.formTable.land and (!ply.lobbyFreeze or ply.lobbyFreeze == nil) then
                ent.formTable.land(ply, ent)
                ent:PillSound("land", false)
            end

            if ent.formTable.noFallDamage or ent.formTable.type == "phys" then return true end
        end
    end)

    hook.Add("DoPlayerDeath", "pk_pill_death", function(ply)
        if IsValid(getMappedEnt(ply)) then
            if SERVER then
                getMappedEnt(ply):PillDie()
				ply:SetTeam(TEAM_UNASSIGNED)
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
        local forcedType = locked_perma[ply:SteamID()] or locked_game[ply:SteamID()]

        if forcedType then
            local e = apply(ply, forcedType)

            if IsValid(e) then
                e.locked = true
            end

            return
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

--	hook.Add("PlayerStepSoundTime", "pk_pill_step_time", function(ply,type,walking)
--		local ent = playerMap[ply]
--		if IsValid(ent) then
--			//if ent.formTable.stepSize then
--				
--			//end
--			return 100
--		end
--	end)
else -- CLIENT HOOKS
    hook.Add("HUDPaint", "pk_pill_hud", function()
        if pk_pills.convars.cl_hidehud:GetBool() then return end
        local ent = getMappedEnt(LocalPlayer())

        if IsValid(ent) and GetConVar("cl_drawhud"):GetBool() then
            if (ent.formTable.health) and !ent.formTable.hideHud then
                local hpMax = ent.formTable.health
                local hpCurrent = ent:GetPillHealth()
                surface.SetDrawColor(Color(0, 0, 0))
                surface.DrawRect(40, ScrH() - 80, 300, 40)

                if not ent.formTable.onlyTakesExplosiveDamage then
                    surface.SetDrawColor(Color(255, 60, 40))
                    surface.DrawRect(42, ScrH() - 78, 296 * math.min(hpCurrent / hpMax, 1), 36)
                    draw.SimpleText("Health: " .. math.Round(hpCurrent) .. "/" .. hpMax, "ChatFont", 190, ScrH() - 52, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
                else
                    surface.SetDrawColor(Color(255, 100, 40))
                    surface.DrawRect(42, ScrH() - 78, 296 * math.min(hpCurrent / hpMax, 1), 36)
                    draw.SimpleText("Hits Left: " .. math.Round(hpCurrent) .. "/" .. hpMax, "ChatFont", 190, ScrH() - 52, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
                end
            end

            if ent.formTable.cloak and ent.formTable.cloak.max ~= -1 then
                surface.SetDrawColor(Color(0, 0, 0))
                surface.DrawRect(ScrW() - 370, ScrH() - 110, 300, 30)
                surface.SetDrawColor(Color(130, 130, 255))
                surface.DrawRect(ScrW() - 368, ScrH() - 108, 296 * math.min(ent:GetCloakLeft() / ent.formTable.cloak.max, 1), 26)
                draw.SimpleText("Cloak: " .. string.format("%.3f", ent:GetCloakLeft()) .. " Seconds", "ChatFont", ScrW() - 200, ScrH() - 86, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
            end

			--[[
            if ent.formTable.aim and (not ent.formTable.aim.usesSecondaryEnt or IsValid(ent:GetPillAimEnt())) and not ent.formTable.aim.nocrosshair then
                local aimEnt = (ent.GetPillAimEnt and IsValid(ent:GetPillAimEnt()) and ent:GetPillAimEnt()) or ent
                local attachment

                if ent.formTable.aim.attachment then
                    attachment = aimEnt:GetAttachment(aimEnt:LookupAttachment(ent.formTable.aim.attachment))
                end

                local dir

                if ent.formTable.aim.simple or not attachment then
                    dir = LocalPlayer():EyeAngles():Forward()
                else
                    dir = attachment.Ang:Forward()
                end

                local start = ent.formTable.aim.overrideStart and ent:LocalToWorld(ent.formTable.aim.overrideStart) or (attachment and attachment.Pos) or (ent.formTable.type == "ply" and LocalPlayer():GetShootPos() or ent:GetPos())
                local tr = util.QuickTrace(start, dir * 99999, {aimEnt, LocalPlayer()})
                local screenPos = tr.HitPos:ToScreen()
                local chColor = Color(160, 220, 50)

                if IsValid(tr.Entity) and (tr.Entity:IsPlayer() or tr.Entity:IsNPC() or tr.Entity:GetClass() == "pill_ent_phys") then
                    chColor = Color(255, 0, 0)
                end

                if screenPos.visible then
                    draw.TexturedQuad({
                        texture = surface.GetTextureID("sprites/hud/v_crosshair1"),
                        color = chColor,
                        x = screenPos.x - 20,
                        y = screenPos.y - 20,
                        w = 40,
                        h = 40
                    })
                end
            end
			]]--
        end

        -- nametags
        if IsValid(LocalPlayer()) then
            local trent = LocalPlayer():GetEyeTraceNoCursor().Entity

            if (IsValid(trent) and trent:GetClass() == "pill_ent_phys") then
                local pillowner = trent:GetPillUser()

                if IsValid(pillowner) and pillowner ~= LocalPlayer() then
                    draw.SimpleText(pillowner:GetName(), "ChatFont", ScrW() / 2, ScrH() / 2, team.GetColor(pillowner:Team()), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                    if trent:GetPillHealth() > 0 then
                        draw.SimpleText(trent:GetPillHealth() .. " HP", "ChatFont", ScrW() / 2, ScrH() / 2 + 20, team.GetColor(pillowner:Team()), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                end
            end
        end
    end)

    -- IGNORE THIS NONSENSE: Just use the default HUD from now on
    hook.Add("HUDShouldDraw", "pk_pill_hideHud", function(name)
        if (getMappedEnt(LocalPlayer()) and name == "CHudHealth") then return false end
    end)
    --[[
	--Causes issues with other players being drawn over their puppets
	hook.Add("ShouldDrawLocalPlayer","pk_pill_thirdperson",function() //only really used for viewmodel... betr ways?
		if getMappedEnt(LocalPlayer()) then
			return true
		end
	end)
	hook.Add("CalcViewModelView","pk_pill_thirdperson",function(wep,mdl,oldpos,oldang,pos,ang)
		if playerMap[LocalPlayer()] && var_thirdperson:GetBool() then
			return pos-Vector(0,0,100),ang
		end
	end)]]
end

-- Shared hooks
hook.Add("PhysgunPickup", "pk_pill_nograb", function(ply, ent)
    if ent:GetClass() == "pill_ent_phys" then
        if ply:IsAdmin() then
            return true
        else
            return false
        end
    end
end)

hook.Add("SetupMove", "pk_pill_movemod", function(ply, mv, cmd)
    local ent = getMappedEnt(ply)

    if IsValid(ent) then
        if ent.formTable.moveMod then
            ent.formTable.moveMod(ply, ent, mv, cmd)
        end
		
		if ent.formTable.moveFunction then
			ent.formTable.moveFunction(ply, ent, mv)
		end

        if ent.GetChargeTime and ent:GetChargeTime() ~= 0 then
            local charge = ent.formTable.charge
            --check if we should continue
            local vel = mv:GetVelocity()

            if ent:GetChargeTime() + .1 < CurTime() and vel:Length() < charge.vel * .8 then
                print("uncharge")
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

include("ppp_includes/util.lua")
include("ppp_includes/nocompat.lua")
include("ppp_includes/console.lua")
-- DONE!
print("PILL CORE LOADED")
