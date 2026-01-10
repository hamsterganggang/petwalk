const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();

// 배포 지역을 서울로 설정
setGlobalOptions({ region: "asia-northeast3" });

// 1. 좋아요 알림
exports.sendlikenotification = onDocumentCreated({
    document: "likes/{likeId}",
    // 만약 서울 리전에서 안 오면 이 부분을 생략하거나 'us-central1'로 시도해볼 수 있습니다.
}, async (event) => {
    console.log("🔔 좋아요 트리거 시작! 문서 ID:", event.params.likeId);
    
    const data = event.data.data();
    if (!data) {
        console.log("❌ 데이터가 없습니다.");
        return;
    }

    const { walkId, userId: likerId } = data;
    console.log(`📝 좋아요 데이터: walkId=${walkId}, likerId=${likerId}`);

    try {
        // 1. 산책 정보 가져오기
        const walkDoc = await admin.firestore().collection("walks").doc(walkId).get();
        if (!walkDoc.exists) {
            console.log("❌ 산책 기록(walks)이 존재하지 않습니다.");
            return;
        }
        const walkData = walkDoc.data();
        const receiverId = walkData.userId; // 글 작성자 ID

        if (likerId === receiverId) {
            console.log("⏭️ 본인 글 좋아요이므로 중단.");
            return;
        }

        // 2. 수신자(글 작성자) 토큰 조회
        const userDoc = await admin.firestore().collection("profiles").doc(receiverId).get();
        if (!userDoc.exists) {
            console.log(`❌ 수신자(${receiverId}) 프로필이 없습니다.`);
            return;
        }
        const userData = userDoc.data();
        const token = userData.fcmToken;

        if (!token) {
            console.log("❌ 수신자의 fcmToken이 없습니다.");
            return;
        }

        // 3. 알림 전송
        const likerDoc = await admin.firestore().collection("profiles").doc(likerId).get();
        const likerNickname = likerDoc.exists ? likerDoc.data().nickname : "누군가";

        const message = {
            notification: {
                title: "좋아요 알림",
                body: `${likerNickname}님이 당신의 산책 기록을 좋아합니다!`,
            },
            token: token,
        };

        const response = await admin.messaging().send(message);
        console.log("✅ 알림 전송 성공! 메시지 ID:", response);
    } catch (error) {
        console.error("🔥 좋아요 알림 처리 중 에러:", error);
    }
});

// 2. 팔로우 알림
exports.sendfollownotification = onDocumentCreated("follows/{followId}", async (event) => {
    console.log("🔔 팔로우 트리거 시작! 문서 ID:", event.params.followId);
    const data = event.data.data();
    if (!data) return;

    const { followerId, followingId } = data;

    try {
        const userDoc = await admin.firestore().collection("profiles").doc(followingId).get();
        const userData = userDoc.data();
        const token = userData?.fcmToken;

        if (!token) {
            console.log("❌ 수신자 토큰 없음");
            return;
        }

        const followerDoc = await admin.firestore().collection("profiles").doc(followerId).get();
        const followerNickname = followerDoc.exists ? followerDoc.data().nickname : "누군가";

        const message = {
            notification: {
                title: "팔로우 알림",
                body: `${followerNickname}님이 당신을 팔로우하기 시작했습니다!`,
            },
            token: token,
        };

        await admin.messaging().send(message);
        console.log("✅ 팔로우 알림 전송 성공!");
    } catch (error) {
        console.error("🔥 팔로우 알림 에러:", error);
    }
});