
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()


Function Wait ($secs) {
	if (!($secs)) {$secs = 1}
	Start-Sleep $secs
}

Function Say($something) {
	Write-Host $something 
}

Function SayB($something) {
	Write-Host $something -ForegroundColor darkblue -BackgroundColor white
}

Function isOSTypeHome {
	$ret = (Get-WmiObject -class Win32_OperatingSystem).Caption | select-string "Home"
	Return $ret
}

Function isOSTypePro {
	$ret = (Get-WmiObject -class Win32_OperatingSystem).Caption | select-string "Pro"
	Return $ret
}

Function isOSTypeEnt {
	$ret = (Get-WmiObject -class Win32_OperatingSystem).Caption | select-string "Ent"
	Return $ret
}

Function getWinVer {
	$ret = (Get-WMIObject win32_operatingsystem).version
	Return $ret
}

Function isAdminLocal {
	$ret = (new-object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole("Administrators")
	Return $ret
}

Function isAdminDomain {
	$ret = (new-object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole("Domain Admins")
	Return $ret
}

Function isElevated {
	$ret = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')
	Return $ret
}

Function regSet ($KeyPath, $KeyItem, $KeyValue) {
	$Key = $KeyPath.Split("\")
	ForEach ($level in $Key) {
		If (!($ThisKey)) {
			$ThisKey = "$level"
		} Else {
			$ThisKey = "$ThisKey\$level"
		}
		If (!(Test-Path $ThisKey)) {New-Item $ThisKey -Force -ErrorAction SilentlyContinue | out-null}
	}
	if ($KeyValue -ne $null) {
		Set-ItemProperty $KeyPath $KeyItem -Value $KeyValue -ErrorAction SilentlyContinue 
	} Else {
		Remove-ItemProperty $KeyPath $KeyItem -ErrorAction SilentlyContinue 
	}
}

Function regGet($Key, $Item) {
	If (!(Test-Path $Key)) {
		Return
	} Else {
		If (!($Item)) {$Item = "(Default)"}
		$ret = (Get-ItemProperty -Path $Key -Name $Item -ErrorAction SilentlyContinue).$Item
		Return $ret
	}
}


function MsgBox($Msg, $Caption, $Prompt, $Icon) {
	# $mBox =  [System.Windows.MessageBox]::Show('display dialog?','Begin','YesNo','Information')
	If ($Msg -eq $null) {$Msg = ""}
	If ($Caption -eq $null) {$Caption = ""}
	If ($Prompt -eq $null) {$Prompt = "Ok"}
	If ($Icon -eq $null) {$Icon = "Information"}
	$mBox =  [System.Windows.MessageBox]::Show($Msg, $Caption, $Prompt, $Icon)
	Return $mBox
}


function getUserGroups($username) {
	$tlist = Get-LocalUser | 
		ForEach-Object { 
			$user = $_
			return [PSCustomObject]@{ 
				"User"   = $user.Name
				"Groups" = Get-LocalGroup | Where-Object {  $user.SID -in ($_ | Get-LocalGroupMember | Select-Object -ExpandProperty "SID") } | Select-Object -ExpandProperty "Name"
			} 
		}
	$groups = ($tlist | where {$_.User -like $username}).groups 
	return $groups
	}

# # # # # # # # # # # # 
# # BEGIN EXECUTION # # 
# # # # # # # # # # # # 

If (!(isElevated)) {
	Msgbox "Script was not launched with Elevated permissions, attempting now." "Need Elevated Permissions" "OK" "Warning"
	Wait 1
	Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`" elevate" -f $PSCommandPath) -Verb RunAs
} Else {

	$script:isChanged 	= $false
	$script:popStart 	= $true
	$script:newUser		= $false
	$script:Saving		= $false

	$frmUsers                  	= New-Object System.Windows.Forms.Form
	$frmUsers.ClientSize       	= New-Object System.Drawing.Point(545,425)
	$frmUsers.StartPosition    	= 'CenterScreen'; 	$frmUsers.FormBorderStyle  	= 'FixedSingle'
	$frmUsers.MinimizeBox      	= $true; 			$frmUsers.MaximizeBox      	= $false
	$frmUsers.ShowIcon         	= $true; 			$frmUsers.Text             	= "Local User Management - Megaphat Networks"
	$frmUsers.TopMost          	= $false; 			$frmUsers.AutoScroll       	= $true

	$lblUsers = New-Object System.Windows.Forms.Label
	$lblUsers.Text 				= "Local Users"; 	$lblUsers.Top 				= 5
	$lblUsers.Left 				= 5; 				$lblUsers.Width 			= 150
	$lblUsers.Height 			= 16;				$frmUsers.controls.AddRange(@($lblUsers))

	$lbUsers 					= New-Object System.Windows.Forms.ListBox
	$lbUsers.top          		= 25;				$lbUsers.Left          		= 5
	$lbUsers.height          	= 200;				$lbUsers.width           	= 150
	$frmUsers.controls.AddRange(@($lbUsers))

	$btnEdit             		= New-Object system.Windows.Forms.Button
	$btnEdit.text        		= "Edit User";		$btnEdit.width       		= 75
	$btnEdit.height      		= 30;				$btnEdit.left      			= 160
	$btnEdit.top      			= 25;				$btnEdit.Enabled      		= $true
	$frmUsers.controls.AddRange(@($btnEdit))

	$btnCancel             		= New-Object system.Windows.Forms.Button
	$btnCancel.text        		= "Cancel Edit";	$btnCancel.width       		= 75
	$btnCancel.height      		= 30;				$btnCancel.left      		= 160
	$btnCancel.top      		= 60;				$btnCancel.Enabled      	= $false
	$frmUsers.controls.AddRange(@($btnCancel))

	$btnDelUser            		= New-Object system.Windows.Forms.Button
	$btnDelUser.text        	= "Delete User";	$btnDelUser.left      			= 160
	$btnDelUser.top      		= 105;				$btnDelUser.width       		= 75
	$btnDelUser.height      	= 30;				$btnDelUser.Enabled      		= $true
	$frmUsers.controls.AddRange(@($btnDelUser))

	$lblGroups 					= New-Object System.Windows.Forms.Label
	$lblGroups.Text 			= "Effective Priviledges / Groups"
	$lblGroups.Top 				= 5;				$lblGroups.Left				= 250
	$lblGroups.Width 			= 200;				$lblGroups.Height 			= 16
	$frmUsers.controls.AddRange(@($lblGroups))

	$lbcGroups					 = New-Object System.Windows.Forms.CheckedListBox
	$lbcGroups.Top 				= 25;				$lbcGroups.left 			= 250
	$lbcGroups.height          	= 200;				$lbcGroups.width           	= 200
	$lbcGroups.CheckOnClick 	= $true;			$lbcGroups.Enabled			= $false
	$frmUsers.controls.AddRange(@($lbcGroups))

	$lblUserName           		= New-Object system.Windows.Forms.Label
	$lblUserName.text        	= "User Name";		$lblUserName.width       	= 100
	$lblUserName.height      	= 15;				$lblUserName.left      		= 250
	$lblUserName.top      		= 230;				$frmUsers.controls.AddRange(@($lblUserName))

	$txtUserName           		= New-Object system.Windows.Forms.Textbox
	$txtUserName.text        	= "";				$txtUserName.width       	= 150
	$txtUserName.height      	= 15;				$txtUserName.left      		= 250
	$txtUserName.top      		= 245;				$txtUserName.Enabled		= $false
	$frmUsers.controls.AddRange(@($txtUserName))

	$lblFullName           		= New-Object system.Windows.Forms.Label
	$lblFullName.text        	= "Full Name";		$lblFullName.width       	= 100
	$lblFullName.height      	= 15;				$lblFullName.left      		= 250
	$lblFullName.top      		= 270;				$frmUsers.controls.AddRange(@($lblFullName))

	$txtFullName           		= New-Object system.Windows.Forms.Textbox
	$txtFullName.text        	= "";				$txtFullName.width       	= 150
	$txtFullName.height      	= 15;				$txtFullName.left      		= 250
	$txtFullName.top      		= 285;				$txtFullName.Enabled		= $false
	$frmUsers.controls.AddRange(@($txtFullName))

	$lblDescription           	= New-Object system.Windows.Forms.Label
	$lblDescription.text        = "Description";	$lblDescription.width       = 100
	$lblDescription.height      = 15;				$lblDescription.left      	= 250
	$lblDescription.top      	= 310;				$frmUsers.controls.AddRange(@($lblDescription))

	$txtDescription           	= New-Object system.Windows.Forms.Textbox
	$txtDescription.text        = "";				$txtDescription.width       = 225
	$txtDescription.height      = 90;				$txtDescription.left      	= 250
	$txtDescription.top      	= 325;				$txtDescription.Multiline	= $true
	$txtDescription.Enabled		= $false;			$frmUsers.controls.AddRange(@($txtDescription))

	$chkEnabled            		= New-Object system.Windows.Forms.CheckBox
	$chkEnabled.text        	= "Account Enabled"
	$chkEnabled.width       	= 200;				$chkEnabled.height      	= 15
	$chkEnabled.left      		= 5;				$chkEnabled.top      		= 230
	$chkEnabled.Enabled			= $false;			$frmUsers.controls.AddRange(@($chkEnabled))

	$chkCanChPass          		= New-Object system.Windows.Forms.CheckBox
	$chkCanChPass.text        	= "Can Change Password"
	$chkCanChPass.width       	= 200;				$chkCanChPass.height      	= 15
	$chkCanChPass.left      	= 5;				$chkCanChPass.top      		= 250
	$chkCanChPass.Enabled		= $false;			$frmUsers.controls.AddRange(@($chkCanChPass))

	$chkPassReq          		= New-Object system.Windows.Forms.CheckBox
	$chkPassReq.text        	= "Password Never Expires"
	$chkPassReq.width       	= 200;				$chkPassReq.height      	= 15
	$chkPassReq.left      		= 5;				$chkPassReq.top      		= 270
	$chkPassReq.Enabled			= $false;			$frmUsers.controls.AddRange(@($chkPassReq))

	$chkHideFrom          		= New-Object system.Windows.Forms.CheckBox
	$chkHideFrom.text        	= "Hide from Login Screen"
	$chkHideFrom.width       	= 200;				$chkHideFrom.height      	= 17
	$chkHideFrom.left      		= 5;				$chkHideFrom.top      		= 290
	$chkHideFrom.Enabled		= $false;			$frmUsers.controls.AddRange(@($chkHideFrom))

	$chkChPass          		= New-Object system.Windows.Forms.CheckBox
	$chkChPass.text        		= "Change Password"
	$chkChPass.width       		= 200;				$chkChPass.height      		= 15
	$chkChPass.left      		= 5;				$chkChPass.top      		= 320
	$chkChPass.Enabled			= $false;			$frmUsers.controls.AddRange(@($chkChPass))

	$lblPassWd           		= New-Object system.Windows.Forms.Label
	$lblPassWd.text        		= "Password";		$lblPassWd.width       		= 100
	$lblPassWd.height      		= 15;				$lblPassWd.left      		= 5
	$lblPassWd.top      		= 340;				$frmUsers.controls.AddRange(@($lblPassWd))

	$txtPassWd		           	= New-Object system.Windows.Forms.Textbox
	$txtPassWd.text       		= "";				$txtPassWd.width       		= 200
	$txtPassWd.height      		= 15;				$txtPassWd.left      		= 5
	$txtPassWd.top      		= 355;				$txtPassWd.Enabled			= $false
	$txtPassWd.PasswordChar		= '*';				$frmUsers.controls.AddRange(@($txtPassWd))

	$lblPassCf           		= New-Object system.Windows.Forms.Label
	$lblPassCf.text        		= "Confirm";		$lblPassCf.width       		= 100
	$lblPassCf.height      		= 15;				$lblPassCf.left      		= 5
	$lblPassCf.top      		= 380;				$frmUsers.controls.AddRange(@($lblPassCf))

	$txtPassCf 		          	= New-Object system.Windows.Forms.Textbox
	$txtPassCf.text        		= "";				$txtPassCf.width      		= 200
	$txtPassCf.height      		= 15;				$txtPassCf.left      		= 5
	$txtPassCf.top      		= 395;				$txtPassCf.Enabled			= $false
	$txtPassCf.PasswordChar		= '*';				$frmUsers.controls.AddRange(@($txtPassCf))

	$btnNewUsr             		= New-Object system.Windows.Forms.Button
	$btnNewUsr.text        		= "New User";		$btnNewUsr.width       		= 75
	$btnNewUsr.height      		= 30;				$btnNewUsr.left      		= 455
	$btnNewUsr.top      		= 120;				$btnNewUsr.Enabled      	= $true
	$frmUsers.controls.AddRange(@($btnNewUsr))

	$btnCanUsr             		= New-Object system.Windows.Forms.Button
	$btnCanUsr.text        		= "Cancel New";		$btnCanUsr.width       		= 75
	$btnCanUsr.height      		= 30;				$btnCanUsr.left      		= 455
	$btnCanUsr.top      		= 150;				$btnCanUsr.Enabled      	= $false
	$frmUsers.controls.AddRange(@($btnCanUsr))

	$btnSave             		= New-Object system.Windows.Forms.Button
	$btnSave.text        		= "Save User";		$btnSave.width       		= 75
	$btnSave.height      		= 30;				$btnSave.left      			= 160
	$btnSave.top      			= 195;				$btnSave.Enabled      		= $false
	$frmUsers.controls.AddRange(@($btnSave))

	# Get a simple list of all the local users, enumerate through the list and add to the ListBox
	$AllUsers = Get-LocalUser
	foreach ($ThisUser in $AllUsers) {
		[void] $lbUsers.Items.Add($ThisUser.Name)
	}

	#Get a simple list of all of the local groups, enumerate through the list and add to the CheckedListBox
	$AllGroups = Get-LocalGroup
	foreach ($ThisGroup in $AllGroups) {
		[void] $lbcGroups.Items.Add($ThisGroup.Name)
	}

	# Clear all checkboxes in the Groups list
	function clrChecks() {
		for($i = 0; $i -lt $lbcGroups.Items.Count; $i++) {
			$lbcGroups.SetItemChecked($i, $false);
		}
	}

	#EVENT ListBox Users SelectedIndexChanged
	$lbUsers.Add_SelectedIndexChanged( {
		if ($script:Saving -eq $false) {
			popUserInfo
			$script:isChanged = $false
		}
	})

	#EVENT CheckedListBox Groups ItemCheck
	$lbcGroups.Add_ItemCheck( {
		if ($script:popStart -eq $false) {$script:isChanged = $true; $btnSave.Enabled = $true}
	})

	#EVENT CheckedListBox Groups Click
	$lbcGroups.Add_Click( {
		# $script:isChanged = $true
		if (($script:popStart -eq $false) -and ($script:Saving -eq $false)) {$script:isChanged = $true; $btnSave.Enabled = $true}
	})

	#EVENT Checkbox Account Enabled Check
	$chkEnabled.Add_CheckedChanged({ 
		if ($script:popStart -eq $false) {$script:isChanged = $true; $btnSave.Enabled = $true}
	})
	
	#EVENT Checkbox Can Change Password Check
	$chkCanChPass.Add_CheckedChanged({ 
		if ($script:popStart -eq $false) {$script:isChanged = $true; $btnSave.Enabled = $true}
	})

	#EVENT Checkbox Password Never Expires Check
	$chkPassReq.Add_CheckedChanged({ 
		if ($script:popStart -eq $false) {$script:isChanged = $true; $btnSave.Enabled = $true}
	})

	#EVENT Checkbox Hide From Login Check
	$chkHideFrom.Add_CheckedChanged({ 
		if ($script:popStart -eq $false) {$script:isChanged = $true; $btnSave.Enabled = $true}
	})

	#EVENT Textbox Full Name Changed
	$txtFullName.Add_TextChanged({ 
		if ($script:popStart -eq $false) {$script:isChanged = $true; $btnSave.Enabled = $true}
	})

	#EVENT Textbox User Name Changed
	$txtUserName.Add_TextChanged({ 
		if ($script:popStart -eq $false) {$script:isChanged = $true; $btnSave.Enabled = $true}
	})

	#EVENT Textbox Description Changed
	$txtDescription.Add_TextChanged({ 
		if ($script:popStart -eq $false) {$script:isChanged = $true; $btnSave.Enabled = $true}
	})

	#EVENT Checlbox Change Password Checked
	$chkChPass.Add_CheckedChanged({ 
		if ($chkChPass.Checked -eq $true) {
			$txtPassWd.Enabled 		= $true
			$txtPassCf.Enabled 		= $true
		} Else {
			$txtPassWd.Enabled 		= $false
			$txtPassCf.Enabled 		= $false
		}
	})

	#EVENT Button Delete User Click
	$btnDelUser.Add_Click( {
		if ($env:username -eq $lbUsers.SelectedItem) {
			Msgbox "No, absolutely NOT!   I will not let you delete yourself!"
		} Else {
			$msg = "Deleting a user CANNOT be undone!  It is recommended that you take care when perfomring this action.  "
			$msg += "All user data will remain, this action only deletes the account.  This will NOT free up any space.  "
			$msg += "Are you absolutely sure you wish to delete """ + $lbUsers.SelectedItem.ToUpper() + """ from this system?"
			$mb = Msgbox $msg "Delete User" "YesNo" "Question"
			If ($mb -eq "Yes") {
				regSet "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" $lbUsers.SelectedItem
				Remove-LocalUser -name $lbUsers.SelectedItem
				$lbUsers.Items.Remove($lbUsers.SelectedItem)
			}
		}
	})
	
	#EVENT Button Edit User Click
	$btnEdit.Add_Click( {
		$btnEdit.Enabled 		= $false;		$btnCancel.Enabled 		= $true
		$lbUsers.Enabled 		= $false;		$lbcGroups.Enabled 		= $true
		$chkEnabled.Enabled 	= $true;		$chkCanChPass.Enabled 	= $true
		$chkPassReq.Enabled 	= $true;		$chkHideFrom.Enabled 	= $true
		$txtFullName.Enabled 	= $true;		$txtUserName.Enabled 	= $true
		$txtDescription.Enabled = $true;		$btnSave.Enabled 		= $true
		$btnNewUsr.Enabled 		= $false;		$chkChPass.Enabled		= $true
		
	})

	#EVENT Button New User Click
	$btnNewUsr.Add_Click( {
		$script:newUser			= $true;		$btnCanUsr.Enabled 		= $true
		$btnEdit.Enabled 		= $false;		$btnCancel.Enabled 		= $false
		$lbUsers.Enabled 		= $false;		$lbcGroups.Enabled 		= $true
		$chkEnabled.Enabled 	= $true;		$chkCanChPass.Enabled 	= $true
		$chkPassReq.Enabled 	= $true;		$chkHideFrom.Enabled 	= $true
		$txtFullName.Enabled 	= $true;		$txtUserName.Enabled 	= $true
		$txtDescription.Enabled = $true;		$btnSave.Enabled 		= $true
		$btnNewUsr.Enabled 		= $false;		$chkChPass.Enabled		= $true
		$txtUserName.Text 		= '';			$txtDescription.Text	= ''
		$txtFullName.Text 		= ''; 			$chkEnabled.Checked		= $true
		$chkPassReq.Checked		= $true;		$chkCanChPass.Checked	= $true
		$chkHideFrom.Checked	= $false;		$txtUserName.Focus()
	})

	#EVENT Button Cancel Edit User Click
	$btnCancel.Add_Click( {
		if ($script:isChanged -eq $true) {
			$mb = Msgbox "You have made changes to this user.  Are you sure you wish to Cancel before Saving the changes?" "Cancel Changes" "YesNo" "Question"
			if ($mb -eq "Yes") {
				$btnEdit.Enabled 		= $true;		$btnCancel.Enabled 		= $false
				$lbUsers.Enabled 		= $true;		$lbcGroups.Enabled 		= $false
				$chkEnabled.Enabled 	= $false;		$chkCanChPass.Enabled 	= $false
				$chkPassReq.Enabled 	= $false;		$chkHideFrom.Enabled 	= $false
				$txtFullName.Enabled 	= $false;		$txtUserName.Enabled 	= $false
				$txtDescription.Enabled = $false;		$btnSave.Enabled 		= $false
				$btnNewUsr.Enabled 		= $true;		$chkChPass.Enabled		= $false
				$chkChPass.Checked		= $false
				popUserInfo
				$script:isChanged = $false
			}
		} Else {
			$btnEdit.Enabled 		= $true;		$btnCancel.Enabled 		= $false
			$lbUsers.Enabled 		= $true;		$lbcGroups.Enabled 		= $false
			$chkEnabled.Enabled 	= $false;		$chkCanChPass.Enabled 	= $false
			$chkPassReq.Enabled 	= $false;		$chkHideFrom.Enabled 	= $false
			$txtFullName.Enabled 	= $false;		$txtUserName.Enabled 	= $false
			$txtDescription.Enabled = $false;		$btnSave.Enabled 		= $false
			$btnNewUsr.Enabled 		= $true;		$chkChPass.Enabled		= $false
			$chkChPass.Checked		= $false
		}
	})

	#EVENT Button Cancel New User Click
	$btnCanUsr.Add_Click( {
		$script:newUser			= $false;		$btnCanusr.Enabled		= $false
		$btnEdit.Enabled 		= $true;		$btnCancel.Enabled 		= $false
		$lbUsers.Enabled 		= $true;		$lbcGroups.Enabled 		= $false
		$chkEnabled.Enabled 	= $false;		$chkCanChPass.Enabled 	= $false
		$chkPassReq.Enabled 	= $false;		$chkHideFrom.Enabled 	= $false
		$txtFullName.Enabled 	= $false;		$txtUserName.Enabled 	= $false
		$txtDescription.Enabled = $false;		$btnSave.Enabled 		= $false
		$btnNewUsr.Enabled 		= $true;		$chkChPass.Enabled		= $false
		$chkChPass.Checked		= $false
		popUserInfo
		$script:isChanged = $false
	})

	#EVENT Button Save Click
	$btnSave.Add_Click({
		$script:Saving = $true
		if (($env:username -eq $lbUsers.SelectedItem) -and ($chkEnabled.Checked -eq $false)) {
			Msgbox "Disabling Yourself is REALLY NOT a good idea! " "WARNING" "Ok" "Warning"
		}
		if ($script:newUser -eq $true) {
			CreateUser
		}
		if ($private:uid -ne '') {
			setUserProps $lbUsers.SelectedItem
			setUserGroups $lbUsers.SelectedItem
			setPwd $lbUsers.SelectedItem
			if (($lbUsers.SelectedItem -ne $txtUserName.Text) -and ($env:username -eq $lbUsers.SelectedItem)) {
				RenameUser 
				Msgbox "You have modified your OWN account!  You may need to log off in order for the changes to take effect."
			}
		}
		$script:newUser			= $false;		$btnCanUsr.Enabled		= $false
		$btnEdit.Enabled 		= $true;		$btnCancel.Enabled 		= $false
		$lbUsers.Enabled 		= $true;		$lbcGroups.Enabled 		= $false
		$chkEnabled.Enabled 	= $false;		$chkCanChPass.Enabled 	= $false
		$chkPassReq.Enabled 	= $false;		$chkHideFrom.Enabled 	= $false
		$txtFullName.Enabled 	= $false;		$txtUserName.Enabled 	= $false
		$txtDescription.Enabled = $false;		$btnSave.Enabled 		= $false
		$btnNewUsr.Enabled 		= $true;		$chkChPass.Enabled		= $false
		$chkChPass.Checked		= $false;		$script:Saving			= $false
	})

		
	function CreateUser() {
		# Create new user
		if ($txtUserName.Text -eq '') {
			Msgbox "Cannot save a user with no name, cancelling!" "Error" "Ok" "Warning"
		} Else {
			if ($txtPassWd.Text -ne $txtPassCf.Text) {
				Msgbox "Password and Confirmation do NOT match!  Setting to blank.  You can edit the settings after completion." "Warning" "OK" "Warning"
				$txtPassWd.Text = ''
				$txtPassCf.Text = ''
			}
			if ($txtPassWd.Text -eq '') {
				New-LocalUser -name $txtUserName.Text -Password ([securestring]::new())
			} Else {
				New-LocalUser -name $txtUserName.Text -Password (ConvertTo-SecureString $txtPassWd.Text -AsPlainText -Force)
			}
			[void] $lbUsers.Items.Add($txtUserName.Text)
			$lbUsers.SelectedIndex = ($lbUsers.Items.Count-1)
			$lbUsers.Sorted = $true
		}		
		Return $txtUserName.Text
	}

	function setUserProps() {
		Set-LocalUser -Name $lbUsers.SelectedItem -Description $txtDescription.Text
		Set-LocalUser -Name $lbUsers.SelectedItem -FullName $txtFullName.Text
		if ($chkEnabled.Checked -eq $true) {Enable-LocalUser -Name $lbUsers.SelectedItem} Else {Disable-LocalUser -Name $lbUsers.SelectedItem}
		Set-LocalUser -Name $lbUsers.SelectedItem -UserMayChangePassword $chkCanChPass.Checked
		if ($chkPassReq.Checked -eq $true) {
			Set-LocalUser -Name $lbUsers.SelectedItem -PasswordNeverExpires 1
		} Else {
			Set-LocalUser -Name $lbUsers.SelectedItem -PasswordNeverExpires 0
		}
		if ($chkHideFrom.Checked -eq $true) {
			regSet "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" $lbUsers.SelectedItem 0
		} Else {
			regSet "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" $lbUsers.SelectedItem
		}
	}

	function setPwd() {
		if ($chkChPass.Checked -eq $true) {
			if ($txtPassWd.Text -ne $txtPassCf.Text) {
				Msgbox "Password and Confirmation do NOT match!  Not changing password!"
			} Else {
				if ($txtPassWd.Text -eq '') {
					$mb = Msgbox 'Blank Passwords are not secure.  Are you sure you want to use a Blank Password?' 'Blank Password Detected' 'YesNo' 'Question'
					if ($mb -eq 'Yes') {Set-LocalUser -name $lbUsers.SelectedItem -Password ([securestring]::new())}
				} Else {
					Set-LocalUser -name $lbUsers.SelectedItem -Password (ConvertTo-SecureString $txtPassWd.Text -AsPlainText -Force)
				}
			}
			$txtPassWd.Text = ''
			$txtPassCf.Text = ''
		}
	}

	function setUserGroups() {
		foreach ($tItem in $lbcGroups.Items) {
			$isChecked=$lbcGroups.GetItemCheckState($lbcGroups.Items.IndexOf($tItem)).ToString() 
			if ($isChecked -eq "Checked") {
				# Save all CHECKED Groups
				$ErrorActionPreference = 'SilentlyContinue'
				Add-LocalGroupMember -Group $tItem -Member $lbUsers.SelectedItem
				$ErrorActionPreference = 'Continue'
			} Else {
				if (($tItem -eq "Administrators") -and ($lbUsers.SelectedItem -eq $env:username)) {
					# Removing Current user from Administrators
					$mb = Msgbox "Are you SURE you wish to remove yourself from the Administrators group?" "Confirmation" "YesNo" "Question"
					if ($mb -eq "Yes" ) {$ErrorActionPreference = 'SilentlyContinue';Remove-LocalGroupMember -Group $tItem -Member $tUser;$ErrorActionPreference = 'Continue'}
				} Else {
					# Save all UN-CHECKED Groups 
					$ErrorActionPreference = 'SilentlyContinue'
					Remove-LocalGroupMember -Group $tItem -Member $lbUsers.SelectedItem
					$ErrorActionPreference = 'Continue'
				}
			}
		}
	}

	function RenameUser() {
		$mb = Msgbox 'Are you sure you wish to rename user $lbUsers.SelectedItem to $txtUserName.Text ?' 'Rename User' 'YesNo' 'Question'
		if ($mb -eq 'Yes') {Rename-LocalUser -Name $lbUsers.SelectedItem -NewName $txtUserName.Text}
	}

	function popUserInfo () {
		$script:popStart 	= $true
		$userInfo = (Get-LocalUser | Where-Object {$_.Name -eq $lbUsers.SelectedItem} | select * )
		$chkEnabled.Checked 	= $userInfo.Enabled
		$chkCanChPass.Checked 	= $userInfo.UserMayChangePassword
		if ($userInfo.PasswordExpires -eq $null) {$chkPassReq.Checked = $true} Else {$chkPassReq.Checked = $false}
		$txtFullName.Text 		= $userInfo.FullName
		$txtUserName.Text		= $userInfo.Name
		$txtDescription.Text	= $userInfo.Description
		$temp = (regGet "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" $userInfo.Name)
		if ($temp -ne 0) {$chkHideFrom.Checked = $false} else {$chkHideFrom.Checked = $true} 
		$userGroups = getUserGroups($lbUsers.SelectedItem)
		clrChecks

		foreach ($uGroup in $userGroups) {
			$ErrorActionPreference = 'SilentlyContinue'
			foreach ($thisItem in $lbcGroups.Items) {
				if ($thisItem -eq $uGroup) {
					$lbcGroups.SetItemChecked($lbcGroups.Items.IndexOf($uGroup), $true);
				}
			}
			$ErrorActionPreference = 'Continue'
		}
		$btnSave.Enabled = $false
		$script:isChanged = $false
	}

	
	$lbUsers.SelectedIndex = 0
	popUserInfo
	$script:isChanged = $false
	$script:popStart 	= $false
	# Display Management Form
	[void]$frmUsers.ShowDialog()

} # End of Script
