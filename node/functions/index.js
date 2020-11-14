const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Example cloud function
// exports.helloWorld = functions.https.onRequest((request, response) => {
//   functions.logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

// Creates a new document for each new user
exports.createDoc = functions.auth.user().onCreate(user => {

    // Data to be stored in document
    const userData = {
        name: user.displayName,
        email: user.email
    };

    // Add user data to new document
    return admin.firestore().doc(`users/${user.uid}`).set(userData);
});
