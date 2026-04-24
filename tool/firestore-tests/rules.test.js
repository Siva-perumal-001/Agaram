// Firestore security-rules unit tests for Agaram.
//
// Run via:  cd tool/firestore-tests && npm test
// The npm script boots the Firestore emulator, applies ../../firestore.rules,
// and executes every case below. Adding a new rule = adding a case here.

import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  addDoc,
  collection,
  collectionGroup,
  getDocs,
  serverTimestamp,
  query,
  where,
} from 'firebase/firestore';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import {
  afterAll,
  beforeAll,
  beforeEach,
  describe,
  it,
  expect,
} from 'vitest';

const projectId = 'agaram-test';
const __dirname = dirname(fileURLToPath(import.meta.url));
const rulesPath = resolve(__dirname, '../../firestore.rules');

// Seed uids used across every test.
const PRESIDENT = 'pres_uid';
const ADMIN = 'admin_uid';
const MEMBER = 'member_uid';
const OTHER_MEMBER = 'other_member_uid';

// Event / task baseline data seeded before each test.
const EVENT_ID = 'evt_one';
const TASK_ID = 'task_one';
const QR_SECRET = 'qr-secret-aaaaaaaaa';
const CLOUDINARY_URL =
  'https://res.cloudinary.com/dttox49ht/image/upload/v1/agaram/test.jpg';
const NON_CLOUDINARY_URL = 'https://evil.example.com/fake.jpg';

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: readFileSync(rulesPath, 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

afterAll(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  // Seed user docs + a sample event + a sample pending task via the
  // admin-only bypass (rules disabled for setup).
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', PRESIDENT), {
      name: 'Pres',
      email: 'pres@club.test',
      role: 'admin',
      isPresident: true,
      position: 'president',
      active: true,
      stars: 0,
      joinedAt: new Date(),
    });
    await setDoc(doc(db, 'users', ADMIN), {
      name: 'Admin',
      email: 'admin@club.test',
      role: 'admin',
      isPresident: false,
      position: 'secretary',
      active: true,
      stars: 0,
      joinedAt: new Date(),
    });
    await setDoc(doc(db, 'users', MEMBER), {
      name: 'Member',
      email: 'member@club.test',
      role: 'member',
      isPresident: false,
      position: 'member',
      active: true,
      stars: 0,
      joinedAt: new Date(),
    });
    await setDoc(doc(db, 'users', OTHER_MEMBER), {
      name: 'Other',
      email: 'other@club.test',
      role: 'member',
      isPresident: false,
      position: 'member',
      active: true,
      stars: 0,
      joinedAt: new Date(),
    });
    await setDoc(doc(db, 'events', EVENT_ID), {
      title: 'Welcome Meet',
      description: 'kickoff',
      venue: 'Auditorium',
      date: new Date(),
      status: 'upcoming',
      kind: 'event',
      durationMinutes: 120,
      createdBy: ADMIN,
      qrSecret: QR_SECRET,
      tasksCount: 1,
      createdAt: new Date(),
    });
    await setDoc(doc(db, 'events', EVENT_ID, 'tasks', TASK_ID), {
      eventId: EVENT_ID,
      eventTitle: 'Welcome Meet',
      title: 'Bring banner',
      description: 'please',
      assignedTo: MEMBER,
      assignedToName: 'Member',
      status: 'pending',
      starsAwarded: 0,
      createdAt: new Date(),
    });
  });
});

// ───────── contexts ─────────
const unauthDb = () => testEnv.unauthenticatedContext().firestore();
const memberDb = () => testEnv.authenticatedContext(MEMBER).firestore();
const otherMemberDb = () =>
  testEnv.authenticatedContext(OTHER_MEMBER).firestore();
const adminDb = () => testEnv.authenticatedContext(ADMIN).firestore();
const presidentDb = () => testEnv.authenticatedContext(PRESIDENT).firestore();

