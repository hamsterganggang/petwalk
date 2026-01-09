# Google Sign-In 오류 해결 가이드

## 문제
`PlatformException(sign_in_failed, com.google.android.gms.common.api.Api10)` 오류가 발생합니다.

## 원인
`google-services.json` 파일에 OAuth 클라이언트 ID가 설정되지 않았습니다.

## 해결 방법

### 1단계: Firebase Console에서 OAuth 클라이언트 ID 생성

1. [Firebase Console](https://console.firebase.google.com/u/1/project/petwalk-14a2a/settings/general) 접속
2. **프로젝트 설정** > **일반** 탭
3. **내 앱** 섹션에서 Android 앱 선택
4. **SHA 인증서 지문** 확인:
   - SHA-1: `7A:66:08:E5:77:12:28:83:37:81:58:8E:57:3F:44:86:3D:4C:82:9D`
   - 등록되어 있는지 확인

### 2단계: Google Cloud Console에서 OAuth 클라이언트 ID 생성

1. [Google Cloud Console](https://console.cloud.google.com/apis/credentials?project=petwalk-14a2a) 접속
2. **API 및 서비스** > **사용자 인증 정보**
3. **+ 사용자 인증 정보 만들기** > **OAuth 클라이언트 ID**
4. **애플리케이션 유형**: Android 선택
5. **이름**: PetWalk Android (또는 원하는 이름)
6. **패키지 이름**: `com.example.petwalk`
7. **SHA-1 인증서 지문**: `7A:66:08:E5:77:12:28:83:37:81:58:8E:57:3F:44:86:3D:4C:82:9D`
8. **만들기** 클릭
9. 생성된 **클라이언트 ID** 복사

### 3단계: Firebase Console에서 OAuth 클라이언트 ID 연결

1. Firebase Console > 프로젝트 설정 > 일반
2. Android 앱 섹션에서 **SHA 인증서 지문 추가** 클릭
3. SHA-1 값이 등록되어 있는지 확인
4. **google-services.json 다시 다운로드**

### 4단계: google-services.json 파일 업데이트

1. Firebase Console에서 새로 다운로드한 `google-services.json` 파일
2. `android/app/` 디렉토리에 복사 (기존 파일 덮어쓰기)
3. 파일에 `oauth_client` 배열이 채워져 있는지 확인

### 5단계: 앱 재빌드

```powershell
flutter clean
flutter pub get
flutter run
```

## 대안: 서버 클라이언트 ID 직접 지정

OAuth 클라이언트 ID가 자동으로 설정되지 않는 경우, 코드에서 직접 지정할 수 있습니다:

`lib/services/google_signin_handler.dart` 파일 수정:

```dart
final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: [
    'email',
    'profile',
  ],
  // 서버 클라이언트 ID 추가 (Web 클라이언트 ID)
  serverClientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com',
);
```

**Web 클라이언트 ID 찾기:**
1. Google Cloud Console > 사용자 인증 정보
2. **웹 애플리케이션** 타입의 OAuth 클라이언트 ID 찾기
3. 클라이언트 ID 복사

## 확인 사항 체크리스트

- [ ] SHA-1 인증서 지문이 Firebase Console에 등록됨
- [ ] Google Cloud Console에 Android OAuth 클라이언트 ID 생성됨
- [ ] google-services.json 파일이 최신 버전으로 업데이트됨
- [ ] google-services.json에 oauth_client 배열이 채워져 있음
- [ ] 앱을 재빌드함

## 참고

- OAuth 클라이언트 ID 생성 후 몇 분 정도 시간이 걸릴 수 있습니다
- google-services.json 파일을 업데이트한 후 반드시 앱을 재빌드해야 합니다
- 디버그와 릴리즈 빌드는 각각 다른 SHA-1 지문이 필요할 수 있습니다
