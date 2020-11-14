const functions = require('firebase-functions');
const admin = require('firebase-admin');
const path = require('path');

admin.initializeApp();

// Creates a new user with an HTTP request
exports.createUser = functions.https.onRequest(async (req, res) => {

    // Create new user given query parameters
    admin.auth().createUser({
        displayName: req.query.name,
        email: req.query.email,
        password: req.query.password
    })
    .then(userRecord => res.json({result: true, uid: `${userRecord.uid}`}))
    .catch(error => res.json({result: false, error: `Error creating new user: ${error}`}));
});

// Creates a new document for each new user
exports.createDoc = functions.auth.user().onCreate(user => {

    // Data to be stored in document
    const userData = {
        name: user.displayName,
        email: user.email
    };

    // Add user data to new document
    admin.firestore().doc(`users/${user.uid}`).set(userData)
    .then(() => console.log("Document successfully written."))
    .catch(console.error);
});

// Moves specified file to a folder for the given user
exports.moveFile = functions.https.onRequest(async (req, res) => {

    // Get necessary data
    const bucket = admin.storage().bucket();
    const fileName = req.query.name;
    const newFileName = path.join(req.query.uid, fileName);

    // Rename given file
    bucket.file(fileName).rename(newFileName)
    .then(() => res.json({result: true}))
    .catch(error => res.json({result: false, error: `${error}`}));
});
