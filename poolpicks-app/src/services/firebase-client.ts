import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { initializeFirestore } from 'firebase/firestore';
import { firebasePublicConfig } from '../firebase.public-config';

export const firebaseApp = initializeApp(firebasePublicConfig);
export const firebaseAuth = getAuth(firebaseApp);
export const firestore = initializeFirestore(firebaseApp, {
  ignoreUndefinedProperties: true,
});
