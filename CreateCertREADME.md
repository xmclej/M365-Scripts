How to Add Macro File as Trusted Publisher
1.	User sends you the macro files  
a.	Ask the user to send you their macro files  
2.	Create a certificate to sign the files
a.	Run a PowerShell script to create the certificate (once) 
$cert = New-SelfSignedCertificate `
  -Subject "CN=*CertName" `
  -KeyUsage DigitalSignature `
  -Type CodeSigningCert `
  -CertStoreLocation "Cert:\CurrentUser\My" `
  -NotAfter (Get-Date).AddYears(5)
*CertName - Change this value to an apporicate name e.g. “CN=Trusted Macro Publisher”
3.	Sign each macro file with the certificate 
a.	In the Macro enabled excel file > Press “Alt + F11”
b.	Tools > Digital Signature > Choose > Select the Cert that was created in Step 2 > OK
c.	Save the file
4.	Send the signed files back to the users 
a.	Send the signed files back to the user 
b.	Tell them to replace their old file with this new signed version 
5.	Push the certificate to all devices via Intune 
a.	Export the certificate as .cer 
b.	Create a new policy
i.	Intune > Devices > Configuration > Create > Templates > Trusted Certificate 
ii.	Upload the .cer  
iii.	Destination store:  
iv.	Assign to all devices
c.	Intune pushes the certificate to all devices
6.	User opens the signed file
•	Their device already trusts the certificate (from step 4) 
•	Macro runs without being blocked 

