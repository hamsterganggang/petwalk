# CMake Generator 설정 스크립트

Write-Host "Visual Studio 설치 확인 중..." -ForegroundColor Cyan

# Visual Studio 2022 경로 확인
$vs2022Path = "C:\Program Files\Microsoft Visual Studio\2022\Community"
$vs2022BuildTools = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"

# Visual Studio 2026 Insiders 경로 확인
$vs2026Path = "C:\Program Files\Microsoft Visual Studio\18\Insiders"

$vsPath = $null
$vsVersion = $null

if (Test-Path $vs2022Path) {
    $vsPath = $vs2022Path
    $vsVersion = "Visual Studio 17 2022"
    Write-Host "✓ Visual Studio 2022를 찾았습니다" -ForegroundColor Green
} elseif (Test-Path $vs2022BuildTools) {
    $vsPath = $vs2022BuildTools
    $vsVersion = "Visual Studio 17 2022"
    Write-Host "✓ Visual Studio 2022 Build Tools를 찾았습니다" -ForegroundColor Green
} elseif (Test-Path $vs2026Path) {
    $vsPath = $vs2026Path
    $vsVersion = "Visual Studio 18 2026"
    Write-Host "✓ Visual Studio 2026 Insiders를 찾았습니다 (프리릴리즈)" -ForegroundColor Yellow
} else {
    Write-Host "Visual Studio를 찾을 수 없습니다." -ForegroundColor Red
    Write-Host ""
    Write-Host "Visual Studio 2022 Community를 설치하세요:" -ForegroundColor Yellow
    Write-Host "https://visualstudio.microsoft.com/downloads/" -ForegroundColor Cyan
    exit 1
}

Write-Host ""
Write-Host "CMake Generator를 설정합니다..." -ForegroundColor Cyan
Write-Host "Generator: $vsVersion" -ForegroundColor Green
Write-Host ""

# 환경 변수 설정 (현재 세션)
$env:CMAKE_GENERATOR = $vsVersion

Write-Host "현재 세션에 CMAKE_GENERATOR 환경 변수를 설정했습니다." -ForegroundColor Green
Write-Host ""
Write-Host "이제 다음 명령어를 실행하세요:" -ForegroundColor Yellow
Write-Host "  flutter build windows" -ForegroundColor White
Write-Host ""
Write-Host "또는 Visual Studio Developer Command Prompt에서 실행하세요." -ForegroundColor Yellow
