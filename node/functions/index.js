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
        .catch(err => res.json({result: false, error: `Error creating new user: ${err}`}));
});

// Creates a new document for each new user
exports.createDoc = functions.auth.user().onCreate(async user => {

    // Create data to be stored in document
    const userData = {
        name: user.displayName,
        email: user.email,
        classID: (await generateClassID())
    };

    // Add user data to new document
    return admin.firestore().doc(`users/${user.uid}`).set(userData);
});

// Generates a unique class ID for each new user
const generateClassID = async () => {

    // Get class ID document and new ID number
    const ID = admin.firestore().doc("users/_classID");
    const num = (await ID.get()).data().last + 1;

    // Update class ID in database and return new ID
    await ID.update({last: num});
    return num;
}

// Gets class ID given a user UID
exports.getClassID = functions.https.onRequest(async (req, res) => {

    // Attempt to get class ID
    admin.firestore().doc(`users/${req.query.uid}`).get()
        .then(doc => res.json({result: true, classID: doc.data().classID}))
        .catch(err => res.json({result: false, error: `${err}`}));
});

// Moves specified file to a folder for the given user
exports.moveFile = functions.https.onRequest(async (req, res) => {

    // Create new file name
    const newFileName = path.join(req.query.uid, fileName);

    // Rename given file
    admin.storage().bucket().file(req.query.name).rename(newFileName)
        .then(() => res.json({result: true}))
        .catch(err => res.json({result: false, error: `${err}`}));
});
