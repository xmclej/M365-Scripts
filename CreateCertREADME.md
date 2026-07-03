How to Add Macro File as Trusted Publisher

1. User sends you the macro files
. Ask the user to send you their macro files via Teams

2. Create a certificate to sign the files
. Run the PowerShell script below to create the certificate (only needs to be done once)

$cert = New-SelfSignedCertificate -Subject "CN=*CertName"
-KeyUsage DigitalSignature -Type CodeSigningCert
-CertStoreLocation "Cert:\CurrentUser\My" `
-NotAfter (Get-Date).AddYears(5)

*CertName - Change this to an appropriate name e.g. CN=Site Safe Macro

3. Sign each macro file with the certificate
. Open the macro enabled Excel file
. Press Alt + F11 to open the VBA editor
. Go to Tools > Digital Signature > Choose
. Select the certificate created in Step 2
. Click OK and save the file

4. Send the signed files back to the users
. Send the signed files back to the user via Teams
. Tell them to replace their old file with this new signed version

5. Push the certificate to all devices via Intune
. Export the certificate as a .cer file
. Go to Intune > Devices > Configuration > Create > Templates > Trusted Certificate
. Upload the .cer file
. Assign to all devices
. Intune will automatically push the certificate to all devices silently

6. User opens the signed file
. Their device already trusts the certificate from Step 5
. Macro runs without being blocked


NOTE: If the macro code is edited after signing the file must be re-signed. Data changes such as cell values and formatting do not require re-signing.