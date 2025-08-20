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
