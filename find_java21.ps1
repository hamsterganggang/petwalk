# Java 21 설치 경로 찾기 스크립트

Write-Host "Java 21 설치 경로를 찾는 중..." -ForegroundColor Cyan
Write-Host ""

# 일반적인 설치 경로들
$possiblePaths = @(
    "C:\Program Files\Eclipse Adoptium\jdk-21*",
    "C:\Program Files\Java\jdk-21*",
    "C:\Program Files (x86)\Java\jdk-21*",
    "C:\Program Files\Microsoft\jdk-21*",
    "C:\Program Files\Amazon Corretto\jdk21*"
)

$foundPaths = @()

foreach ($pathPattern in $possiblePaths) {
    $resolved = Get-ChildItem $pathPattern -Directory -ErrorAction SilentlyContinue
    if ($resolved) {
        foreach ($dir in $resolved) {
            $javaExe = Join-Path $dir.FullName "bin\java.exe"
            if (Test-Path $javaExe) {
                # Java 버전 확인
                $versionOutput = & $javaExe -version 2>&1
                if ($versionOutput -match "21") {
                    $foundPaths += $dir.FullName
                    Write-Host "✓ Java 21을 찾았습니다: $($dir.FullName)" -ForegroundColor Green
                }
            }
        }
    }
}

if ($foundPaths.Count -eq 0) {
    Write-Host "Java 21을 찾을 수 없습니다." -ForegroundColor Red
    Write-Host ""
    Write-Host "수동으로 확인하는 방법:" -ForegroundColor Yellow
    Write-Host "1. 파일 탐색기에서 'C:\Program Files' 폴더 확인" -ForegroundColor Yellow
    Write-Host "2. 'Eclipse Adoptium' 또는 'Java' 폴더 찾기" -ForegroundColor Yellow
    Write-Host "3. 'jdk-21'로 시작하는 폴더 찾기" -ForegroundColor Yellow
    Write-Host ""
    $manualPath = Read-Host "Java 21 설치 경로를 직접 입력하세요 (또는 Enter로 취소)"
    if ($manualPath -and (Test-Path $manualPath)) {
        $javaExe = Join-Path $manualPath "bin\java.exe"
        if (Test-Path $javaExe) {
            $foundPaths += $manualPath
            Write-Host "✓ 경로 확인됨: $manualPath" -ForegroundColor Green
        } else {
            Write-Host "오류: 해당 경로에 java.exe가 없습니다." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "취소되었습니다." -ForegroundColor Red
        exit 1
    }
}

if ($foundPaths.Count -gt 0) {
    $selectedPath = $foundPaths[0]
    if ($foundPaths.Count -gt 1) {
        Write-Host ""
        Write-Host "여러 Java 21 설치를 찾았습니다:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $foundPaths.Count; $i++) {
            Write-Host "$($i + 1). $($foundPaths[$i])" -ForegroundColor Cyan
        }
        $choice = Read-Host "사용할 경로 번호를 선택하세요 (1-$($foundPaths.Count))"
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $foundPaths.Count) {
            $selectedPath = $foundPaths[[int]$choice - 1]
        }
    }
    
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "Java 21 경로: $selectedPath" -ForegroundColor Green
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host ""
    Write-Host "이 경로를 android/gradle.properties 파일에 추가하세요:" -ForegroundColor Yellow
    Write-Host ""
    $gradlePath = $selectedPath -replace '\\', '/'
    Write-Host "org.gradle.java.home=$gradlePath" -ForegroundColor White
    Write-Host ""
    
    # gradle.properties 파일 업데이트 제안
    $update = Read-Host "gradle.properties 파일을 자동으로 업데이트하시겠습니까? (Y/N)"
    if ($update -eq 'Y' -or $update -eq 'y') {
        $gradlePropsPath = "android\gradle.properties"
        if (Test-Path $gradlePropsPath) {
            $content = Get-Content $gradlePropsPath -Raw
            $gradlePath = $selectedPath -replace '\\', '/'
            
            if ($content -match "org\.gradle\.java\.home") {
                $content = $content -replace "org\.gradle\.java\.home=.*", "org.gradle.java.home=$gradlePath"
            } else {
                $content += "`norg.gradle.java.home=$gradlePath"
            }
            
            Set-Content -Path $gradlePropsPath -Value $content
            Write-Host "✓ gradle.properties 파일이 업데이트되었습니다!" -ForegroundColor Green
        } else {
            Write-Host "오류: gradle.properties 파일을 찾을 수 없습니다." -ForegroundColor Red
        }
    }
}
