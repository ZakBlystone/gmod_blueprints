TEST.Name = "List Diff"
TEST.Libs = {
	"bpdata",
	"bplist",
	"bplistdiff",
	"bpfile",
}

function DIFF_BASIC()

	local myList = bplist.New():NamedItems()
	myList:Add( bpfile.New(), "test1" )
	myList:Add( bpfile.New(), "test2" )

	local shadow = myList:CopyInto( bplist.New(), true )

	myList:Remove( 1 )
	myList:Add( bpfile.New(), "crazy" )
	myList:Get(2):SetFlag(bpfile.FL_Running)

	local diff = bplistdiff.New( shadow, myList )


	local listenerExecuted = false
	shadow:BindRaw("postModify", "test", function(action, id, var)
		if action == bplist.MODIFY_REPLACE then
			listenerExecuted = true
		end
	end)

	diff:Patch(shadow)

	EXPECT( bplistdiff.New( shadow, myList ):IsEmpty(), true )
	EXPECT( listenerExecuted, true )

end