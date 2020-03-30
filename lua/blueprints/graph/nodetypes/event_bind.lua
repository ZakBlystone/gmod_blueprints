AddCSLuaFile()

module("node_eventbind", package.seeall, bpcommon.rescope(bpschema, bpcompiler))

local NODE = {}

function NODE:Setup() end
function NODE:Compile(compiler, pass)

	BaseClass.Compile( self, compiler, pass )

	if pass == CP_MAINPASS then

		local arg = {}
		for k, pin in self:SidePins(PD_Out) do
			if not pin:IsType( PN_Exec ) then
				arg[#arg+1] = compiler:GetPinCode( pin, true )
			end
		end

		if #arg > 0 then compiler.emit( table.concat(arg, ",\n\t") .. " = ..." ) end

		return true

	elseif pass == CP_METAPASS then

		local graph = self:GetGraph()
		compiler:CompileGraphMetaHook(graph, self, self:GetTypeName())

		-- compile hook listing if this node is a hook
		local hook = self:GetHook()
		if hook then
			local graphID = compiler:GetID(graph)
			compiler.begin(CTX_Hooks .. graphID)
			local args = {self:GetTypeName(), hook, graphID, compiler:GetID(self)}
			compiler.emit("_FR_HOOK(" .. table.concat(args, ",") .. ")")
			compiler.finish()
		end

	end

end

RegisterNodeClass("EventBind", NODE)