// ════════════════════════════════════════════════════════════════════
//                              USERS
// ════════════════════════════════════════════════════════════════════
describe('users/{uid}', () => {
  describe('read', () => {
    it('member reads own profile → allow', async () => {
      await assertSucceeds(getDoc(doc(memberDb(), 'users', MEMBER)));
    });
    it('member reads another profile → allow (directory is public)', async () => {
      await assertSucceeds(getDoc(doc(memberDb(), 'users', OTHER_MEMBER)));
    });
    it('unauth reads profile → deny', async () => {
      await assertFails(getDoc(doc(unauthDb(), 'users', MEMBER)));
    });
  });

  describe('create', () => {
    it('admin creates new profile → allow', async () => {
      await assertSucceeds(
        setDoc(doc(adminDb(), 'users', 'new_uid'), {
          name: 'New',
          email: 'new@club.test',
          role: 'member',
          isPresident: false,
          position: 'member',
          active: true,
          stars: 0,
          joinedAt: new Date(),
        })
      );
    });
    it('member creates profile → deny', async () => {
      await assertFails(
        setDoc(doc(memberDb(), 'users', 'xx'), { name: 'X', role: 'member' })
      );
    });
    it('unauth creates profile → deny', async () => {
      await assertFails(
        setDoc(doc(unauthDb(), 'users', 'xx'), { name: 'X', role: 'member' })
      );
    });
  });

  describe('update — self branch (FND-02 allowlist)', () => {
    it('member updates own name → allow', async () => {
      await assertSucceeds(
        updateDoc(doc(memberDb(), 'users', MEMBER), { name: 'New Name' })
      );
    });
    it('member updates own phone → allow', async () => {
      await assertSucceeds(
        updateDoc(doc(memberDb(), 'users', MEMBER), { phone: '555' })
      );
    });
    it('member updates own photoUrl → allow', async () => {
      await assertSucceeds(
        updateDoc(doc(memberDb(), 'users', MEMBER), { photoUrl: CLOUDINARY_URL })
      );
    });
    it('member updates own lastReadNotificationsAt → allow', async () => {
      await assertSucceeds(
        updateDoc(doc(memberDb(), 'users', MEMBER), {
          lastReadNotificationsAt: serverTimestamp(),
        })
      );
    });
    it('member tries to change own stars → deny (FND-02)', async () => {
      await assertFails(
        updateDoc(doc(memberDb(), 'users', MEMBER), { stars: 999 })
      );
    });
    it('member tries to change own email → deny (FND-02)', async () => {
      await assertFails(
        updateDoc(doc(memberDb(), 'users', MEMBER), { email: 'x@x.com' })
      );
    });
    it('member tries to change own joinedAt → deny (FND-02)', async () => {
      await assertFails(
        updateDoc(doc(memberDb(), 'users', MEMBER), { joinedAt: new Date(0) })
      );
    });
    it('member tries to promote self to admin → deny', async () => {
      await assertFails(
        updateDoc(doc(memberDb(), 'users', MEMBER), { role: 'admin' })
      );
    });
    it('member tries to set isPresident → deny', async () => {
      await assertFails(
        updateDoc(doc(memberDb(), 'users', MEMBER), { isPresident: true })
      );
    });
    it('member tries to reactivate self → deny', async () => {
      await assertFails(
        updateDoc(doc(memberDb(), 'users', MEMBER), { active: false })
      );
    });
    it('member tries to change someone else (non-self) → deny', async () => {
      await assertFails(
        updateDoc(doc(memberDb(), 'users', OTHER_MEMBER), { name: 'Hacked' })
      );
    });
  });

  describe('update — admin branch', () => {
    it('admin changes a member role → allow', async () => {
      await assertSucceeds(
        updateDoc(doc(adminDb(), 'users', MEMBER), { role: 'admin' })
      );
    });
    it('admin changes a member position → allow', async () => {
      await assertSucceeds(
        updateDoc(doc(adminDb(), 'users', MEMBER), { position: 'secretary' })
      );
    });
    it('admin flips active → allow', async () => {
      await assertSucceeds(
        updateDoc(doc(adminDb(), 'users', MEMBER), { active: false })
      );
    });
    it('admin increments stars (used by approveTask tx) → allow', async () => {
      await assertSucceeds(
        updateDoc(doc(adminDb(), 'users', MEMBER), { stars: 3 })
      );
    });
    it('admin tries to flip isPresident → deny (president-only)', async () => {
      await assertFails(
        updateDoc(doc(adminDb(), 'users', MEMBER), { isPresident: true })
      );
    });
  });

  describe('update — president branch', () => {
    it('president flips isPresident on another admin → allow', async () => {
      await assertSucceeds(
        updateDoc(doc(presidentDb(), 'users', ADMIN), { isPresident: true })
      );
    });
  });

  describe('delete', () => {
    it('president deletes → allow', async () => {
      await assertSucceeds(
        deleteDoc(doc(presidentDb(), 'users', OTHER_MEMBER))
      );
    });
    it('admin (non-president) deletes → deny', async () => {
      await assertFails(deleteDoc(doc(adminDb(), 'users', OTHER_MEMBER)));
    });
    it('member deletes → deny', async () => {
      await assertFails(deleteDoc(doc(memberDb(), 'users', OTHER_MEMBER)));
    });
  });
});

