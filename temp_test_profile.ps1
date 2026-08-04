# Diagnostic: prints the raw /profile response so we can see whether
# billing/shipping postcode is actually saved server-side, or whether the
# save is fine and the checkout page itself is failing to display it.
#   $env:ALBURAGH_TEST_USER = 'admin1'
#   $env:ALBURAGH_TEST_PASS = '...'
if (-not $env:ALBURAGH_TEST_USER -or -not $env:ALBURAGH_TEST_PASS) {
    Write-Error "Set `$env:ALBURAGH_TEST_USER and `$env:ALBURAGH_TEST_PASS before running this script."
    exit 1
}

$base = 'https://alburagh.com/wp-json/alburagh/v1'

$body = @{ username = $env:ALBURAGH_TEST_USER; password = $env:ALBURAGH_TEST_PASS } | ConvertTo-Json
$resp = Invoke-RestMethod -Uri "$base/login" -Method Post -ContentType 'application/json' -Body $body -ErrorAction Stop
$token = $resp.token
Write-Host "LOGIN OK for $($env:ALBURAGH_TEST_USER)"

Write-Host "`n=== PROFILE API RESPONSE ==="
$profile = Invoke-RestMethod -Uri "$base/profile" -Method Get -Headers @{ 'Authorization' = "Bearer $token" } -ErrorAction Stop
Write-Host ($profile | ConvertTo-Json -Depth 10)
