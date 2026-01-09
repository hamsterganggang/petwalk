# Firebase 설정 가이드

## 1. Firebase Console에서 앱 등록

### Android 앱 등록
1. [Firebase Console](https://console.firebase.google.com/u/1/project/petwalk-14a2a/overview?hl=ko)에 접속
2. 프로젝트 개요 페이지에서 "Android 앱 추가" 클릭
3. Android 패키지 이름 입력: `com.example.petwalk`
4. 앱 닉네임 입력 (선택사항): `PetWalk`
5. `google-services.json` 파일 다운로드
6. 다운로드한 파일을 `android/app/` 디렉토리에 복사

### Windows 앱 등록 (선택사항)
1. Firebase Console에서 "Windows 앱 추가" 클릭
2. 앱 닉네임 입력: `PetWalk`
3. `firebase_options.dart` 파일 업데이트가 필요합니다

## 2. firebase_options.dart 파일 업데이트

Firebase Console에서 앱을 등록한 후, `lib/firebase_options.dart` 파일의 다음 값을 업데이트해야 합니다:

### Android 설정
- `YOUR_ANDROID_API_KEY`: Firebase Console > 프로젝트 설정 > 일반 > Android 앱의 API 키
- `YOUR_ANDROID_APP_ID`: Firebase Console > 프로젝트 설정 > 일반 > Android 앱의 앱 ID
- `YOUR_MESSAGING_SENDER_ID`: Firebase Console > 프로젝트 설정 > 클라우드 메시징 > 발신자 ID

### Web 설정 (선택사항)
- `YOUR_WEB_API_KEY`: Firebase Console > 프로젝트 설정 > 일반 > 웹 앱의 API 키
- `YOUR_WEB_APP_ID`: Firebase Console > 프로젝트 설정 > 일반 > 웹 앱의 앱 ID

### FlutterFire CLI 사용 (권장)
다음 명령어를 실행하여 자동으로 설정할 수 있습니다:

```bash
flutterfire configure --project=petwalk-14a2a --platforms=android,windows
```

**주의**: FlutterFire CLI를 사용하려면:
1. Firebase CLI 설치 및 로그인 필요
2. PATH 환경 변수에 `C:\Users\iamga\AppData\Local\Pub\Cache\bin` 추가 필요

## 3. google-services.json 파일 위치 확인

다운로드한 `google-services.json` 파일은 다음 위치에 있어야 합니다:
```
android/app/google-services.json
```

## 4. Firebase 보안 규칙 배포

Firestore 및 Storage 보안 규칙을 Firebase에 배포하려면:

```bash
firebase deploy --only firestore:rules,storage:rules
```

## 5. 테스트

앱을 실행하여 Firebase 연결을 확인하세요:
```bash
flutter run
```

콘솔에 "Firebase initialized successfully" 메시지가 표시되면 성공입니다.

## 참고사항

- Firebase 초기화 실패 시에도 앱은 정상적으로 실행됩니다 (예외 처리 포함)
- Firestore 오프라인 모드가 활성화되어 있어 인터넷 없이도 작동 가능합니다
- 보안 규칙은 개발 중이므로 모든 인증된 사용자에게 읽기/쓰기 권한을 부여합니다