// ════════════════════════════════════════════════════════════════════
//                              EVENTS
// ════════════════════════════════════════════════════════════════════
describe('events/{eventId}', () => {
  it('signed-in reads → allow', async () => {
    await assertSucceeds(getDoc(doc(memberDb(), 'events', EVENT_ID)));
  });
  it('unauth reads → deny', async () => {
    await assertFails(getDoc(doc(unauthDb(), 'events', EVENT_ID)));
  });
  it('admin creates event → allow', async () => {
    await assertSucceeds(
      setDoc(doc(adminDb(), 'events', 'new_evt'), {
        title: 'X',
        status: 'upcoming',
        date: new Date(),
        createdBy: ADMIN,
      })
    );
  });
  it('member creates event → deny', async () => {
    await assertFails(
      setDoc(doc(memberDb(), 'events', 'new_evt'), { title: 'X' })
    );
  });
  it('admin updates event → allow', async () => {
    await assertSucceeds(
      updateDoc(doc(adminDb(), 'events', EVENT_ID), { status: 'ongoing' })
    );
  });
  it('member updates event → deny', async () => {
    await assertFails(
      updateDoc(doc(memberDb(), 'events', EVENT_ID), { status: 'ongoing' })
    );
  });
  it('admin deletes event → allow', async () => {
    await assertSucceeds(deleteDoc(doc(adminDb(), 'events', EVENT_ID)));
  });
  it('member deletes event → deny', async () => {
    await assertFails(deleteDoc(doc(memberDb(), 'events', EVENT_ID)));
  });
});

