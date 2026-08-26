# GE_Sky E2E verification: register -> 2FA setup/enable -> 2FA login -> vendors -> order splitting
$ErrorActionPreference = 'Stop'
$base = if ($args.Count -ge 1) { $args[0] } else { "http://localhost:4100/api/v1" }

function Invoke-Api {
  param($Method, $Uri, $Body, $Session, $Headers)
  $params = @{ Method = $Method; Uri = $Uri; UseBasicParsing = $true; ErrorAction = 'Stop' }
  if ($Body) { $params.ContentType = 'application/json'; $params.Body = ($Body | ConvertTo-Json -Depth 8) }
  if ($Session) { $params.WebSession = $Session }
  if ($Headers) { $params.Headers = $Headers }
  try {
    $r = Invoke-WebRequest @params
    return @{ ok = $true; status = [int]$r.StatusCode; json = ($r.Content | ConvertFrom-Json); headers = $r.Headers }
  } catch {
    $resp = $_.Exception.Response
    if ($resp) {
      $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
      return @{ ok = $false; status = [int]$resp.StatusCode; body = $sr.ReadToEnd() }
    }
    throw
  }
}

# --- TOTP (RFC 6238, SHA1, 30s) ---
function ConvertFrom-Base32 {
  param([string]$s)
  $alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
  $bits = ""
  foreach ($ch in $s.ToUpper().Replace(" ", "").Replace("=", "").ToCharArray()) {
    $idx = $alphabet.IndexOf($ch)
    if ($idx -ge 0) { $bits += [Convert]::ToString($idx, 2).PadLeft(5, '0') }
  }
  $bytes = New-Object byte[] ([math]::Floor($bits.Length / 8))
  for ($i = 0; $i -lt $bytes.Length; $i++) {
    $bytes[$i] = [Convert]::ToByte($bits.Substring($i * 8, 8), 2)
  }
  return ,$bytes
}

function Get-TotpCode {
  param([string]$Secret, [long]$UnixTime = 0)
  if ($UnixTime -eq 0) { $UnixTime = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
  $counter = [long][math]::Floor($UnixTime / 30)
  # 64-bit big-endian counter (exactly 8 bytes)
  $msgBytes = [BitConverter]::GetBytes($counter)
  [array]::Reverse($msgBytes)
  $hmac = New-Object System.Security.Cryptography.HMACSHA1 (,(ConvertFrom-Base32 $Secret))
  $hash = $hmac.ComputeHash($msgBytes)
  $offset = $hash[$hash.Length - 1] -band 0x0F
  $code = (([int]$hash[$offset] -band 0x7F) -shl 24) -bor ([int]$hash[$offset+1] -shl 16) -bor ([int]$hash[$offset+2] -shl 8) -bor [int]$hash[$offset+3]
  return ("{0:D6}" -f ($code % 1000000))
}

$results = @()
function Add-Result { param($Name, $Pass, $Detail = "") $script:results += [PSCustomObject]@{ Test = $Name; Pass = $Pass; Detail = $Detail }; Write-Host "$(if($Pass){'PASS'}else{'FAIL'}) | $Name | $Detail" }

# ===== 1. Register =====
$email = "e2e-$(Get-Random)@test.dz"
$password = "SecureP@ss123"
$sess = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r = Invoke-Api -Method Post -Uri "$base/auth/register" -Body @{ name = "E2E Tester"; email = $email; password = $password; companyName = "E2E Test Co" } -Session $sess
Add-Result "Register returns 201 + OWNER user" ($r.ok -and $r.status -eq 201 -and $r.json.user.role -eq 'OWNER') "status=$($r.status)"
if ($r.ok) {
  $setCookie = $r.headers['Set-Cookie']
  Add-Result "Register sets auth cookies" ($null -ne $setCookie -and ($setCookie -join ' ') -match 'access_token') ""
}

# ===== 2. Login =====
$r = Invoke-Api -Method Post -Uri "$base/auth/login" -Body @{ email = $email; password = $password }
Add-Result "Login returns tokens/user" ($r.ok -and $r.json.user.email -eq $email) "status=$($r.status)"
$userId = $r.json.user.id

# ===== 3. 2FA setup =====
$r = Invoke-Api -Method Post -Uri "$base/auth/2fa/setup" -Session $sess
Add-Result "2FA setup returns secret+QR" ($r.ok -and $r.json.secret -and $r.json.qrCodeDataUrl -match '^data:image/png;base64,') "status=$($r.status)"
$secret = $r.json.secret

# ===== 4. 2FA enable with valid TOTP =====
$code = Get-TotpCode -Secret $secret
$r = Invoke-Api -Method Post -Uri "$base/auth/2fa/enable" -Body @{ code = $code } -Session $sess
Add-Result "2FA enable accepts valid TOTP" ($r.ok -and $r.status -eq 200) "status=$($r.status) $(if(-not $r.ok){$r.body})"

# wrong code must fail
$bad = Invoke-Api -Method Post -Uri "$base/auth/2fa/enable" -Body @{ code = "000000" } -Session $sess
Add-Result "2FA enable rejects invalid code" (-not $bad.ok -and ($bad.status -eq 403 -or $bad.status -eq 400)) "status=$($bad.status)"

# ===== 5. Login now requires 2FA =====
$r = Invoke-Api -Method Post -Uri "$base/auth/login" -Body @{ email = $email; password = $password }
Add-Result "Login returns requiresTwoFactor=true, no tokens" ($r.ok -and $r.json.requiresTwoFactor -eq $true -and -not $r.json.tokens) "status=$($r.status)"

# ===== 6. Complete login with TOTP (retry across window boundary) =====
$loginOk = $false
foreach ($attempt in 1..3) {
  $code = Get-TotpCode -Secret $secret
  $r = Invoke-Api -Method Post -Uri "$base/auth/login/2fa" -Body @{ email = $email; password = $password; code = $code }
  if ($r.ok -and $r.json.user.id -eq $userId) { $loginOk = $true; break }
  # wait for next TOTP window before retrying
  Start-Sleep -Seconds (31 - ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() % 30))
}
Add-Result "login/2fa completes with valid code" $loginOk "status=$($r.status)"

