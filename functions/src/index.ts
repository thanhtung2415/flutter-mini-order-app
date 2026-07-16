import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";
import {setGlobalOptions} from "firebase-functions/v2";
import {HttpsError, onCall} from "firebase-functions/v2/https";

initializeApp();
setGlobalOptions({
  region: "asia-southeast1",
  maxInstances: 3,
  memory: "256MiB",
  timeoutSeconds: 30,
});

const db = getFirestore();

function requiredString(data: unknown, field: string): string {
  if (typeof data !== "object" || data === null) {
    throw new HttpsError("invalid-argument", "Dữ liệu không hợp lệ.");
  }
  const value = (data as Record<string, unknown>)[field];
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `Thiếu trường ${field}.`);
  }
  return value.trim();
}

function requiredRole(data: unknown): "admin" | "staff" {
  const role = requiredString(data, "role");
  if (role !== "admin" && role !== "staff") {
    throw new HttpsError("invalid-argument", "Vai trò không hợp lệ.");
  }
  return role;
}

function optionalString(data: unknown, field: string): string {
  if (typeof data !== "object" || data === null) return "";
  const value = (data as Record<string, unknown>)[field];
  return typeof value === "string" ? value.trim() : "";
}

async function assertAdmin(callerUid: string | undefined): Promise<void> {
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Bạn cần đăng nhập.");
  }
  const profile = await db.doc(`users/${callerUid}`).get();
  const data = profile.data();
  if (!profile.exists || data?.vaiTro !== "admin" || data?.trangThai !== "active") {
    throw new HttpsError("permission-denied", "Chỉ Admin đang hoạt động được phép.");
  }
}

function profileFields(data: unknown, uid: string): Record<string, unknown> {
  const email = requiredString(data, "email").toLowerCase();
  return {
    userId: uid,
    maNhanVien: requiredString(data, "employeeCode"),
    hoTen: requiredString(data, "fullName"),
    email,
    soDienThoai: optionalString(data, "phone"),
    tenDangNhap: requiredString(data, "username"),
    vaiTro: requiredRole(data),
    caLamViec: requiredString(data, "shift"),
    updatedAt: new Date().toISOString(),
  };
}

export const requestGoogleAccess = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Bạn cần đăng nhập Google.");
  }

  const auth = getAuth();
  const authUser = await auth.getUser(uid);
  const isGoogleAccount = authUser.providerData.some(
    (provider) => provider.providerId === "google.com",
  );
  if (!isGoogleAccount) {
    throw new HttpsError(
      "permission-denied",
      "Chỉ tài khoản đăng nhập bằng Google được gửi yêu cầu này.",
    );
  }

  const profile = await db.doc(`users/${uid}`).get();
  if (profile.exists) {
    return {status: "approved"};
  }

  const email = authUser.email?.trim().toLowerCase();
  if (!email) {
    throw new HttpsError(
      "failed-precondition",
      "Tài khoản Google không cung cấp email hợp lệ.",
    );
  }

  const requestRef = db.doc(`access_requests/${uid}`);
  const existing = await requestRef.get();
  if (existing.data()?.status === "rejected") {
    return {status: "rejected"};
  }

  const now = new Date().toISOString();
  await requestRef.set({
    uid,
    email,
    fullName: authUser.displayName?.trim() || email.split("@")[0],
    photoUrl: authUser.photoURL ?? "",
    status: "pending",
    requestedAt: existing.data()?.requestedAt ?? now,
    lastAttemptAt: now,
  }, {merge: true});
  return {status: "pending"};
});