// ════════════════════════════════════════════════════════════════════
//                              TASKS
// ════════════════════════════════════════════════════════════════════
describe('events/{eventId}/tasks/{taskId}', () => {
  it('signed-in reads → allow', async () => {
    await assertSucceeds(
      getDoc(doc(memberDb(), 'events', EVENT_ID, 'tasks', TASK_ID))
    );
  });
  it('admin creates task → allow', async () => {
    await assertSucceeds(
      addDoc(collection(adminDb(), 'events', EVENT_ID, 'tasks'), {
        title: 'New',
        assignedTo: MEMBER,
        status: 'pending',
      })
    );
  });
  it('member creates task → deny', async () => {
    await assertFails(
      addDoc(collection(memberDb(), 'events', EVENT_ID, 'tasks'), {
        title: 'New',
        assignedTo: MEMBER,
        status: 'pending',
      })
    );
  });
  it('admin deletes task → allow', async () => {
    await assertSucceeds(
      deleteDoc(doc(adminDb(), 'events', EVENT_ID, 'tasks', TASK_ID))
    );
  });
  it('member deletes task → deny', async () => {
    await assertFails(
      deleteDoc(doc(memberDb(), 'events', EVENT_ID, 'tasks', TASK_ID))
    );
  });

  describe('update — admin', () => {
    it('admin updates any field → allow', async () => {
      await assertSucceeds(
        updateDoc(doc(adminDb(), 'events', EVENT_ID, 'tasks', TASK_ID), {
          status: 'approved',
          reviewedBy: ADMIN,
          reviewedAt: serverTimestamp(),
          starsAwarded: 3,
        })
      );
    });
  });

  describe('update — assignee submission (FND-03)', () => {
    it('assignee submits pending → submitted with allowed fields → allow', async () => {
      await assertSucceeds(
        updateDoc(doc(memberDb(), 'events', EVENT_ID, 'tasks', TASK_ID), {
          proofUrl: CLOUDINARY_URL,
          proofType: 'image',
          memberNote: 'done',
          status: 'submitted',
          submittedAt: serverTimestamp(),
        })
      );
    });
    it('assignee submits rejected → submitted (resubmission) → allow', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(
          doc(ctx.firestore(), 'events', EVENT_ID, 'tasks', TASK_ID),
          { status: 'rejected', reviewNote: 'try again' }
        );
      });
      await assertSucceeds(
        updateDoc(doc(memberDb(), 'events', EVENT_ID, 'tasks', TASK_ID), {
          proofUrl: CLOUDINARY_URL,
          proofType: 'image',
          status: 'submitted',
          submittedAt: serverTimestamp(),
        })
      );
    });
    it('assignee tries to forge reviewNote → deny (FND-03)', async () => {
      await assertFails(
        updateDoc(doc(memberDb(), 'events', EVENT_ID, 'tasks', TASK_ID), {
          proofUrl: CLOUDINARY_URL,
          proofType: 'image',
          status: 'submitted',
          submittedAt: serverTimestamp(),
          reviewNote: 'I say good',
        })
      );
    });
    it('assignee tries to forge reviewedBy → deny', async () => {
      await assertFails(
        updateDoc(doc(memberDb(), 'events', EVENT_ID, 'tasks', TASK_ID), {
          proofUrl: CLOUDINARY_URL,
          proofType: 'image',
          status: 'submitted',
          submittedAt: serverTimestamp(),
          reviewedBy: MEMBER,
        })
      );
    });
    it('assignee tries to forge reviewedAt → deny', async () => {
      await assertFails(
        updateDoc(doc(memberDb(), 'events', EVENT_ID, 'tasks', TASK_ID), {
          proofUrl: CLOUDINARY_URL,
          proofType: 'image',
          status: 'submitted',
          submittedAt: serverTimestamp(),
          reviewedAt: serverTimestamp(),
        })
      );
    });
    it('assignee tries to change starsAwarded → deny', async () => {
      await assertFails(
        updateDoc(doc(memberDb(), 'events', EVENT_ID, 'tasks', TASK_ID), {
          status: 'submitted',
          submittedAt: serverTimestamp(),
          starsAwarded: 99,
        })
      );
    });
    it('non-assignee submits on behalf of assignee → deny', async () => {
      await assertFails(
        updateDoc(doc(otherMemberDb(), 'events', EVENT_ID, 'tasks', TASK_ID), {
          proofUrl: CLOUDINARY_URL,
          proofType: 'image',
          status: 'submitted',
          submittedAt: serverTimestamp(),
        })
      );
    });
    it('assignee cannot edit an already-approved task → deny', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await updateDoc(
          doc(ctx.firestore(), 'events', EVENT_ID, 'tasks', TASK_ID),
          { status: 'approved' }
        );
      });
      await assertFails(
        updateDoc(doc(memberDb(), 'events', EVENT_ID, 'tasks', TASK_ID), {
          proofUrl: CLOUDINARY_URL,
          proofType: 'image',
          status: 'submitted',
          submittedAt: serverTimestamp(),
        })
      );
    });
  });

  describe('collection-group read', () => {
    it('member can query all tasks via CG → allow (intentional — FND-15)', async () => {
      await assertSucceeds(
        getDocs(
          query(
            collectionGroup(memberDb(), 'tasks'),
            where('assignedTo', '==', MEMBER)
          )
        )
      );
    });
    it('unauth CG query → deny', async () => {
      await assertFails(
        getDocs(collectionGroup(unauthDb(), 'tasks'))
      );
    });
  });
});

