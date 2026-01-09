# SHA-1 인증서 지문 확인 스크립트

# 일반적인 keytool 경로들
$possiblePaths = @(
    "C:\Program Files\Java\jdk-*\bin\keytool.exe",
    "C:\Program Files\Java\jre-*\bin\keytool.exe",
    "C:\Program Files (x86)\Java\jdk-*\bin\keytool.exe",
    "C:\Program Files (x86)\Java\jre-*\bin\keytool.exe",
    "$env:JAVA_HOME\bin\keytool.exe",
    "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe",
    "C:\Program Files\Android\Android Studio\jre\bin\keytool.exe"
)

$keytoolPath = $null

# 가능한 경로들 확인
foreach ($path in $possiblePaths) {
    $resolved = Resolve-Path $path -ErrorAction SilentlyContinue
    if ($resolved) {
        $keytoolPath = $resolved[0].Path
        Write-Host "keytool을 찾았습니다: $keytoolPath" -ForegroundColor Green
        break
    }
}

# keytool을 찾지 못한 경우
if (-not $keytoolPath) {
    Write-Host "keytool을 찾을 수 없습니다." -ForegroundColor Red
    Write-Host ""
    Write-Host "다음 중 하나를 시도해보세요:" -ForegroundColor Yellow
    Write-Host "1. Java JDK를 설치하세요: https://adoptium.net/" -ForegroundColor Yellow
    Write-Host "2. JAVA_HOME 환경 변수를 설정하세요" -ForegroundColor Yellow
    Write-Host "3. keytool의 전체 경로를 직접 입력하세요" -ForegroundColor Yellow
    Write-Host ""
    
    # 사용자에게 직접 경로 입력 요청
    $manualPath = Read-Host "keytool.exe의 전체 경로를 입력하세요 (또는 Enter로 취소)"
    if ($manualPath -and (Test-Path $manualPath)) {
        $keytoolPath = $manualPath
    } else {
        Write-Host "취소되었습니다." -ForegroundColor Red
        exit 1
    }
}

# debug.keystore 경로
$keystorePath = "$env:USERPROFILE\.android\debug.keystore"

# keystore 파일 존재 확인
if (-not (Test-Path $keystorePath)) {
    Write-Host "경고: debug.keystore 파일을 찾을 수 없습니다: $keystorePath" -ForegroundColor Yellow
    Write-Host "Flutter 앱을 한 번 실행하면 자동으로 생성됩니다." -ForegroundColor Yellow
    exit 1
}

# SHA-1 인증서 지문 확인
Write-Host ""
Write-Host "SHA-1 인증서 지문을 확인하는 중..." -ForegroundColor Cyan
Write-Host ""

& $keytoolPath -list -v -keystore $keystorePath -alias androiddebugkey -storepass android -keypass android | Select-String -Pattern "SHA1|SHA-1" -Context 0,1

Write-Host ""
Write-Host "위의 SHA1 또는 SHA-1 값을 복사하여 Firebase Console에 등록하세요." -ForegroundColor Green
