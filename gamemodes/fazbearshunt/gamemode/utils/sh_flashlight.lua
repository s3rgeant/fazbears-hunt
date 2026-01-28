hook.Add("PlayerSwitchFlashlight", "fh_toggle_flashlights", function(ply, enabled)
	--local state = not ply:GetNW2Bool("FH_Flashlight", false)
	--ply:SetNW2Bool("FH_Flashlight", state)
	
	return false
end)

--[[
if CLIENT then
	local Flashlights = Flashlights or {}
	local myself

	hook.Add("Think", "fh_fp_flashlight", function()
		myself = myself or LocalPlayer()
		if not IsValid(myself) then return end

		local enabled = myself:GetNW2Bool("FH_Flashlight", false)
		
		local isFirstPerson = myself:ShouldDrawLocalPlayer() == false

		if enabled and isFirstPerson then
			if not Flashlights[myself] then
				local fl = ProjectedTexture()
				fl:SetTexture("effects/flashlight001")
				fl:SetFOV(70)
				fl:SetFarZ(900)
				fl:SetNearZ(8)
				fl:SetBrightness(2)
				fl:SetEnableShadows(false)
				Flashlights[myself] = fl
			end

			local fl = Flashlights[myself]
			fl:SetPos(myself:EyePos())
			fl:SetAngles(myself:EyeAngles())
			fl:Update()
		else
			if Flashlights[myself] then
				Flashlights[myself]:Remove()
				Flashlights[myself] = nil
			end
		end
	end)

	local coneMat   = Material("effects/vol_light001")
	local lampMat   = Material("sprites/light_ignorez")

	hook.Add("PostPlayerDraw", "FH_ThirdPersonFlashlight_SoftCone", function(ply)
		if ply == LocalPlayer() and not ply:ShouldDrawLocalPlayer() then return end
		if not ply:GetNW2Bool("FH_Flashlight", false) then return end

		local attID = ply:LookupAttachment("anim_attachment_RH")
		if attID <= 0 then return end

		local att = ply:GetAttachment(attID)
		if not att then return end

		local startPos = att.Pos + att.Ang:Forward() * 3
		local dir      = att.Ang:Forward()
		local right    = att.Ang:Right()
		local up       = att.Ang:Up()

		local length   = 750
		local widthEnd = 120
		local widthBeg = 12

		-- Конец света (НЕ рисуем точку!)
		local endPos = startPos + dir * length

		-- ==========
		-- МЯГКИЙ QUAD
		-- ==========
		render.SetMaterial(coneMat)

		local a = Color(255,255,255,35)

		render.DrawQuad(
			startPos + right * widthBeg + up * widthBeg,
			startPos - right * widthBeg + up * widthBeg,
			endPos   - right * widthEnd,
			endPos   + right * widthEnd,
			a
		)

		-- ==========
		-- ЛАМПА У РУКИ
		-- ==========
		render.SetMaterial(lampMat)
		render.DrawSprite(
			startPos,
			14,
			14,
			Color(255,255,255,220)
		)
	end)
	
	hook.Add("EntityRemoved", "fh_flashlight_cleanup", function(ent)
		if Flashlights[ent] then
			Flashlights[ent]:Remove()
			Flashlights[ent] = nil
		end
	end)
end
]]--