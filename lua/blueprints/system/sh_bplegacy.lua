AddCSLuaFile()

module("bplegacy", package.seeall)

function ConvertModule16( moduleFile )

	local old = bpcompat.COMPAT_ENV.bpmodule.New()
	--old:Load("blueprints/client/bpm_" .. a[1] .. ".txt")
	old:Load(moduleFile)

	local new = bpmodule.New(old:GetType())
	local graphMap = {}
	local graphIDMapOld = {}
	local graphIDMapNew = {}
	local nodeMap = {}
	local nodeIDMap = {}
	local varIDMap = {}
	local graphCallMap = {}

	local function ConvertPinType( base, addFlags )
		return bppintype.New( 
			base:GetBaseType(), 
			bit.bor(base:GetFlags(), addFlags or 0), 
			base:GetSubType() 
		)
	end

	if old:CanHaveStructs() then

		for k, oldStruct in old:Structs() do
			local id, newStruct = new.structs:ConstructNamed(oldStruct:GetName())
			newStruct:PreModify()

			for id, pin in oldStruct.pins:Items() do

				local pt = bppintype.New( pin:GetBaseType(), pin:GetFlags(), pin:GetSubType() )
				newStruct.pins:Construct( pin:GetDir(), pin:GetName(), pt, pin:GetDescription() )

			end

			newStruct.nameMap = oldStruct.nameMap
			newStruct.invNameMap = oldStruct.invNameMap

			newStruct:PostModify()

		end

	end

	local newPinTypes = bpcollection.New()
	new:GetPinTypes(newPinTypes)

	if old:CanHaveVariables() then

		for k, var in old:Variables() do

			local existingType = nil
			if var:GetType():GetBaseType() == bpschema.PN_Struct then
				for _, x in newPinTypes:Items() do
					if x:GetSubType() == var:GetType():GetSubType() then
						existingType = x
						break
					end
				end
			end

			local addFlags = 0
			if existingType then addFlags = existingType:GetFlags() end
			local newType = ConvertPinType( var:GetType(), addFlags )
			local id, newVar = new:NewVariable( var:GetName(), newType )
			varIDMap[k] = id
			--print("VAR: " .. var:GetName() .. " " .. k .. " -> " .. id)
		end

	end

	if old:CanHaveEvents() then

		for k, oldEvent in old:Events() do
			local id, newEvent = new.events:ConstructNamed(oldEvent:GetName())
			newEvent.flags = oldEvent.flags
			newEvent:PreModify()

			for id, pin in oldEvent.pins:Items() do

				local pt = bppintype.New( pin:GetBaseType(), pin:GetFlags(), pin:GetSubType() )
				newEvent.pins:Construct( pin:GetDir(), pin:GetName(), pt, pin:GetDescription() )

			end

			newEvent:PostModify()

		end

	end

	for k, oldGraph in old:Graphs() do
		print(oldGraph:GetTitle())

		local id, newGraph = new:NewGraph( oldGraph:GetTitle(), oldGraph:GetType() )
		newGraph:SetFlags( oldGraph:GetFlags() )
		graphIDMapNew[newGraph] = id
		graphIDMapNew[id] = newGraph

		graphMap[oldGraph] = newGraph
		graphIDMapOld[oldGraph] = k
		graphIDMapOld[k] = oldGraph

		for k, input in oldGraph:Inputs() do
			local pt = bppintype.New( input:GetBaseType(), input:GetFlags(), input:GetSubType() )
			newGraph.inputs:Construct( input:GetDir(), input:GetName(), pt, input:GetDescription() )
		end

		for k, output in oldGraph:Outputs() do
			local pt = bppintype.New( output:GetBaseType(), output:GetFlags(), output:GetSubType() )
			newGraph.outputs:Construct( output:GetDir(), output:GetName(), pt, output:GetDescription() )
		end

		if newGraph:GetType() == bpschema.GT_Function then
			local newEntry = newGraph:GetEntryNode()
			local newExit = newGraph:GetExitNode()

			newGraph:RemoveNode(newEntry)
			newGraph:RemoveNode(newExit)
		end
	end

	local nodeTypes = bpcollection.New()
	old:GetNodeTypes(nodeTypes, nil)

	for id, type in nodeTypes:Items() do

		local _,_,id = type:GetName():find("__Call(%d+)")
		if id then
			id = tonumber(id)
			local oldGraphTarget = graphIDMapOld[id]
			if not oldGraphTarget then
				error("Failed to remap old graph to new graph")
			end

			local newTarget = graphMap[oldGraphTarget]
			local newID = graphIDMapNew[newTarget]

			print("REMAP GRAPH CALL ID: " .. id .. " -> " .. newID)

			for k, oldGraph in old:Graphs() do
				for _, node in oldGraph:Nodes() do
					if node:GetTypeName() == type:GetName() then
						node.nodeType = "__Call" .. newID
					end
				end
			end
		end

		local _,_,mode,id = type:GetName():find("__V(%a+)(%d+)")
		if mode and id then
			id = tonumber(id)
			local newID = varIDMap[id]

			print("REMAP GRAPH " .. mode .. " ID: " .. id .. " -> " .. newID)

			for k, oldGraph in old:Graphs() do
				for _, node in oldGraph:Nodes() do
					if node:GetTypeName() == type:GetName() then
						node.nodeType = "__V" .. mode .. newID
					end
				end
			end
		end

	end

	for oldGraph, newGraph in pairs(graphMap) do

		local nodeTypes = newGraph:GetNodeTypes()
		for k, oldNode in oldGraph:Nodes() do

			local type = oldNode:GetTypeName()
			local _, newNode = newGraph:AddNode( type, oldNode.x, oldNode.y )
			if newNode == nil then
				print("FAILED TO CREATE NODE: " .. tostring(type))
				continue
			end

			newNode:PreModify()
			for x,y in pairs(oldNode.data) do
				newNode.data[x] = y
			end
			newNode:PostModify()

			nodeMap[oldNode] = newNode
			nodeIDMap[k] = newNode

			for id, oldPin, pos in oldNode:Pins(function(x) return x:GetDir() == bpschema.PD_In end) do
				local newPin = newNode:FindPin(bpschema.PD_In, oldPin:GetName())
				if newPin then
					newPin:SetLiteral( oldNode:GetLiteral(id) )
				end
			end

		end

		for k, oldNode in oldGraph:Nodes() do

			for id, pin, pos in oldNode:Pins(function(x) return x:GetDir() == bpschema.PD_Out end) do

				for _, target in ipairs(pin:GetConnectedPins()) do

					local targetNode = target:GetNode()
					local A = nodeMap[oldNode]
					local B = nodeMap[targetNode]
					if A and B then

						local APin = A:FindPin(bpschema.PD_Out, pin:GetName())
						local BPin = B:FindPin(bpschema.PD_In, target:GetName())

						if APin and BPin then

							APin:Connect(BPin)

						end

					end

				end

			end

		end

	end

	return new

end