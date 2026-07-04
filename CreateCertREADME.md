# How to Add a Macro File as a Trusted Publisher

This guide walks through the process of signing a macro-enabled Excel file with a trusted certificate and deploying that trust to all devices via Intune, so the macro runs without being blocked.

## 1. Collect the Macro Files

- Ask the user to send you their macro-enabled files (e.g. `.xlsm`).

## 2. Create a Signing Certificate

Run the following PowerShell script **once** to generate a self-signed code-signing certificate:

```powershell
$cert = New-SelfSignedCertificate `
  -Subject "CN=*CertName" `
  -KeyUsage DigitalSignature `
  -Type CodeSigningCert `
  -CertStoreLocation "Cert:\CurrentUser\My" `
  -NotAfter (Get-Date).AddYears(5)
```

> **Note:** Replace `*CertName` with an appropriate name, e.g. `CN=Trusted Macro Publisher`.

## 3. Sign the Macro File

1. Open the macro-enabled Excel file.
2. Press **Alt + F11** to open the VBA editor.
3. Go to **Tools → Digital Signature**.
4. Click **Choose**, select the certificate created in Step 2, then click **OK**.
5. Save the file.

## 4. Return the Signed File

1. Send the signed file back to the user.
2. Instruct them to replace their old file with the new signed version.

## 5. Deploy the Certificate via Intune

### 5.1 Export the Certificate

- Export the certificate as a `.cer` file.

### 5.2 Create a New Intune Policy

1. Navigate to **Intune → Devices → Configuration → Create → Templates → Trusted Certificate**.
2. Upload the `.cer` file.
3. Set the **Destination store**.
4. Assign the policy to **all devices**.

### 5.3 Push to Devices

- Intune pushes the certificate to all assigned devices automatically.

## 6. End Result

- The user opens the signed file.
- Their device already trusts the certificate (deployed in Step 5).
- The macro runs without being blocked.
