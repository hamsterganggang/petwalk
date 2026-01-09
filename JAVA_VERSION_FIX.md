# Java 버전 호환성 문제 해결 가이드

## 문제
Java 24 (class file major version 68)가 Gradle과 호환되지 않습니다.

## 해결 방법

### 방법 1: Java 17 또는 21 설치 (권장)

1. **Java 다운로드**
   - [Adoptium (OpenJDK)](https://adoptium.net/) 접속
   - Java 17 LTS 또는 Java 21 LTS 다운로드
   - Windows x64 Installer 선택

2. **설치 후 경로 확인**
   - 일반적인 설치 경로: `C:\Program Files\Eclipse Adoptium\jdk-17.x.x-hotspot` 또는 `C:\Program Files\Eclipse Adoptium\jdk-21.x.x-hotspot`

3. **gradle.properties 설정**
   
   `android/gradle.properties` 파일에 다음 줄 추가:
   ```properties
   org.gradle.java.home=C:/Program Files/Eclipse Adoptium/jdk-17.0.12.7-hotspot
   ```
   
   또는 Java 21인 경우:
   ```properties
   org.gradle.java.home=C:/Program Files/Eclipse Adoptium/jdk-21.0.5.11-hotspot
   ```
   
   **주의**: 실제 설치된 경로로 수정하세요!

4. **signingReport 다시 실행**
   ```powershell
   cd android
   .\gradlew signingReport
   ```

### 방법 2: JAVA_HOME 환경 변수 설정

Java 17/21을 설치한 후:

1. **시스템 환경 변수 설정**
   - Win + R → `sysdm.cpl` → Enter
   - "고급" 탭 → "환경 변수" 클릭
   - "시스템 변수"에서 "새로 만들기"
   - 변수 이름: `JAVA_HOME`
   - 변수 값: `C:\Program Files\Eclipse Adoptium\jdk-17.0.12.7-hotspot` (실제 경로)

2. **PowerShell 재시작 후 실행**
   ```powershell
   cd android
   .\gradlew signingReport
   ```

### 방법 3: 현재 세션에서만 JAVA_HOME 설정

```powershell
# Java 17/21 설치 경로로 변경
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.12.7-hotspot"

cd android
.\gradlew signingReport
```

## 빠른 설치 링크

- **Java 17 LTS**: https://adoptium.net/temurin/releases/?version=17
- **Java 21 LTS**: https://adoptium.net/temurin/releases/?version=21

## 설치 확인

Java 설치 후 버전 확인:
```powershell
# 설치된 Java 버전 확인
java -version

# JAVA_HOME 확인
$env:JAVA_HOME
```

## 참고사항

- Java 17과 Java 21 모두 Gradle과 호환됩니다
- Java 21이 더 최신이지만, Java 17도 충분히 안정적입니다
- 여러 Java 버전을 설치해도 문제없습니다 (JAVA_HOME으로 선택 가능)
