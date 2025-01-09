AddCSLuaFile()
-- Convars
pk_pills.convars = {}
-- Admin vars

-- Client vars
if CLIENT then
    pk_pills.convars.cl_thirdperson = CreateClientConVar("fh_thirdperson", 0)
    pk_pills.convars.cl_hidehud = CreateClientConVar("pk_pill_cl_hidehud", 0)
end
