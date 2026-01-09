# signingReport 태스크 실행 가이드

## signingReport란?

Android Gradle의 태스크로, 앱 서명에 사용되는 인증서의 SHA-1, SHA-256 지문을 확인할 수 있습니다.

## 실행 방법

### 방법 1: Android 디렉토리에서 직접 실행 (권장)

```powershell
# 프로젝트 루트에서
cd android
.\gradlew signingReport
```

### 방법 2: 프로젝트 루트에서 실행

```powershell
# 프로젝트 루트에서
cd android; .\gradlew signingReport
```

### 방법 3: Flutter 명령어 사용

```powershell
# Flutter 명령어로 실행 (간접적)
flutter build apk --debug
# 빌드 후 출력에서 SHA-1 확인 가능
```

## 출력 예시

실행 성공 시 다음과 같은 출력을 볼 수 있습니다:

```
Variant: debug
Config: debug
Store: C:\Users\YourName\.android\debug.keystore
Alias: AndroidDebugKey
MD5: XX:XX:XX:...
SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
SHA-256: XX:XX:XX:...
Valid until: ...
```

## 현재 문제: Java 버전 호환성

현재 Java 24가 설치되어 있어서 Gradle과 호환되지 않습니다.

### 해결 방법

#### 옵션 1: Java 17 또는 21 설치 (권장)

1. **Java 다운로드**
   - [Adoptium (OpenJDK)](https://adoptium.net/) 접속
   - Java 17 또는 Java 21 LTS 버전 다운로드
   - 설치

2. **Gradle에서 특정 Java 버전 사용하도록 설정**

   `android/gradle.properties` 파일에 추가:
   ```properties
   org.gradle.java.home=C:/Program Files/Java/jdk-21
   ```

   또는 환경 변수 설정:
   ```powershell
   $env:JAVA_HOME = "C:\Program Files\Java\jdk-21"
   ```

3. **signingReport 다시 실행**
   ```powershell
   cd android
   .\gradlew signingReport
   ```

#### 옵션 2: JAVA_HOME 환경 변수 설정

```powershell
# 현재 세션에만 적용
$env:JAVA_HOME = "C:\Program Files\Java\jdk-21"

# 영구적으로 설정하려면
# 시스템 환경 변수에서 JAVA_HOME 추가
```

#### 옵션 3: Gradle Wrapper에서 Java 버전 지정

`android/gradle/wrapper/gradle-wrapper.properties` 확인 후, 호환되는 Gradle 버전 사용

## SHA-1 값 찾기

출력에서 다음 형식의 값을 찾으세요:

```
SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
```

또는

```
SHA-1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
```

## Firebase Console에 등록

1. [Firebase Console](https://console.firebase.google.com/u/1/project/petwalk-14a2a/settings/general) 접속
2. 프로젝트 설정 > 일반 탭
3. Android 앱 섹션에서 "SHA 인증서 지문 추가" 클릭
4. 위에서 확인한 SHA-1 값을 붙여넣기
5. 저장

## 참고사항

- **디버그 키스토어**: 개발 중에는 `debug.keystore` 사용
- **릴리즈 키스토어**: 앱스토어 배포 시 별도의 릴리즈 키스토어 필요
- **SHA-256**: 일부 서비스에서는 SHA-256도 필요할 수 있음

## 문제 해결

### "Unsupported class file major version 68" 오류

Java 24는 아직 Gradle과 완전히 호환되지 않습니다. Java 17 또는 21을 사용하세요.

### "gradlew not found" 오류

Android 디렉토리로 이동했는지 확인하세요:
```powershell
cd android
```

### "debug.keystore not found" 오류

Flutter 앱을 한 번 실행하면 자동으로 생성됩니다:
```powershell
flutter run
```