export const adminReviewGoogleAccess = onCall(async (request) => {
  await assertAdmin(request.auth?.uid);
  const uid = requiredString(request.data, "uid");
  const decision = requiredString(request.data, "decision");
  if (decision !== "approved" && decision !== "rejected") {
    throw new HttpsError("invalid-argument", "Quyết định không hợp lệ.");
  }

  const requestRef = db.doc(`access_requests/${uid}`);
  const accessRequest = await requestRef.get();
  const requestData = accessRequest.data();
  if (!accessRequest.exists || !requestData) {
    throw new HttpsError("not-found", "Không tìm thấy yêu cầu cấp quyền.");
  }

  const now = new Date().toISOString();
  if (decision === "rejected") {
    await requestRef.set({
      status: "rejected",
      reviewedAt: now,
      reviewedBy: request.auth?.uid,
    }, {merge: true});
    return {uid, status: "rejected"};
  }

  const role = requiredRole(request.data);
  const shift = requiredString(request.data, "shift");
  const auth = getAuth();
  const authUser = await auth.getUser(uid);
  const email = authUser.email?.trim().toLowerCase() ||
    requiredString(requestData, "email").toLowerCase();
  const fullName = authUser.displayName?.trim() ||
    optionalString(requestData, "fullName") || email.split("@")[0];
  const profileRef = db.doc(`users/${uid}`);
  const existingProfile = await profileRef.get();
  const employeePrefix = role === "admin" ? "AD" : "NV";

  await auth.updateUser(uid, {disabled: false, displayName: fullName});
  await auth.setCustomUserClaims(uid, {role});

  const batch = db.batch();
  batch.set(profileRef, {
    userId: uid,
    maNhanVien: existingProfile.data()?.maNhanVien ??
      `${employeePrefix}${uid.substring(0, 6).toUpperCase()}`,
    hoTen: fullName,
    email,
    soDienThoai: existingProfile.data()?.soDienThoai ?? "",
    tenDangNhap: email.split("@")[0],
    vaiTro: role,
    caLamViec: shift,
    trangThai: "active",
    createdAt: existingProfile.data()?.createdAt ?? now,
    updatedAt: now,
  }, {merge: true});
  batch.set(requestRef, {
    status: "approved",
    assignedRole: role,
    reviewedAt: now,
    reviewedBy: request.auth?.uid,
  }, {merge: true});
  await batch.commit();
  return {uid, status: "approved", role};
});

export const adminCreateUser = onCall(async (request) => {
  await assertAdmin(request.auth?.uid);
  const email = requiredString(request.data, "email").toLowerCase();
  const password = requiredString(request.data, "password");
  if (password.length < 6) {
    throw new HttpsError("invalid-argument", "Mật khẩu phải có ít nhất 6 ký tự.");
  }

  const auth = getAuth();
  const created = await auth.createUser({
    email,
    password,
    displayName: requiredString(request.data, "fullName"),
    disabled: false,
  });

  try {
    const role = requiredRole(request.data);
    await auth.setCustomUserClaims(created.uid, {role});
    await db.doc(`users/${created.uid}`).set({
      ...profileFields(request.data, created.uid),
      trangThai: "active",
      createdAt: new Date().toISOString(),
    });
    return {uid: created.uid};
  } catch (error) {
    await auth.deleteUser(created.uid).catch(() => undefined);
    throw error;
  }
});

export const adminUpdateUser = onCall(async (request) => {
  await assertAdmin(request.auth?.uid);
  const uid = requiredString(request.data, "uid");
  const email = requiredString(request.data, "email").toLowerCase();
  const role = requiredRole(request.data);
  if (uid === request.auth?.uid && role !== "admin") {
    throw new HttpsError(
      "failed-precondition",
      "Không thể tự hạ quyền tài khoản Admin đang đăng nhập.",
    );
  }
  const auth = getAuth();

  await auth.updateUser(uid, {
    email,
    displayName: requiredString(request.data, "fullName"),
  });
  await auth.setCustomUserClaims(uid, {role});
  const profileRef = db.doc(`users/${uid}`);
  const existingProfile = await profileRef.get();
  await profileRef.set({
    ...profileFields(request.data, uid),
    trangThai: existingProfile.data()?.trangThai ?? "active",
    ...(!existingProfile.exists ? {createdAt: new Date().toISOString()} : {}),
  }, {merge: true});
  return {uid};
});

export const adminSetUserDisabled = onCall(async (request) => {
  await assertAdmin(request.auth?.uid);
  const uid = requiredString(request.data, "uid");
  if (uid === request.auth?.uid) {
    throw new HttpsError("failed-precondition", "Không thể khóa tài khoản đang đăng nhập.");
  }
  if (typeof request.data?.disabled !== "boolean") {
    throw new HttpsError("invalid-argument", "Trạng thái khóa không hợp lệ.");
  }
  const disabled = request.data.disabled as boolean;
  await getAuth().updateUser(uid, {disabled});
  await db.doc(`users/${uid}`).set({
    trangThai: disabled ? "locked" : "active",
    updatedAt: new Date().toISOString(),
  }, {merge: true});
  return {uid, disabled};
});

export const adminDeleteUser = onCall(async (request) => {
  await assertAdmin(request.auth?.uid);
  const uid = requiredString(request.data, "uid");
  if (uid === request.auth?.uid) {
    throw new HttpsError("failed-precondition", "Không thể xóa tài khoản đang đăng nhập.");
  }
  const orderHistory = await db.collection("orders")
    .where("userId", "==", uid)
    .limit(1)
    .get();
  if (!orderHistory.empty) {
    throw new HttpsError(
      "failed-precondition",
      "Tài khoản đã có lịch sử order; hãy khóa thay vì xóa.",
    );
  }
  await getAuth().deleteUser(uid);
  await db.doc(`users/${uid}`).delete();
  return {uid};
});