// ════════════════════════════════════════════════════════════════════
//                           ATTENDANCE (FND-04)
// ════════════════════════════════════════════════════════════════════
describe('events/{eventId}/attendance/{memberUid}', () => {
  it('signed-in reads attendance list → allow', async () => {
    await assertSucceeds(
      getDocs(collection(memberDb(), 'events', EVENT_ID, 'attendance'))
    );
  });

  describe('create — member QR path', () => {
    it('member with valid qrSecretUsed + canonical payload → allow', async () => {
      await assertSucceeds(
        setDoc(
          doc(memberDb(), 'events', EVENT_ID, 'attendance', MEMBER),
          {
            userId: MEMBER,
            userName: 'Member',
            method: 'qr',
            starsAwarded: 2,
            qrSecretUsed: QR_SECRET,
            checkedInAt: serverTimestamp(),
          }
        )
      );
    });
    it('member with WRONG qrSecretUsed → deny (FND-04)', async () => {
      await assertFails(
        setDoc(
          doc(memberDb(), 'events', EVENT_ID, 'attendance', MEMBER),
          {
            userId: MEMBER,
            userName: 'Member',
            method: 'qr',
            starsAwarded: 2,
            qrSecretUsed: 'forged-secret',
            checkedInAt: serverTimestamp(),
          }
        )
      );
    });
    it('member without qrSecretUsed field → deny', async () => {
      await assertFails(
        setDoc(
          doc(memberDb(), 'events', EVENT_ID, 'attendance', MEMBER),
          {
            userId: MEMBER,
            userName: 'Member',
            method: 'qr',
            starsAwarded: 2,
            checkedInAt: serverTimestamp(),
          }
        )
      );
    });
    it('member tries starsAwarded: 999 → deny', async () => {
      await assertFails(
        setDoc(
          doc(memberDb(), 'events', EVENT_ID, 'attendance', MEMBER),
          {
            userId: MEMBER,
            userName: 'Member',
            method: 'qr',
            starsAwarded: 999,
            qrSecretUsed: QR_SECRET,
            checkedInAt: serverTimestamp(),
          }
        )
      );
    });
    it('member tries method: "manual" (admin-only) → deny', async () => {
      await assertFails(
        setDoc(
          doc(memberDb(), 'events', EVENT_ID, 'attendance', MEMBER),
          {
            userId: MEMBER,
            userName: 'Member',
            method: 'manual',
            starsAwarded: 2,
            qrSecretUsed: QR_SECRET,
            checkedInAt: serverTimestamp(),
          }
        )
      );
    });
    it('member tries to check in another user → deny', async () => {
      await assertFails(
        setDoc(
          doc(memberDb(), 'events', EVENT_ID, 'attendance', OTHER_MEMBER),
          {
            userId: OTHER_MEMBER,
            userName: 'Other',
            method: 'qr',
            starsAwarded: 2,
            qrSecretUsed: QR_SECRET,
            checkedInAt: serverTimestamp(),
          }
        )
      );
    });
    it('member writes userId != own uid → deny', async () => {
      await assertFails(
        setDoc(
          doc(memberDb(), 'events', EVENT_ID, 'attendance', MEMBER),
          {
            userId: OTHER_MEMBER,
            userName: 'Mismatch',
            method: 'qr',
            starsAwarded: 2,
            qrSecretUsed: QR_SECRET,
            checkedInAt: serverTimestamp(),
          }
        )
      );
    });
  });

  describe('create — admin path', () => {
    it('admin marks any member manually (no qrSecretUsed needed) → allow', async () => {
      await assertSucceeds(
        setDoc(
          doc(adminDb(), 'events', EVENT_ID, 'attendance', OTHER_MEMBER),
          {
            userId: OTHER_MEMBER,
            userName: 'Other',
            method: 'manual',
            starsAwarded: 2,
            checkedInAt: serverTimestamp(),
          }
        )
      );
    });
  });

  describe('update / delete', () => {
    it('admin can delete attendance → allow', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(
          doc(ctx.firestore(), 'events', EVENT_ID, 'attendance', MEMBER),
          { userId: MEMBER, method: 'manual', starsAwarded: 2 }
        );
      });
      await assertSucceeds(
        deleteDoc(doc(adminDb(), 'events', EVENT_ID, 'attendance', MEMBER))
      );
    });
    it('member cannot update/delete attendance → deny', async () => {
      await testEnv.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(
          doc(ctx.firestore(), 'events', EVENT_ID, 'attendance', MEMBER),
          { userId: MEMBER, method: 'manual', starsAwarded: 2 }
        );
      });
      await assertFails(
        deleteDoc(doc(memberDb(), 'events', EVENT_ID, 'attendance', MEMBER))
      );
    });
  });
});

