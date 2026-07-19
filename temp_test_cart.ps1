$creds = @(
  @{ u='admin1'; p='@Alburagh@iq@123' }
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