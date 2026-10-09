param(
    [string]$ToEmail,
    [string]$CcEmail,
    [string]$Subject,
    [string]$emailBodyBase64,
    [string]$FromEmail,
    [string]$AzureCredentialsJson
)

$ErrorActionPreference = "Stop"

function Get-Recipients([string]$addresses) {
    # Split comma/semicolon separated addresses and skip empty entries
    return @($addresses -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique | ForEach-Object {
            @{ emailAddress = @{ address = $_ } }
        })
}

# Step 1: Decode the Base64 email body
if ([string]::IsNullOrEmpty($emailBodyBase64)) {
    Write-Host "::Error::emailBodyBase64 is empty."
    exit 1
}
$BodyContent = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($emailBodyBase64))
Write-Host "Decoded email body."

$ToRecipients = Get-Recipients $ToEmail
if (-not $ToRecipients) {
    Write-Host "::Error::No recipients specified in ToEmail."
    exit 1
}
$CcRecipients = Get-Recipients $CcEmail

# Step 2: Parse Azure credentials
try {
    $AzureCredentials = $AzureCredentialsJson | ConvertFrom-Json
    Write-Host "Parsed Azure credentials successfully."
}
catch {
    Write-Host "::Error::Error parsing AzureCredentialsJson: $($_.Exception.Message)"
    exit 1
}

# Step 3: Get a Microsoft Graph token (client credentials)
try {
    $tokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$($AzureCredentials.tenantId)/oauth2/v2.0/token" -Body @{
        client_id     = $AzureCredentials.clientId
        client_secret = $AzureCredentials.clientSecret
        scope         = 'https://graph.microsoft.com/.default'
        grant_type    = 'client_credentials'
    }
    Write-Host "Connected to Microsoft Graph."
}
catch {
    Write-Host "::Error::Error connecting to Microsoft Graph: $($_.Exception.Message)"
    exit 1
}

# Step 4: Send the email
$message = @{
    subject      = $Subject
    toRecipients = $ToRecipients
    body         = @{
        contentType = "HTML"
        content     = $BodyContent
    }
}
if ($CcRecipients) {
    $message.ccRecipients = $CcRecipients
}
$requestBody = @{ message = $message; saveToSentItems = $true } | ConvertTo-Json -Depth 10

try {
    Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/v1.0/users/$([uri]::EscapeDataString($FromEmail))/sendMail" -Headers @{ Authorization = "Bearer $($tokenResponse.access_token)" } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($requestBody)) | Out-Null
    Write-Host "Email sent to $ToEmail successfully."
}
catch {
    Write-Host "::Error::Error sending email: $($_.Exception.Message)"
    exit 1
}