// ════════════════════════════════════════════════════════════════════
//                           GALLERY (FND-18)
// ════════════════════════════════════════════════════════════════════
describe('events/{eventId}/gallery/{photoId}', () => {
  it('member creates with valid uploadedBy + Cloudinary URL → allow', async () => {
    await assertSucceeds(
      addDoc(collection(memberDb(), 'events', EVENT_ID, 'gallery'), {
        url: CLOUDINARY_URL,
        uploadedBy: MEMBER,
        uploadedByName: 'Member',
        uploadedAt: serverTimestamp(),
      })
    );
  });
  it('member forges uploadedBy to another uid → deny (FND-18)', async () => {
    await assertFails(
      addDoc(collection(memberDb(), 'events', EVENT_ID, 'gallery'), {
        url: CLOUDINARY_URL,
        uploadedBy: OTHER_MEMBER,
        uploadedByName: 'Other',
        uploadedAt: serverTimestamp(),
      })
    );
  });
  it('member posts non-Cloudinary URL → deny (FND-18)', async () => {
    await assertFails(
      addDoc(collection(memberDb(), 'events', EVENT_ID, 'gallery'), {
        url: NON_CLOUDINARY_URL,
        uploadedBy: MEMBER,
        uploadedByName: 'Member',
        uploadedAt: serverTimestamp(),
      })
    );
  });
  it('uploader deletes own photo → allow', async () => {
    let photoId;
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const ref = await addDoc(
        collection(ctx.firestore(), 'events', EVENT_ID, 'gallery'),
        { url: CLOUDINARY_URL, uploadedBy: MEMBER }
      );
      photoId = ref.id;
    });
    await assertSucceeds(
      deleteDoc(doc(memberDb(), 'events', EVENT_ID, 'gallery', photoId))
    );
  });
  it('other member tries to delete someone else\'s photo → deny', async () => {
    let photoId;
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const ref = await addDoc(
        collection(ctx.firestore(), 'events', EVENT_ID, 'gallery'),
        { url: CLOUDINARY_URL, uploadedBy: MEMBER }
      );
      photoId = ref.id;
    });
    await assertFails(
      deleteDoc(doc(otherMemberDb(), 'events', EVENT_ID, 'gallery', photoId))
    );
  });
  it('admin deletes anyone\'s photo → allow', async () => {
    let photoId;
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const ref = await addDoc(
        collection(ctx.firestore(), 'events', EVENT_ID, 'gallery'),
        { url: CLOUDINARY_URL, uploadedBy: MEMBER }
      );
      photoId = ref.id;
    });
    await assertSucceeds(
      deleteDoc(doc(adminDb(), 'events', EVENT_ID, 'gallery', photoId))
    );
  });
});

