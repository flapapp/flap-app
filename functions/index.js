const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Відправка FCM-запрошень при створенні челенджу
exports.sendChallengeInvitations = functions.firestore
  .document('challenges/{challengeId}')
  .onCreate(async (snap, context) => {
    const challenge = snap.data();
    const challengeId = context.params.challengeId;
    
    let targetTokens = [];
    
    try {
      // Визначаємо аудиторію
      switch (challenge.audience) {
        case 'friends':
          // Отримуємо друзів створювача
          const creatorDoc = await admin.firestore()
            .collection('users')
            .doc(challenge.creatorId)
            .get();
          
          if (creatorDoc.exists) {
            const friends = creatorDoc.data().friends || [];
            if (friends.length > 0) {
              const friendDocs = await admin.firestore()
                .collection('users')
                .where(admin.firestore.FieldPath.documentId(), 'in', friends)
                .get();
              
              friendDocs.forEach(doc => {
                const tokens = doc.data().deviceTokens || [];
                targetTokens.push(...tokens);
              });
            }
          }
          break;
          
        case 'city':
          // Всі користувачі з того ж міста
          const cityUsers = await admin.firestore()
            .collection('users')
            .where('city', '==', challenge.city)
            .get();
          
          cityUsers.forEach(doc => {
            const tokens = doc.data().deviceTokens || [];
            targetTokens.push(...tokens);
          });
          break;
          
        case 'country':
          // Всі користувачі України (можна додати поле country)
          const countryUsers = await admin.firestore()
            .collection('users')
            .limit(1000) // обмежуємо для продуктивності
            .get();
          
          countryUsers.forEach(doc => {
            const tokens = doc.data().deviceTokens || [];
            targetTokens.push(...tokens);
          });
          break;
          
        case 'world':
          // Всі користувачі (обмежено)
          const allUsers = await admin.firestore()
            .collection('users')
            .limit(500)
            .get();
          
          allUsers.forEach(doc => {
            const tokens = doc.data().deviceTokens || [];
            targetTokens.push(...tokens);
          });
          break;
      }
      
      // Видаляємо дублікати та недійсні токени
      targetTokens = [...new Set(targetTokens)].filter(token => token && token.length > 0);
      
      if (targetTokens.length === 0) {
        console.log('No valid tokens found for challenge:', challengeId);
        return;
      }
      
      // Відправляємо пуш-повідомлення
      const message = {
        notification: {
          title: 'Новий челендж!',
          body: `${challenge.creatorName} створив челендж: ${challenge.title}`,
        },
        data: {
          type: 'challenge_invitation',
          challengeId: challengeId,
          challengeTitle: challenge.title,
          creatorName: challenge.creatorName,
        },
        tokens: targetTokens.slice(0, 500), // FCM ліміт 500 токенів за раз
      };
      
      const response = await admin.messaging().sendMulticast(message);
      console.log(`Sent ${response.successCount} notifications for challenge ${challengeId}`);
      
      // Логуємо помилки
      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.error(`Failed to send to token ${targetTokens[idx]}:`, resp.error);
          }
        });
      }
      
    } catch (error) {
      console.error('Error sending challenge invitations:', error);
    }
  });

// Автоматичне оновлення статусів челенджів
exports.updateChallengeStatuses = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async (context) => {
    const now = new Date();
    const challengesRef = admin.firestore().collection('challenges');
    
    try {
      // Оновлюємо статуси активних челенджів
      const activeChallenges = await challengesRef
        .where('isActive', '==', true)
        .where('status', '!=', 'completed')
        .get();
      
      const batch = admin.firestore().batch();
      let updatesCount = 0;
      
      activeChallenges.forEach(doc => {
        const challenge = doc.data();
        const submissionDeadline = challenge.submissionDeadline.toDate();
        const votingDeadline = challenge.votingDeadline.toDate();
        const endDate = challenge.endDate.toDate();
        
        let newStatus = challenge.status;
        
        // Перевіряємо переходи між етапами
        if (challenge.status === 'recruiting' && now >= submissionDeadline) {
          newStatus = 'submission';
        } else if (challenge.status === 'submission' && now >= votingDeadline) {
          newStatus = 'voting';
        } else if (challenge.status === 'voting' && now >= endDate) {
          newStatus = 'completed';
        }
        
        if (newStatus !== challenge.status) {
          batch.update(doc.ref, { status: newStatus });
          updatesCount++;
        }
      });
      
      if (updatesCount > 0) {
        await batch.commit();
        console.log(`Updated ${updatesCount} challenge statuses`);
      }
      
    } catch (error) {
      console.error('Error updating challenge statuses:', error);
    }
  });

