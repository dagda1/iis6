function create_site(name, path, hostname)
	strComputer = "."
	Set objWMIService = GetObject _
		("winmgmts:{authenticationLevel=pktPrivacy}\\" _
			& strComputer & "\root\microsoftiisv2")

	Set objWebService = objWMIService.ExecQuery _
		("Select * From IISWebService")

	arrBindings = Array(0)
	Set arrBindings(0) = objWMIService.Get("ServerBinding").SpawnInstance_()
	arrBindings(0).IP = "192.168.1.1"
	arrBindings(0).Port = "80"
	arrBindings(0).Hostname = hostname

	For Each objItem in objWebService
		objItem.CreateNewSite name, arrBindings, path
	Next

	Set colItems = objWMIService.ExecQuery ("Select * from IIsWebServiceSetting")

	For Each objItem in colItems
		objItem.AllowKeepAlive = True
		objItem.ConnectionTimeout = 1200
		objItem.DontLog = False
		objItem.ServerComment = "This is an intranet-only server."
		objItem.Put_
	Next

	strComputer = "."
	Set objWMIService = GetObject ("winmgmts:{authenticationLevel=pktPrivacy}\\" _
	& strComputer & "\root\microsoftiisv2")

	Set colItems = objWMIService.ExecQuery("Select * from IIsWebServiceSetting")

	For Each objItem in colItems
		strDocs = objItem.DefaultDoc
		objItem.DefaultDoc = strDocs & ",Default.aspx"
		objItem.EnableDefaultDoc = True
		objItem.EnableDocFooter = False
		objItem.Put_
	Next

	strComputer = "."
	Set objWMIService = GetObject _
	("winmgmts:{authenticationLevel=pktPrivacy}\\" _
	& strComputer & "\root\microsoftiisv2")

	Set colItems = objWMIService.ExecQuery ("Select * from IIsWebServiceSetting")

	For Each objItem in colItems
		objItem.ContentIndexed = True
		objItem.DontLog = True
		objItem.Put_
	Next

	strComputer = "."
	Set objWMIService = GetObject _
	("winmgmts:{authenticationLevel=pktPrivacy}\\" _
	& strComputer & "\root\microsoftiisv2")

	Set colItems = objWMIService.ExecQuery ("Select * from IIsWebServiceSetting")

	For Each objItem in colItems
		objItem.MaxBandwidth = -1
		objItem.MaxConnections = 10000
		objItem.Put_
	Next

	strComputer = "."
	Set objWMIService = GetObject _
	("winmgmts:{authenticationLevel=pktPrivacy}\\" _
	& strComputer & "\root\microsoftiisv2")

	Set colItems = objWMIService.ExecQuery _
	("Select * From IIsWebServer Where Name = " & _
	"'W3SVC/2142295254'")

	For Each objItem in colItems
		objItem.Start
	Next




end function

msgbox wsh.arguments(0)
msgbox wsh.arguments(1)
msgbox wsh.arguments(2)
'create_site(wsh.arguments(0), wsh.arguments(1), wsh.arguments(2))