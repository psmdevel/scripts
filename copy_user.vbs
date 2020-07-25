' This code copies the attributes in the Attrs array from an 
' existing object to a new one.

Set objArgs = WScript.Arguments
If objArgs.Count < 3 Then
	Wscript.Echo "Usage: copy_user <from_user> <to_user> <password>"
	Wscript.Echo
	Wscript.Quit
End if

TemplateUserName=objArgs(0)
NewUserName=objArgs(1)
Password=objArgs(2)

' ------ SCRIPT CONFIGURATION ------
arrAttrs        = Array("department","co","title","l", "c", "st")
strParentDN     = "ou=ASP Users OU,dc=mycharts,dc=md"   ' e.g. cn=Users,dc=rallencorp,dc=com
strTemplateUser = TemplateUserName  ' e.g. template-user-sales
strNewUser      = NewUserName       ' e.g. jdoe
strPassword     = Password
' ------ END CONFIGURATION ---------
     
Const ADS_UF_NORMAL_ACCOUNT = 512  ' from ADS_USER_FLAG_ENUM

Wscript.Echo "LDAP://cn=" & strTemplateUser & "," & strParentDN
     
Set objTemplate = GetObject("LDAP://cn=" & strTemplateUser & "," & strParentDN)
Set objParent   = GetObject("LDAP://" & strParentDN)
Set objUser     = objParent.Create("user", "cn=" & strNewUser)
     
objUser.Put "sAMAccountName", strNewUser
    
for each strAttr in arrAttrs
   objUser.Put strAttr, objTemplate.Get(strAttr)
next
     
objUser.SetInfo
objUser.SetPassword(strPassword)
objUser.SetInfo

objUser.Put "userAccountControl", ADS_UF_NORMAL_ACCOUNT
objUser.AccountDisabled = FALSE
objUser.SetInfo

WScript.Echo "Successfully created user"

