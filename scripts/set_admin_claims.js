/**
 * Usage:
 * 1) Place a Firebase service account JSON at scripts/serviceAccountKey.json
 * 2) Edit scripts/admin_uids.json with an array of UIDs to make admin
 * 3) Run: node scripts/set_admin_claims.js
 *
 * This script sets { admin: true } custom claim for each uid.
 */
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const keyPath = path.join(__dirname, 'serviceAccountKey.json');
if (!fs.existsSync(keyPath)) {
  console.error('serviceAccountKey.json not found in scripts/. Create it from Firebase Console.');
  process.exit(1);
}
const uidsPath = path.join(__dirname, 'admin_uids.json');
if (!fs.existsSync(uidsPath)) {
  console.error('admin_uids.json not found in scripts/. Create it with an array of UIDs.');
  process.exit(1);
}

const serviceAccount = require(keyPath);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const uids = require(uidsPath);
if (!Array.isArray(uids) || uids.length === 0) {
  console.error('admin_uids.json must be a non-empty array of UIDs.');
  process.exit(1);
}

(async () => {
  for (const uid of uids) {
    try {
      console.log(`Setting admin claim for ${uid} ...`);
      await admin.auth().setCustomUserClaims(uid, { admin: true });
      console.log(`Success: ${uid}`);
    } catch (e) {
      console.error(`Failed for ${uid}:`, e.message || e);
    }
  }
  console.log('Done. Note: custom claims take effect after user refreshes token / signs in again.');
  process.exit(0);
})();