// Відправка push нотифікацій
exports.sendPushNotification = functions.firestore
  .document('pushNotifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notificationData = snap.data();
    const notificationId = context.params.notificationId;
    
    try {
      // Отримуємо FCM токен користувача
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(notificationData.userId)
        .get();
      
      if (!userDoc.exists) {
        console.log('User not found:', notificationData.userId);
        return;
      }
      
      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;
      const deviceTokens = Array.isArray(userData.deviceTokens) ? userData.deviceTokens.filter(Boolean) : [];

      if (fcmToken) {
        const message = {
          notification: { title: notificationData.title, body: notificationData.message },
          data: { ...notificationData.data, notificationId: notificationId },
          token: fcmToken,
        };
        const response = await admin.messaging().send(message);
        console.log('Successfully sent (single) push notification:', response);
      } else if (deviceTokens.length > 0) {
        const message = {
          notification: { title: notificationData.title, body: notificationData.message },
          data: { ...notificationData.data, notificationId: notificationId },
          tokens: deviceTokens.slice(0, 500),
        };
        const response = await admin.messaging().sendMulticast(message);
        console.log(`Successfully sent multicast: ${response.successCount}/${deviceTokens.length}`);
      } else {
        console.log('No FCM token(s) for user:', notificationData.userId);
        return;
      }

      // remove from queue after success
      await snap.ref.delete();
      
    } catch (error) {
      console.error('Error sending push notification:', error);
      
      // Позначаємо як помилку
      await snap.ref.update({
        error: error.message,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

// Автоматичне завершення челенджів
exports.finalizeChallenges = functions.pubsub
  .schedule('every 30 minutes')
  .onRun(async (context) => {
    const now = new Date();
    const challengesRef = admin.firestore().collection('challenges');
    
    try {
      // Знаходимо челенджі, які треба завершити
      const challengesToFinalize = await challengesRef
        .where('status', '==', 'voting')
        .where('votingDeadline', '<=', now)
        .get();
      
      console.log(`Found ${challengesToFinalize.size} challenges to finalize`);
      
      for (const doc of challengesToFinalize.docs) {
        const challengeId = doc.id;
        const challenge = doc.data();
        
        try {
          // Підрахувати результати
          const submissionScores = {};
          const submissionToUser = {};
          
          // Отримати інформацію про submissions
          const submissionsSnapshot = await admin.firestore()
            .collection('submissions')
            .where('challengeId', '==', challengeId)
            .get();
          
          submissionsSnapshot.forEach(submissionDoc => {
            const submission = submissionDoc.data();
            submissionToUser[submissionDoc.id] = submission.userId;
          });
          
          // Підрахувати середні оцінки
          if (challenge.submissionVotes) {
            Object.keys(challenge.submissionVotes).forEach(submissionId => {
              const votes = challenge.submissionVotes[submissionId];
              let totalScore = 0;
              let voteCount = 0;
              
              Object.values(votes).forEach(rating => {
                totalScore += rating;
                voteCount++;
              });
              
              if (voteCount > 0) {
                submissionScores[submissionId] = totalScore / voteCount;
              }
            });
          }
          
          // Сортувати за найвищими оцінками
          const sortedSubmissions = Object.entries(submissionScores)
            .sort(([,a], [,b]) => b - a);
          
          // Визначити переможців (топ 3)
          const winners = [];
          const prizes = [
            Math.round(challenge.prizePool * 0.5),  // 1st: 50%
            Math.round(challenge.prizePool * 0.3),  // 2nd: 30%
            Math.round(challenge.prizePool * 0.2),  // 3rd: 20%
          ];
          
          // Використовуємо batch для транзакційності
          const batch = admin.firestore().batch();
          
          // Виплатити призи
          for (let i = 0; i < 3 && i < sortedSubmissions.length; i++) {
            const [submissionId, score] = sortedSubmissions[i];
            const userId = submissionToUser[submissionId];
            
            if (userId) {
              winners.push(submissionId);
              const prizeAmount = prizes[i];
              
              // Нарахувати монети
              const userRef = admin.firestore().collection('users').doc(userId);
              batch.update(userRef, {
                coins: admin.firestore.FieldValue.increment(prizeAmount),
              });
              
              // Записати транзакцію
              const transactionRef = admin.firestore().collection('transactions').doc();
              batch.set(transactionRef, {
                userId: userId,
                type: 'challenge_prize',
                amount: prizeAmount,
                challengeId: challengeId,
                position: i + 1,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                description: `Приз за ${i + 1} місце в челенджі: ${challenge.title}`,
              });
              
              // Створити нотифікацію
              const notificationRef = admin.firestore().collection('notifications').doc();
              batch.set(notificationRef, {
                userId: userId,
                type: 'challengeResult',
                title: 'Результати челенджу!',
                message: `Ви зайняли ${i === 0 ? '🥇 1-е' : i === 1 ? '🥈 2-е' : '🥉 3-є'} місце в "${challenge.title}" і отримали ${prizeAmount} монет!`,
                data: {
                  challengeId: challengeId,
                  challengeTitle: challenge.title,
                  position: i + 1,
                  coinsWon: prizeAmount,
                },
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                isRead: false,
                actionUrl: `/challenge-details/${challengeId}`,
              });
              
              // Додати до черги push нотифікацій
              const pushRef = admin.firestore().collection('pushNotifications').doc();
              batch.set(pushRef, {
                userId: userId,
                title: 'Результати челенджу!',
                message: `Ви зайняли ${i === 0 ? '🥇 1-е' : i === 1 ? '🥈 2-е' : '🥉 3-є'} місце в "${challenge.title}"!`,
                data: {
                  type: 'challenge_result',
                  challengeId: challengeId,
                  position: i + 1,
                },
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
              });
            }
          }
          
          // Оновити статус челенджу
          batch.update(doc.ref, {
            status: 'completed',
            winners: winners,
            finalScores: submissionScores,
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          
          await batch.commit();
          console.log(`Successfully finalized challenge: ${challengeId}`);
          
        } catch (error) {
          console.error(`Error finalizing challenge ${challengeId}:`, error);
        }
      }
      
    } catch (error) {
      console.error('Error in finalizeChallenges:', error);
    }
  });

// Очищення старих нотифікацій (старші за 30 днів)
exports.cleanupOldNotifications = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    try {
      const oldNotifications = await admin.firestore()
        .collection('notifications')
        .where('createdAt', '<=', thirtyDaysAgo)
        .limit(500)
        .get();
      
      if (oldNotifications.empty) {
        console.log('No old notifications to delete');
        return;
      }
      
      const batch = admin.firestore().batch();
      oldNotifications.forEach(doc => {
        batch.delete(doc.ref);
      });
      
      await batch.commit();
      console.log(`Deleted ${oldNotifications.size} old notifications`);
      
    } catch (error) {
      console.error('Error cleaning up old notifications:', error);
    }
  });

// Cloud Function для прийняття запрошення в друзі
exports.acceptFriendRequest = functions.https.onCall(async (data, context) => {
  // Перевірка авторизації
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Користувач не авторизований');
  }

  const { requestId, accept } = data;
  const currentUserId = context.auth.uid;

  try {
    // Отримуємо запрошення
    const requestDoc = await admin.firestore()
      .collection('friend_requests')
      .doc(requestId)
      .get();

    if (!requestDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Запрошення не знайдено');
    }

    const request = requestDoc.data();

    // Перевірка що це запрошення для поточного користувача
    if (request.toUserId !== currentUserId) {
      throw new functions.https.HttpsError('permission-denied', 'Це не ваше запрошення');
    }

    // Перевірка статусу
    if (request.status !== 'pending') {
      throw new functions.https.HttpsError('failed-precondition', 'Запрошення вже оброблено');
    }

    const batch = admin.firestore().batch();
    const newStatus = accept ? 'accepted' : 'declined';

    // Оновлюємо статус запрошення
    batch.update(requestDoc.ref, {
      status: newStatus,
      respondedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (accept) {
      // Двостороння дружба: оновлюємо ОБОХ користувачів
      
      // 1. Той хто приймає (toUserId)
      const toUserRef = admin.firestore().collection('users').doc(request.toUserId);
      batch.update(toUserRef, {
        friends: admin.firestore.FieldValue.arrayUnion(request.fromUserId),
        friendsCount: admin.firestore.FieldValue.increment(1),
        coins: admin.firestore.FieldValue.increment(5),
      });

      // 2. Той хто відправляв (fromUserId)
      const fromUserRef = admin.firestore().collection('users').doc(request.fromUserId);
      batch.update(fromUserRef, {
        friends: admin.firestore.FieldValue.arrayUnion(request.toUserId),
        friendsCount: admin.firestore.FieldValue.increment(1),
      });

      // 3. Транзакція для того хто приймає
      batch.set(admin.firestore().collection('transactions').doc(), {
        userId: request.toUserId,
        type: 'friend_added',
        amount: 5,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        description: `Новий друг: ${request.fromUserName}`,
      });

      // 4. Транзакція для того хто відправляв
      batch.set(admin.firestore().collection('transactions').doc(), {
        userId: request.fromUserId,
        type: 'friend_request_accepted',
        amount: 0,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        description: `${request.toUserName} прийняв ваше запрошення в друзі`,
      });

      // 5. Сповіщення для того хто відправляв
      batch.set(admin.firestore().collection('notifications').doc(), {
        userId: request.fromUserId,
        type: 'friendRequestAccepted',
        title: 'Запрошення прийнято',
        message: `${request.toUserName} прийняв ваше запрошення в друзі`,
        data: {
          friendId: request.toUserId,
          friendName: request.toUserName,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
      });
    }

    // Виконуємо всі операції атомарно
    await batch.commit();

    return { success: true, message: accept ? 'Запрошення прийнято' : 'Запрошення відхилено' };

  } catch (error) {
    console.error('Error in acceptFriendRequest:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});