# ===== 7. Create two vendors =====
$v1 = Invoke-Api -Method Post -Uri "$base/vendors" -Body @{ name = "Vendor Alpha"; contactEmail = "alpha@vendors.dz"; commissionRate = 0.10 } -Session $sess
$v2 = Invoke-Api -Method Post -Uri "$base/vendors" -Body @{ name = "Vendor Beta"; contactEmail = "beta@vendors.dz"; commissionRate = 0.15 } -Session $sess
Add-Result "Create vendor Alpha" ($v1.ok -and $v1.json.id) "status=$($v1.status) $(if(-not $v1.ok){$v1.body})"
Add-Result "Create vendor Beta" ($v2.ok -and $v2.json.id) "status=$($v2.status) $(if(-not $v2.ok){$v2.body})"
$vendorA = $v1.json.id
$vendorB = $v2.json.id

# ===== 8. Products for each vendor =====
$p1 = Invoke-Api -Method Post -Uri "$base/products" -Body @{ name = "Alpha Widget A"; price = 1000; stock = 50; vendorId = $vendorA; status = 'ACTIVE' } -Session $sess
$p2 = Invoke-Api -Method Post -Uri "$base/products" -Body @{ name = "Beta Gadget B"; price = 500; stock = 80; vendorId = $vendorB; status = 'ACTIVE' } -Session $sess
Add-Result "Create product A (vendor Alpha)" ($p1.ok -and $p1.json.id) "status=$($p1.status) $(if(-not $p1.ok){$p1.body})"
Add-Result "Create product B (vendor Beta)" ($p2.ok -and $p2.json.id) "status=$($p2.status) $(if(-not $p2.ok){$p2.body})"
$prodA = $p1.json.id
$prodB = $p2.json.id

# ===== 9. Multi-vendor order -> parent + sub-orders =====
$o = Invoke-Api -Method Post -Uri "$base/orders" -Body @{
  customerName = "E2E Buyer"
  customerEmail = "buyer@test.dz"
  customerPhone = "+213555000111"
  subtotal = 4000
  total = 4000
  items = @(
    @{ productId = $prodA; productName = "Alpha Widget A"; sku = "SKU-A-001"; price = 1000; quantity = 2 },
    @{ productId = $prodB; productName = "Beta Gadget B"; sku = "SKU-B-001"; price = 500; quantity = 4 }
  )
} -Session $sess
Add-Result "Multi-vendor order created" ($o.ok) "status=$($o.status) $(if(-not $o.ok){$o.body})"
if ($o.ok) {
  $orderId = $o.json.id
  $subCount = @($o.json.subOrders).Count
  Add-Result "Order split into 2 sub-orders" ($subCount -eq 2) "subOrders=$subCount"
  # totals: subtotal=2000+2000=4000; each group exactly 2000 => proportional allocation exact
  $subs = @($o.json.subOrders)
  $sumSubTotal = ($subs | Measure-Object -Property subtotal -Sum).Sum
  Add-Result "Sub-order subtotals sum to parent" ($sumSubTotal -eq $o.json.subtotal) "parent=$($o.json.subtotal) sum=$sumSubTotal"
  $vendorsInSubs = ($subs | ForEach-Object { $_.vendorId } | Sort-Object -Unique).Count
  Add-Result "Each sub-order has distinct vendor" ($vendorsInSubs -eq 2) "distinctVendors=$vendorsInSubs"

  # single-vendor order should NOT split
  $o2 = Invoke-Api -Method Post -Uri "$base/orders" -Body @{
    customerName = "E2E Buyer"
    customerEmail = "buyer@test.dz"
    customerPhone = "+213555000111"
    subtotal = 1000
    total = 1000
    items = @( @{ productId = $prodA; productName = "Alpha Widget A"; sku = "SKU-A-001"; price = 1000; quantity = 1 } )
  } -Session $sess
  Add-Result "Single-vendor order stays unsplit" ($o2.ok -and (-not $o2.json.subOrders -or @($o2.json.subOrders).Count -eq 0)) "status=$(if($o2.ok){$o2.status}else{$o2.body})"

  # fetch parent order includes sub-orders
  $g = Invoke-Api -Method Get -Uri "$base/orders/$orderId" -Session $sess
  Add-Result "GET order/:id includes subOrders" ($g.ok -and @($g.json.subOrders).Count -eq 2) "status=$($g.status)"
}

Write-Host "`n===== SUMMARY ====="
$pass = ($results | Where-Object Pass).Count
Write-Host "$pass / $($results.Count) passed"
$results | Format-Table -AutoSize | Out-String | Write-Host
