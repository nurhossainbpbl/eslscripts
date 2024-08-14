@@ -0,0 +1,197 @@
# Please Configure the following variables....
$DomainName="GPH"
$smtpServer="smtprelay.bergerbd.com"
$password = ConvertTo-SecureString "Y5tnTAdiPBzFSwABjvWt" -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential ("bergertechbd", $password)
$from ="support@bergertechbd.com"
$expireindays = 6
$logging = "Enabled" # Set to Disabled to Disable Logging
$ct = get-date -format yyyyMMdd-hhmm
$logFile = ".\PasswordExpiry-$ct.csv" # ie. c:\mylog.csv
$testing = "Disabled" # Set to Disabled to Email Users
$testRecipient = "infrastructure@bergerbd.com"

###################################################################################################################

# Check Logging Settings
if (($logging) -eq "Enabled")
{
    # Test Log File Path
    $logfilePath = (Test-Path $logFile)
    if (($logFilePath) -ne "True")
    {
        # Create CSV File and Headers
        New-Item $logfile -ItemType File
        Add-Content $logfile "Date,DisplayName,Username,EmailAddress,DaystoExpire,ExpiresOn,Notified"
    }
} # End Logging Check

# System Settings
$textEncoding = [System.Text.Encoding]::UTF8
$date = Get-Date -format ddMMyyyy
# End System Settings

# Get Users From AD who are Enabled, Passwords Expire and are Not Currently Expired
Import-Module ActiveDirectory
$users = get-aduser -filter * -properties DisplayName, PasswordNeverExpires, PasswordExpired, PasswordLastSet, EmailAddress | where { $_.Enabled -eq "True" -AND $_.PasswordNeverExpires -eq $false -AND $_.passwordexpired -eq $false}
$DefaultmaxPasswordAge = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge

# Process Each User for Password Expiry
foreach ($user in $users)
{
    $Name = $user.DisplayName
	$UserName = $user.SamAccountName
    $emailaddress = $user.emailaddress
    $passwordSetDate = $user.PasswordLastSet
    $PasswordPol = (Get-AduserResultantPasswordPolicy $user)
    $sent = "" # Reset Sent Flag
    # Check for Fine Grained Password
    if (($PasswordPol) -ne $null)
    {
        $maxPasswordAge = ($PasswordPol).MaxPasswordAge
    }
    else
    {
        # No FGP set to Domain Default
        $maxPasswordAge = $DefaultmaxPasswordAge
    }


    $expireson = $passwordsetdate + $maxPasswordAge
    $today = (get-date)
    $daystoexpire = (New-TimeSpan -Start $today -End $Expireson).Days

    # Set Greeting based on Number of Days to Expiry.

    # Check Number of Days to Expiry
    $messageDays = $daystoexpire
	$expirationTime = ($passwordSetDate).AddDays($maxPasswordAge.Days)

    if (($messageDays) -gt "1")
    {
        $messageDays = "in " + "$daystoexpire" + " days"
    }
    else
    {
        $messageDays = "today"
    }

    # Email Subject Set Here
    $subject="Your VPN password will expire $messageDays"

    # Email Body Set Here, Note You can use HTML, including Images.
    $body ="Dear $Name,
    <p>
	Your Password will expire $messageDays ($expirationTime). Please do not wait for the last day. Please choose a secure password which complies with the following password policy settings -
	</p>

	<p>
	 <b> Current password policy settings </b> <br>
		<ul>
	     <li> 8 old passwords can not be reused </li>
		 <li> The minimum password length is 8 characters </li>
		 <li> Password must contain three characters from the following four categories: </li>
		 <ul>
			<li> English uppercase characters (A through Z) </li>
			<li> English lowercase characters (a through z) </li>
			<li> Base 10 digits (0 through 9) </li>
			<li> Non-alphabetic or special characters (for example, !, $, #, %, @) </li>
		 </ul>
         <li> Password must not contain the user's account name or parts of the user's full name that exceed two consecutive characters. </li>
		 <li> Password should not contain dictionary words like January, February etc.  </li>
		 <li> Password should not common words like Allah, Bismillah etc. </li>
         <li> The maximum password age is 42 days i.e. password must be changed after 42 days. </li>
         <li> The minimum password age is 1 day i.e. password could not be changed before 24 hours. </li>
        </ul>
	</p>

	<p>
	Example of password:  <br>
	<table border=1>
	  <tr>
		<th>Bad</th>
		<th>Good</th>
	  </tr>
	  <tr>
		<td>June@2021</td>
		<td>Jvne@2021</td>
	  </tr>
	  <tr>
		<td>Dhaka@2021</td>
		<td>Dhk@2021</td>
	  </tr>
	</table>
	</p>

	<p>
	Please use the following password change method -
	</p>

	<p>
	 <ul>
	   <li> Close all of your running applications except browser. </li>
	   <li> Browse https://40.119.214.27:4435/RDWeb/Pages/en-US/password.aspx from any updated browser. </li>
	   <li> Put your username i.e. $DomainName\$UserName in username field. </li>
	   <li> Put your current VPN password in 'Current password:' field. </li>
	   <li> Type your new password in 'New password:' field. </li>
	   <li> Retype your new password in 'Confirm new password:' field. </li>
	   <li> Click on 'Submit'. </li>
	 </ul>
	</p>

    <p>
	   Thanks - <br>
     Cloud Support Team
    </p>"


    # If Testing Is Enabled - Email Administrator
    if (($testing) -eq "Enabled")
    {
        $emailaddress = $testRecipient
    } # End Testing

    # If a user has no email address listed
    if (($emailaddress) -eq $null)
    {
        $emailaddress = $testRecipient
    }# End No Valid Email

    # Send Email Message
    if (($daystoexpire -ge "0") -and ($daystoexpire -lt $expireindays))
    {
        $sent = "Yes"
        # If Logging is Enabled Log Details
        if (($logging) -eq "Enabled")
        {
            Add-Content $logfile "$date,$Name,$UserName,$emailaddress,$daystoExpire,$expireson,$sent"
        }
        # Send Email Message

		try{
			Send-Mailmessage -smtpServer $smtpServer -from $from -to $emailaddress -subject $subject -body $body -bodyasHTML -Encoding $textEncoding -Port 587 -Credential $Cred -UseSsl
			start-sleep 30
		}
		catch{
			Write-Host Email sending failed for $emailaddress
			Write-Host "`nError Message: " $_.Exception.Message
        }

    } # End Send Message
    else # Log Non Expiring Password
    {
        $sent = "No"
        # If Logging is Enabled Log Details
        if (($logging) -eq "Enabled")
        {
            Add-Content $logfile "$date,$Name,$UserName,$emailaddress,$daystoExpire,$expireson,$sent"
        }
    }

} # End User Processing



# End
