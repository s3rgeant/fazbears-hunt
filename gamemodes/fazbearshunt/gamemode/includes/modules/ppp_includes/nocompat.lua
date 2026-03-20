-- Does what compat.lua used to without being so aggressive about compatability.
-- If another addon wants to break things, IT CAN!
AddCSLuaFile()

-- Them hooks
hook.Add("CalcView", "momo_calcview", function(ply, pos, ang, fov, nearZ, farZ)
	local myself = LocalPlayer()
    local ent = pills.getMappedEnt(myself)

    if IsValid(ent) and ply:GetViewEntity() == ply then
        local startpos

        if ent.formTable.type == "phys" then
            startpos = ent:LocalToWorld(ent.formTable.camera and ent.formTable.camera.offset or Vector(0, 0, 0))
        else
            startpos = pos
        end

        if pills.convars.cl_thirdperson:GetBool() or CurTime() < myself:GetNW2Float("fh_pill_thirdperson") then
            local dist
			
			if hook.Run("HandlePillThirdperson", ply, ent) == false then return end

            if ent.formTable.type == "phys" and ent.formTable.camera and ent.formTable.camera.distFromSize then
                dist = ent:BoundingRadius() * 5
            else
                dist = ent.formTable.camera and ent.formTable.camera.dist or 100
            end

            local underslung = ent.formTable.camera and ent.formTable.camera.underslung
            local offset = LocalToWorld(Vector(-dist, 0, underslung and -dist / 5 or dist / 5), Angle(0, 0, 0), Vector(0, 0, 0), ang)

            local tr = util.TraceHull({
                start = startpos,
                endpos = startpos + offset,
                filter = ent.camTraceFilter,
                mins = Vector(-5, -5, -5),
                maxs = Vector(5, 5, 5),
                mask = MASK_VISIBLE
            })

            local view = {}
            view.origin = tr.HitPos
            view.angles = ang
            view.fov = fov
            view.drawviewer = true
            --[[else
            local view = {}
            view.origin = startpos
            view.angles = ang
            view.fov = fov
            return view]]

            return view
        end
    end
end)
