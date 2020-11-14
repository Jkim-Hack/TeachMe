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

// Checks if the given user credentials are valid
exports.checkLogin = functions.https.onRequest(async (req, res) => {

    // Search user email, return information if user is found
    admin.auth().getUserByEmail(req.query.email)
    .then(userRecord => {
        const passwordCheck = userRecord.toJSON().passwordHash.substring(userRecord.toJSON().passwordHash.indexOf("password=") + 9) === req.query.password;
        res.json({result: passwordCheck, uid: passwordCheck ? userRecord.uid : "none"});
    })
    .catch(error => res.json({result: false, error: `${error}`}));
});