// ════════════════════════════════════════════════════════════════════
//                             WALLET (FND-18)
// ════════════════════════════════════════════════════════════════════
describe('events/{eventId}/wallet/{docId}', () => {
  it('member uploads pdf with valid uploadedBy + Cloudinary URL → allow', async () => {
    await assertSucceeds(
      addDoc(collection(memberDb(), 'events', EVENT_ID, 'wallet'), {
        url: CLOUDINARY_URL,
        uploadedBy: MEMBER,
        uploadedByName: 'Member',
        type: 'pdf',
        title: 'receipt',
        uploadedAt: serverTimestamp(),
      })
    );
  });
  it('member uploads image with type: image → allow', async () => {
    await assertSucceeds(
      addDoc(collection(memberDb(), 'events', EVENT_ID, 'wallet'), {
        url: CLOUDINARY_URL,
        uploadedBy: MEMBER,
        uploadedByName: 'Member',
        type: 'image',
        title: 'photo',
        uploadedAt: serverTimestamp(),
      })
    );
  });
  it('member forges uploadedBy → deny', async () => {
    await assertFails(
      addDoc(collection(memberDb(), 'events', EVENT_ID, 'wallet'), {
        url: CLOUDINARY_URL,
        uploadedBy: OTHER_MEMBER,
        type: 'pdf',
      })
    );
  });
  it('member posts bogus type enum → deny', async () => {
    await assertFails(
      addDoc(collection(memberDb(), 'events', EVENT_ID, 'wallet'), {
        url: CLOUDINARY_URL,
        uploadedBy: MEMBER,
        type: 'exe',
      })
    );
  });
  it('member posts non-Cloudinary URL → deny', async () => {
    await assertFails(
      addDoc(collection(memberDb(), 'events', EVENT_ID, 'wallet'), {
        url: NON_CLOUDINARY_URL,
        uploadedBy: MEMBER,
        type: 'pdf',
      })
    );
  });
});

// ════════════════════════════════════════════════════════════════════
//                           NOTIFICATIONS
// ════════════════════════════════════════════════════════════════════
describe('notifications/{id}', () => {
  it('signed-in reads → allow', async () => {
    await assertSucceeds(getDocs(collection(memberDb(), 'notifications')));
  });
  it('admin creates → allow', async () => {
    await assertSucceeds(
      addDoc(collection(adminDb(), 'notifications'), {
        title: 'x',
        body: 'y',
        kind: 'announcement',
        topic: 'all_members',
        sentBy: ADMIN,
        sentByName: 'Admin',
        sentAt: serverTimestamp(),
      })
    );
  });
  it('member creates → deny', async () => {
    await assertFails(
      addDoc(collection(memberDb(), 'notifications'), {
        title: 'x',
        body: 'y',
        kind: 'announcement',
      })
    );
  });
});

// ════════════════════════════════════════════════════════════════════
//                               KURALS
// ════════════════════════════════════════════════════════════════════
describe('kurals/{date}', () => {
  it('signed-in reads kural → allow', async () => {
    await assertSucceeds(getDoc(doc(memberDb(), 'kurals', '2026-04-23')));
  });
  it('admin writes kural → allow', async () => {
    await assertSucceeds(
      setDoc(doc(adminDb(), 'kurals', '2026-04-23'), {
        number: 1, tamil: 't', english: 'e', chapter: 'c',
      })
    );
  });
  it('member writes kural → deny', async () => {
    await assertFails(
      setDoc(doc(memberDb(), 'kurals', '2026-04-23'), { number: 1 })
    );
  });
});
