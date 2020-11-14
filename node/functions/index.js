const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Creates a new user with an HTTP request
exports.createUser = functions.https.onRequest(async (req, res) => {

    // Create new user given query parameters
    admin.auth().createUser({
        displayName: req.query.name,
        email: req.query.email,
        password: req.query.password
    })
    .then(userRecord => res.json({result: `Successfully created new user: ${userRecord.uid}`}))
    .catch(error=> res.json({result: `Error creating new user: ${error}`}));
});

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
