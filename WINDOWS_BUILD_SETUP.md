# Windows 빌드 설정 가이드

## 문제
CMake가 Visual Studio 2019를 찾지 못하여 Windows 빌드가 실패합니다.

## 해결 방법

### 방법 1: Visual Studio 설치 (권장)

Windows 앱을 빌드하려면 Visual Studio가 필요합니다.

#### Visual Studio 2022 설치 (권장)

1. **Visual Studio 2022 다운로드**
   - [Visual Studio 2022 Community](https://visualstudio.microsoft.com/downloads/) 다운로드 (무료)
   - 또는 Visual Studio 2022 Build Tools만 설치

2. **필수 워크로드 선택**
   설치 시 다음 워크로드를 선택하세요:
   - **"Desktop development with C++"** (C++를 사용한 데스크톱 개발)
   - **"Windows 10/11 SDK** (최신 버전)

3. **설치 후 확인**
   ```powershell
   # Visual Studio 설치 확인
   & "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat"
   ```

#### Visual Studio 2019 설치 (대안)

Visual Studio 2019가 필요한 경우:
- [Visual Studio 2019 Community](https://visualstudio.microsoft.com/vs/older-downloads/) 다운로드
- "Desktop development with C++" 워크로드 설치

### 방법 2: Android만 빌드 (임시 해결책)

Windows 빌드가 필요하지 않다면 Android만 빌드할 수 있습니다:

```powershell
# Android만 빌드
flutter build apk

# 또는 Android 앱 실행
flutter run -d android
```

### 방법 3: Visual Studio Build Tools만 설치

전체 Visual Studio가 필요하지 않다면 Build Tools만 설치:

1. [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022) 다운로드
2. "C++ build tools" 워크로드 선택
3. Windows 10/11 SDK 선택

## 설치 확인

Visual Studio 설치 후:

```powershell
# Flutter doctor로 확인
flutter doctor -v

# Windows 빌드 테스트
flutter build windows
```

## 참고사항

- **Visual Studio Community**: 개인 개발자 및 소규모 팀에게 무료
- **Build Tools**: Visual Studio IDE 없이 빌드만 필요한 경우
- **Windows SDK**: Windows 앱 빌드에 필수

## 문제 해결

### "Visual Studio not found" 오류

1. Visual Studio가 설치되어 있는지 확인
2. 환경 변수 확인:
   ```powershell
   $env:VSINSTALLDIR
   ```
3. Flutter doctor 실행:
   ```powershell
   flutter doctor -v
   ```

### CMake Generator 오류

Visual Studio가 설치되어 있어도 CMake가 찾지 못하는 경우:

1. Visual Studio Developer Command Prompt에서 실행
2. 또는 환경 변수 설정:
   ```powershell
   $env:CMAKE_GENERATOR = "Visual Studio 17 2022"
   ```

## 빠른 다운로드 링크

- **Visual Studio 2022 Community**: https://visualstudio.microsoft.com/downloads/
- **Visual Studio Build Tools**: https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022
