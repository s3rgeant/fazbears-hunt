function RecursiveSetPreventTransmit( ent, ply, stopTransmitting )
	if IsValid( ent ) then
		ent:SetPreventTransmit( ply, stopTransmitting )
		local tab = ent:GetChildren()
		for i = 1, #tab do
			RecursiveSetPreventTransmit( tab[ i ], ply, stopTransmitting )
		end
	end
end