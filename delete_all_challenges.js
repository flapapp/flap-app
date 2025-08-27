const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
// Using project ID directly
admin.initializeApp({
  projectId: 'flap-app-5c0c2'
});

const db = admin.firestore();

async function deleteCollection(collectionRef, batchSize) {
  const query = collectionRef.limit(batchSize);

  return new Promise((resolve, reject) => {
    deleteQueryBatch(db, query, resolve, reject);
  });
}

async function deleteQueryBatch(db, query, resolve, reject) {
  const snapshot = await query.get();

  if (snapshot.size === 0) {
    resolve();
    return;
  }

  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });

  await batch.commit();
  process.nextTick(() => deleteQueryBatch(db, query, resolve, reject));
}

async function deleteAllChallenges() {
  console.log('🗑️  Starting deletion of all challenges and related data...');

  try {
    // Delete submissions
    const submissionsRef = db.collection('submissions');
    console.log('Deleting submissions...');
    await deleteCollection(submissionsRef, 100);
    console.log('✅ All submissions deleted.');

    // Delete challenges
    const challengesRef = db.collection('challenges');
    console.log('Deleting challenges...');
    await deleteCollection(challengesRef, 100);
    console.log('✅ All challenges deleted.');

    console.log('🎉 All challenge-related data deleted successfully!');
  } catch (error) {
    console.error('❌ Error deleting challenges:', error);
  } finally {
    process.exit();
  }
}

deleteAllChallenges();
