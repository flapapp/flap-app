// Скрипт для видалення всіх челенджів з Firestore
// Запустіть в Firebase Console > Firestore > Запити

// Видалити всі челенджі
db.collection("challenges").get().then(function(querySnapshot) {
    querySnapshot.forEach(function(doc) {
        doc.ref.delete();
    });
    console.log("Всі челенджі видалено");
});

// Видалити всі submissions
db.collection("submissions").get().then(function(querySnapshot) {
    querySnapshot.forEach(function(doc) {
        doc.ref.delete();
    });
    console.log("Всі submissions видалено");
});

// Видалити всі votes (якщо є окрема колекція)
db.collection("votes").get().then(function(querySnapshot) {
    querySnapshot.forEach(function(doc) {
        doc.ref.delete();
    });
    console.log("Всі votes видалено");
});

console.log("Скрипт завершено. Перевірте Firestore Console.");
