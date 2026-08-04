# Reads credentials from environment variables instead of hardcoding them,
# so this script can stay in version control without leaking a live admin
# password. Set them before running:
#   $env:ALBURAGH_TEST_USER = 'admin1'
#   $env:ALBURAGH_TEST_PASS = '...'
if (-not $env:ALBURAGH_TEST_USER -or -not $env:ALBURAGH_TEST_PASS) {
    Write-Error "Set `$env:ALBURAGH_TEST_USER and `$env:ALBURAGH_TEST_PASS before running this script."
    exit 1
}

$creds = @(
  @{ u=$env:ALBURAGH_TEST_USER; p=$env:ALBURAGH_TEST_PASS }
)

$base = 'https://alburagh.com/wp-json/alburagh/v1'

foreach ($c in $creds) {
  try {
    $body = @{ username=$c.u; password=$c.p } | ConvertTo-Json
    $resp = Invoke-RestMethod -Uri "$base/login" -Method Post -ContentType 'application/json' -Body $body -ErrorAction Stop
    $token = $resp.token
    Write-Host "LOGIN OK for $($c.u)"
    
    # Check debug cart meta
    Write-Host "`n=== DEBUG CART META ===" 
    $debug = Invoke-RestMethod -Uri "$base/debug/cart" -Method Get -Headers @{ 'Authorization' = "Bearer $token" }
    Write-Host ($debug | ConvertTo-Json -Depth 10)

    Write-Host "`n=== CART API RESPONSE ==="
    $cart = Invoke-RestMethod -Uri "$base/cart" -Method Get -Headers @{ 'Authorization' = "Bearer $token" } -ErrorAction Stop
    Write-Host ($cart | ConvertTo-Json -Depth 10)
    
    break
  } catch {
    Write-Host "ERROR: $($_.Exception.Message)"
  }
}