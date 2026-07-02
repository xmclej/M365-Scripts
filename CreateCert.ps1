$cert = New-SelfSignedCertificate `
  -Subject "CN=CertName" `
  -KeyUsage DigitalSignature `
  -Type CodeSigningCert `
  -CertStoreLocation "Cert:\CurrentUser\My" `
  -NotAfter (Get-Date).AddYears(5)