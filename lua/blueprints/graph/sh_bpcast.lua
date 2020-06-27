AddCSLuaFile()

module("bpcast", package.seeall, bpcommon.rescope(bpschema))

NodePinImplicitCasts = {}

function AddPinCast(from, to, bidirectional, wrapper, ignoreSub)

	local castInfo = nil
	for _, info in ipairs(NodePinImplicitCasts) do
		if info.from == from then castInfo = info break end
	end
	if castInfo == nil then castInfo = NodePinImplicitCasts[table.insert(NodePinImplicitCasts, { from = from, to = {} })] end

	local function Add( type )
		castInfo.to[#castInfo.to+1] = {
			type = type,
			bidir = bidirectional,
			wrapper = wrapper,
			ignoreSub = ignoreSub,
		}
	end

	if type(to) == "table" and not IsPinType(to) then
		for _, v in ipairs(to) do Add(v) end
	elseif IsPinType(to) then
		Add(to)
	end

end

AddPinCast(bppintype.New(PN_Exec, PNF_Server), { bppintype.New(PN_Exec) })
AddPinCast(bppintype.New(PN_Exec, PNF_Client), { bppintype.New(PN_Exec) })
AddPinCast(bppintype.New(PN_Number), { bppintype.New(PN_Enum) }, true, nil, true )
AddPinCast(bppintype.New(PN_Number), { bppintype.New(PN_String) } )
AddPinCast(bppintype.New(PN_Ref, PNF_None, "Entity"), { 
	bppintype.New(PN_Ref, PNF_None, "Player"),
	bppintype.New(PN_Ref, PNF_None, "Weapon"),
	bppintype.New(PN_Ref, PNF_None, "NPC"),
	bppintype.New(PN_Ref, PNF_None, "Vehicle"),
}, true)
AddPinCast(bppintype.New(PN_String), { bppintype.New(PN_Asset) }, true, nil, true )

--[[
AddPinCast(bppintype.New(PN_Vector), bppintype.New(PN_String), false, "tostring(@)")
AddPinCast(bppintype.New(PN_Bool), bppintype.New(PN_String), false, "tostring(@)")
AddPinCast(bppintype.New(PN_Ref, PNF_None, "Entity"), bppintype.New(PN_String), false, "tostring(@)")
AddPinCast(bppintype.New(PN_Ref, PNF_None, "Weapon"), bppintype.New(PN_String), false, "tostring(@)")
AddPinCast(bppintype.New(PN_Ref, PNF_None, "NPC"), bppintype.New(PN_String), false, "tostring(@)")
AddPinCast(bppintype.New(PN_Ref, PNF_None, "Vehicle"), bppintype.New(PN_String), false, "tostring(@)")
]]

local castMatchFlags = PNF_Table + PNF_Server + PNF_Client
function CanCast(outPinType, inPinType)

	for _, castInfo in ipairs(NodePinImplicitCasts) do
		if castInfo.from:Equal( outPinType, castMatchFlags ) then
			for _, entry in ipairs(castInfo.to) do
				if entry.type:Equal( inPinType, castMatchFlags, entry.ignoreSub ) then
					return true, entry.wrapper
				end
			end
		elseif castInfo.from:Equal( inPinType, castMatchFlags ) then
			for _, entry in ipairs(castInfo.to) do
				if entry.bidir and entry.type:Equal( outPinType, castMatchFlags, entry.ignoreSub ) then
					return true, entry.wrapper
				end
			end
		end
	end

	return outPinType:CanCastTo( inPinType )

end

local function GetNodeTypePins(ntype, module)

	local nodeClass = ntype:GetNodeClass()
	if nodeClass == nil then return ntype:GetPins() end

	local cl = bpnode.nodeClasses:Get(nodeClass)
	if cl and cl.GeneratePins ~= bpnode_meta.GeneratePins then
		local node = bpnode.New(ntype):WithOuter( module )
		node:Initialize(true)
		return node:GetPins()
	end

	return ntype:GetPins()

end

function FindMatchingPin(ntype, pf, module, cache)

	assert(module ~= nil)

	local nodePinCache = nil
	if cache then
		cache.__nodePins = cache.__nodePins or {}
		nodePinCache = cache.__nodePins
	end

	local pins = nil
	local informs = ntype:GetInforms()
	local ignoreNullable = bit.band( PNF_All, bit.bnot( PNF_Nullable ) )

	if nodePinCache and nodePinCache[ntype] then
		pins = nodePinCache[ntype]
	else
		pins = GetNodeTypePins(ntype, module)
		if nodePinCache then nodePinCache[ntype] = pins end
	end


	if cache and cache[ntype] ~= nil then
		local id = cache[ntype]
		if id == -1 then return end
		return id, pins[id]
	end

	local inType = nil
	local outType = nil
	local fdir = pf:GetDir()

	if fdir == PD_In then inType = pf:GetType() end
	if fdir == PD_Out then outType = pf:GetType() end

	for id, pin in ipairs(pins) do

		if pin:GetDir() ~= fdir then

			if fdir == PD_In then outType = pin:GetType() else inType = pin:GetType() end

			local sameType = inType:Equal(outType, PNF_Server + PNF_Client)
			local sameFlags = inType:GetFlags(ignoreNullable) == outType:GetFlags(ignoreNullable)
			local tableMatch = informs ~= nil and #informs > 0 and pin:HasFlag(PNF_Table) and pf:HasFlag(PNF_Table) and pin:IsType(PN_Any)
			local anyMatch = informs ~= nil and #informs > 0 and not pin:HasFlag(PNF_Table) and not pf:HasFlag(PNF_Table) and pin:GetBaseType() ~= PN_Exec
			local typeFlagTableMatch = ((sameType and sameFlags) or tableMatch or anyMatch)
			local castMatch = sameType
			if not castMatch then

				if cache then
					local outH = outType:GetHash()
					local inH = inType:GetHash()
					cache[outH] = cache[outH] or {}
					if cache[outH][inH] ~= nil then 
						castMatch = cache[outH][inH]
					else
						castMatch = CanCast(outType, inType)
						cache[outH][inH] = castMatch
					end
				else
					castMatch = CanCast(outType, inType)
				end

			end

			if (ntype:GetFullName() == "CORE_Pin" or typeFlagTableMatch or castMatch) then
				if cache then cache[ntype] = id end
				return id, pin
			end

		end

	end

	if cache then cache[ntype] = -1 end

end