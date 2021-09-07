param (
    [Parameter(Mandatory=$true)]
    $QueryPath,
    $OutputType,
    $OutputPath
)

Function Get-Token {
    if (-Not (test-path ".\creds.secret")) {
        $tenantId = Read-Host "Enter Tenant ID"
        $clientId =  Read-Host "Enter Application ID"
        $appSecret = Read-Host "Enter Client Secret" -AsSecureString | ConvertFrom-SecureString
        Set-Content -Path .\creds.secret -Value "$tenantId,$clientId,$appSecret"
    }
    $tenantId, $clientId, $appSecret = (Get-Content '.\creds.secret').Split(',')
    $appSecret = $appSecret | ConvertTo-SecureString

    # This code gets the application context token
    $resourceAppIdUri = 'https://api.security.microsoft.com'
    $oAuthUri = "https://login.windows.net/$tenantId/oauth2/token"
    $authBody = [Ordered] @{
        resource = $resourceAppIdUri
        client_id = $clientId
        client_secret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($appSecret))
        grant_type = 'client_credentials'
    }
    try {
        $authResponse = Invoke-RestMethod -Method Post -Uri $oAuthUri -Body $authBody -ErrorAction Stop
        return $authResponse.access_token
    }
    catch {
        Write-Host "Provided credentials did not work... Please try again." -ForegroundColor Yellow
        Write-Host $PSItem.ErrorDetails.Message -ForegroundColor Red
        Remove-Item -Path .\creds.secret
        Exit
    }
}

Function Get-Query {
    $queryRaw = Get-Content $QueryPath
    foreach ($line in $queryRaw) {
        $Query = $Query + $line
    }
    return $Query
}

Function Invoke-Query {
    param (
        [string]$token,
        [string]$query
    )
    $queryURI = 'https://api.security.microsoft.com/api/advancedhunting/run'
    $queryHeaders =  [Ordered] @{
        'Content-Type' = 'application/json'
        Accept = 'application/json'
        Authorization = "Bearer $token"
    }

    $body = ConvertTo-Json -InputObject @{ 'Query' = $query }

    try {
        $webResponse = Invoke-WebRequest -Method Post -Uri $queryURI -Headers $queryHeaders -Body $body -ErrorAction Stop
        return $webResponse | ConvertFrom-Json
    }
    catch {
        Write-Host "Provided query did not work... Please try again." -ForegroundColor Yellow
        Write-Host $PSItem.ErrorDetails.Message -ForegroundColor Red
        Exit
    }
}

$token = Get-Token

$parsedQuery = Get-Query
$response = Invoke-Query $token $parsedQuery

$response.Results
# $response.Schema

# TO DO - OutputType and OutputPath