# 헤드리스 테스트 실행: powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $root "Godot_v4.7.2-stable_win64.exe"
$out = Join-Path $root "tests\out"
New-Item -ItemType Directory -Force $out | Out-Null
$code = 0

Start-Process -FilePath $godot -ArgumentList "--headless", "--path", "`"$root`"", "--import" -NoNewWindow -Wait `
	-RedirectStandardOutput "$out\import.txt" -RedirectStandardError "$out\import_err.txt"

foreach ($t in @("determinism_test", "stage_test")) {
	$p = Start-Process -FilePath $godot -ArgumentList "--headless", "--path", "`"$root`"", "--fixed-fps", "60", "--script", "res://tests/$t.gd" `
		-NoNewWindow -Wait -PassThru -RedirectStandardOutput "$out\$t.txt" -RedirectStandardError "$out\${t}_err.txt"
	Get-Content "$out\$t.txt" -Encoding utf8 | Where-Object { $_ -notmatch "^Godot Engine" }
	$errs = Get-Content "$out\${t}_err.txt" -Encoding utf8 | Where-Object { $_ -match "ERROR" }
	if ($errs) { Write-Host "-- $t 오류 출력 --"; $errs | Select-Object -First 20 }
	if ($p.ExitCode -ne 0 -or $errs) { $code = 1 }
}
# 입력·오프닝 테스트는 실제 창이 필요하다 (헤드리스에서는 GUI 입력 경로와 렌더링이 다름)
foreach ($t in @("input_test", "opening_shot")) {
	$p = Start-Process -FilePath $godot -ArgumentList "--path", "`"$root`"", "--script", "res://tests/$t.gd" `
		-NoNewWindow -Wait -PassThru -RedirectStandardOutput "$out\$t.txt" -RedirectStandardError "$out\${t}_err.txt"
	Get-Content "$out\$t.txt" -Encoding utf8 | Where-Object { $_ -match "PASS|FAIL|결과|==" }
	if ($p.ExitCode -ne 0) { $code = 1 }
}
exit $code
