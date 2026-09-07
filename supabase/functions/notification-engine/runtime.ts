import {
  createNotificationEngine,
  type CompletedProgressRow,
  type NotificationDeliveryRow,
  type NotificationEndpointRow,
  type NotificationPayload,
  type NotificationProvider,
  type NotificationRepository,
  type NotificationSettingsRow,
  type ProviderOutcome,
  type UserPreferenceRow,
} from "./engine.ts";

import webPush from "npm:web-push@^3.6.7";
import elliptic from "npm:elliptic@^6.6.1";

const SUPABASE_REST_HEADERS = {
  Accept: "application/json",
  "Content-Type": "application/json",
};

export function buildRuntimeHandler() {
  const schedulerKey = Deno.env.get("NOTIFICATION_SCHEDULER_KEY") ?? "";
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseKey = loadSupabaseAdminKey();

  if (!schedulerKey) {
    console.warn("NOTIFICATION_SCHEDULER_KEY is not configured.");
  }

  if (!supabaseUrl || !supabaseKey) {
    console.warn("Supabase admin credentials are not fully configured.");
  }

  const repository = new SupabaseRestRepository(
    supabaseUrl,
    supabaseKey,
  );

  const fcmProvider = buildFcmProvider();
  const webPushProvider = buildWebPushProvider();

  const engine = createNotificationEngine({
    repository,
    fcmProvider,
    webPushProvider,
    schedulerKey,
    logger: console,
    developmentMode: isDevelopmentMode(),
  });

  return {
    fetch: async (request: Request): Promise<Response> => {
      try {
        return await engine.handleRequest(request);
      } catch (error) {
        console.error("notification-engine failed:", error);
        return jsonResponse(
          { error: "notification-engine failed." },
          500,
        );
      }
    },
  };
}

class SupabaseRestRepository implements NotificationRepository {
  constructor(
    private readonly supabaseUrl: string,
    private readonly supabaseKey: string,
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  async listNotificationSettings(): Promise<NotificationSettingsRow[]> {
    return this.getJson<NotificationSettingsRow[]>(
      "notification_settings",
      {
        select:
          "user_id,notifications_enabled,daily_prep_reminder_enabled,daily_goal_reminder_enabled,achievement_notifications_enabled,streak_reminder_enabled,preferred_reminder_time,streak_reminder_time,timezone",
      },
    );
  }

  async listUserPreferences(
    userIds: string[],
  ): Promise<UserPreferenceRow[]> {
    if (userIds.length === 0) return [];

    return this.getJson<UserPreferenceRow[]>("user_preferences", {
      select: "user_id,daily_goal,daily_focus_date,daily_focus_topics",
      user_id: `in.(${joinList(userIds)})`,
    });
  }

  async listCompletedProgress(
    userIds: string[],
  ): Promise<CompletedProgressRow[]> {
    if (userIds.length === 0) return [];

    return this.getJson<CompletedProgressRow[]>("user_problem_progress", {
      select: "user_id,completed_at",
      user_id: `in.(${joinList(userIds)})`,
      completed: "eq.true",
      completed_at: "not.is.null",
      order: "completed_at.asc",
    });
  }

  async enqueueNotificationDelivery(input: {
    userId: string;
    category: "daily_prep" | "daily_goal" | "streak" | "achievement";
    localDate: string | null;
    eventIdentifier: string | null;
    eventVersion: string;
  }): Promise<string | null> {
    const result = await this.rpcUnknown("enqueue_notification_delivery", {
      p_user_id: input.userId,
      p_category: input.category,
      p_local_date: input.localDate,
      p_event_identifier: input.eventIdentifier,
      p_event_version: input.eventVersion,
    });

    return normalizeScalarString(result);
  }

  async listDeliveriesToProcess(limit: number): Promise<NotificationDeliveryRow[]> {
    return this.getJson<NotificationDeliveryRow[]>("notification_deliveries", {
      select:
        "id,user_id,category,local_date,event_identifier,event_version,status,attempt_count,last_attempt_at,lease_expires_at,last_error_code",
      status: "in.(pending,failed,sending)",
      attempt_count: "lt.6",
      order: "created_at.asc",
      limit: String(limit),
    });
  }

  async claimNotificationDelivery(
    deliveryId: string,
    leaseSeconds: number,
  ): Promise<NotificationDeliveryRow | null> {
    const result = await this.rpcUnknown("claim_notification_delivery", {
      p_delivery_id: deliveryId,
      p_lease_seconds: leaseSeconds,
    });

    return normalizeSingleRow<NotificationDeliveryRow>(result);
  }

  async completeNotificationDelivery(
    deliveryId: string,
    succeeded: boolean,
    errorCode?: string | null,
  ): Promise<boolean> {
    const result = await this.rpcUnknown("complete_notification_delivery", {
      p_delivery_id: deliveryId,
      p_succeeded: succeeded,
      p_error_code: errorCode ?? null,
    });

    return normalizeScalarBoolean(result);
  }

  async listActiveEndpoints(userId: string): Promise<NotificationEndpointRow[]> {
    return this.getJson<NotificationEndpointRow[]>("notification_endpoints", {
      select:
        "id,user_id,provider,platform,device_token,endpoint,p256dh,auth,active",
      user_id: `eq.${encodeValue(userId)}`,
      active: "eq.true",
      order: "created_at.asc",
    });
  }

  async deactivateEndpoint(endpointId: string): Promise<void> {
    await this.patchJson(`notification_endpoints?id=eq.${encodeValue(endpointId)}`, {
      active: false,
      updated_at: new Date().toISOString(),
    });
  }

  private async getJson<T>(
    table: string,
    params: Record<string, string>,
  ): Promise<T> {
    const url = new URL(`${this.supabaseUrl}/rest/v1/${table}`);
    for (const [key, value] of Object.entries(params)) {
      url.searchParams.set(key, value);
    }

    const response = await this.fetchImpl(url, {
      method: "GET",
      headers: this.adminHeaders(),
    });
    return await this.readJson<T>(response);
  }

  private async patchJson(path: string, body: unknown): Promise<void> {
    const response = await this.fetchImpl(
      `${this.supabaseUrl}/rest/v1/${path}`,
      {
        method: "PATCH",
        headers: this.adminHeaders(),
        body: JSON.stringify(body),
      },
    );
    await this.readJson(response);
  }

  private async rpcUnknown(name: string, body: unknown): Promise<unknown> {
    const response = await this.fetchImpl(
      `${this.supabaseUrl}/rest/v1/rpc/${name}`,
      {
        method: "POST",
        headers: this.adminHeaders(),
        body: JSON.stringify(body),
      },
    );
    return await this.readJson<unknown>(response);
  }

  private adminHeaders(): HeadersInit {
    return {
      ...SUPABASE_REST_HEADERS,
      apikey: this.supabaseKey,
      authorization: `Bearer ${this.supabaseKey}`,
    };
  }

  private async readJson<T>(response: Response): Promise<T> {
    const text = await response.text();
    if (!response.ok) {
      throw new Error(
        `Supabase request failed (${response.status}): ${text.slice(0, 200)}`,
      );
    }

    if (!text) {
      return undefined as T;
    }

    return JSON.parse(text) as T;
  }
}

class FcmProvider implements NotificationProvider {
  private accessToken: { token: string; expiresAt: number } | null = null;
  private readonly projectId: string;
  private readonly clientEmail: string;
  private readonly privateKey: CryptoKey;
  private readonly tokenUri: string;
  private readonly fetchImpl: typeof fetch;

  private constructor(
    serviceAccount: FirebaseServiceAccount,
    fetchImpl: typeof fetch = fetch,
  ) {
    this.projectId = serviceAccount.project_id;
    this.clientEmail = serviceAccount.client_email;
    this.tokenUri = serviceAccount.token_uri ??
      "https://oauth2.googleapis.com/token";
    this.fetchImpl = fetchImpl;
    this.privateKey = serviceAccount.privateKey;
  }

  static async create(
    serviceAccount: FirebaseServiceAccount,
    fetchImpl: typeof fetch = fetch,
  ): Promise<FcmProvider> {
    const privateKey = await importRsaPrivateKey(serviceAccount.private_key);
    return new FcmProvider(
      {
        ...serviceAccount,
        privateKey,
      },
      fetchImpl,
    );
  }

  async send(
    endpoint: NotificationEndpointRow,
    payload: NotificationPayload,
  ): Promise<ProviderOutcome> {
    const accessToken = await this.getAccessToken();
    if (accessToken === "oauth_failed") {
      return {
        ok: false,
        retryable: false,
        deactivateEndpoint: false,
        errorCode: "fcm_oauth_failed",
      };
    }
    if (!accessToken) {
      return {
        ok: false,
        retryable: false,
        deactivateEndpoint: false,
        errorCode: "fcm_not_configured",
      };
    }

    const response = await this.fetchImpl(
      `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(this.projectId)}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: endpoint.device_token,
            notification: {
              title: payload.title,
              body: payload.body,
            },
            data: stringifyData(payload.data),
            android: {
              priority: "HIGH",
            },
          },
        }),
      },
    );

    if (response.ok) {
      return { ok: true };
    }

    const text = await response.text();
    return normalizeFcmError(response.status, text);
  }

  private async getAccessToken(): Promise<string | "oauth_failed"> {
    const now = Date.now();
    if (this.accessToken && this.accessToken.expiresAt - 60_000 > now) {
      return this.accessToken.token;
    }

    const jwt = await signServiceAccountJwt(
      this.clientEmail,
      this.tokenUri,
      this.privateKey,
    );

    const body = new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    });

    const response = await this.fetchImpl(this.tokenUri, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body,
    });

    if (!response.ok) {
      console.warn("FCM OAuth token fetch failed", { status: response.status });
      return "oauth_failed";
    }

    const json = await response.json();
    const token = typeof json.access_token === "string"
      ? json.access_token
      : null;
    const expiresIn = Number(json.expires_in ?? 3600);
    if (!token) {
      console.warn("FCM OAuth response missing access_token");
      return "oauth_failed";
    }

    this.accessToken = {
      token,
      expiresAt: now + Math.max(60, expiresIn) * 1000,
    };

    return token;
  }
}

class DisabledProvider implements NotificationProvider {
  constructor(private readonly code: string) {}

  async send(): Promise<ProviderOutcome> {
    return {
      ok: false,
      retryable: false,
      deactivateEndpoint: false,
      errorCode: this.code,
    };
  }
}

class WebPushProvider implements NotificationProvider {
  private readonly vapidPublicKey: string;

  constructor(
    private readonly subject: string,
    private readonly privateKey: string,
  ) {
    this.vapidPublicKey = deriveVapidPublicKey(privateKey);
    webPush.setVapidDetails(subject, this.vapidPublicKey, privateKey);
  }

  async send(
    endpoint: NotificationEndpointRow,
    payload: NotificationPayload,
  ): Promise<ProviderOutcome> {
    try {
      await webPush.sendNotification(
        {
          endpoint: endpoint.endpoint ?? "",
          keys: {
            p256dh: endpoint.p256dh ?? "",
            auth: endpoint.auth ?? "",
          },
        },
        JSON.stringify(payload),
      );
      return { ok: true };
    } catch (error) {
      return normalizeWebPushError(error);
    }
  }
}

interface FirebaseServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
  privateKey: CryptoKey;
}

export function buildFcmProvider(): NotificationProvider {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!raw) {
    return new DisabledProvider("fcm_not_configured");
  }

  try {
    const parsed = JSON.parse(raw) as Partial<FirebaseServiceAccount>;
    if (
      typeof parsed.project_id !== "string" ||
      typeof parsed.client_email !== "string" ||
      typeof parsed.private_key !== "string"
    ) {
      return new DisabledProvider("fcm_not_configured");
    }

    if (parsed.project_id !== "neo-150-prep") {
      return new DisabledProvider("fcm_project_mismatch");
    }

    const validated: {
      project_id: string;
      client_email: string;
      private_key: string;
      token_uri: string | undefined;
    } = {
      project_id: parsed.project_id,
      client_email: parsed.client_email,
      private_key: parsed.private_key,
      token_uri: parsed.token_uri,
    };

    return new PromiseProvider(async () =>
      await FcmProvider.create({
        project_id: validated.project_id,
        client_email: validated.client_email,
        private_key: validated.private_key,
        token_uri: validated.token_uri,
        privateKey: await importRsaPrivateKey(validated.private_key),
      })
    );
  } catch {
    return new DisabledProvider("fcm_not_configured");
  }
}

export function buildWebPushProvider(): NotificationProvider {
  const subject = Deno.env.get("VAPID_SUBJECT") ?? "";
  const privateKey = Deno.env.get("VAPID_PRIVATE_KEY") ?? "";
  if (!subject || !privateKey) {
    return new DisabledProvider("web_push_not_configured");
  }

  try {
    return new WebPushProvider(subject, privateKey);
  } catch {
    return new DisabledProvider("web_push_not_configured");
  }
}

class PromiseProvider implements NotificationProvider {
  constructor(
    private readonly factory: () => Promise<NotificationProvider>,
  ) {}

  private instance: NotificationProvider | null = null;
  private loading: Promise<NotificationProvider> | null = null;

  async send(
    endpoint: NotificationEndpointRow,
    payload: NotificationPayload,
  ): Promise<ProviderOutcome> {
    const provider = await this.resolve();
    return await provider.send(endpoint, payload);
  }

  private async resolve(): Promise<NotificationProvider> {
    if (this.instance) return this.instance;
    if (!this.loading) {
      this.loading = this.factory().then((provider) => {
        this.instance = provider;
        return provider;
      });
    }

    return await this.loading;
  }
}

function loadSupabaseAdminKey(): string {
  const direct = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (direct) return direct;

  const structured = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (structured) {
    try {
      const parsed = JSON.parse(structured) as Record<string, string>;
      if (typeof parsed.default === "string") {
        return parsed.default;
      }
    } catch {
      return "";
    }
  }

  return Deno.env.get("SUPABASE_SERVICE_KEY") ?? "";
}

function isDevelopmentMode(): boolean {
  return (Deno.env.get("SUPABASE_ENV") ?? Deno.env.get("DENO_ENV") ?? "")
    .toLowerCase() === "local";
}

async function importRsaPrivateKey(pem: string): Promise<CryptoKey> {
  const clean = pem.replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "").replace(
    /\s+/g,
    "",
  );
  const bytes = base64ToBytes(clean);
  return await crypto.subtle.importKey(
    "pkcs8",
    bytes as BufferSource,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );
}

async function signServiceAccountJwt(
  clientEmail: string,
  audience: string,
  privateKey: CryptoKey,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncodeJson({
    alg: "RS256",
    typ: "JWT",
  });
  const payload = base64UrlEncodeJson({
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: audience,
    iat: now,
    exp: now + 3600,
  });
  const unsigned = `${header}.${payload}`;
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    new TextEncoder().encode(unsigned),
  );
  return `${unsigned}.${bytesToBase64Url(new Uint8Array(signature))}`;
}

function deriveVapidPublicKey(privateKey: string): string {
  const ec = new elliptic.ec("p256");
  const keyPair = ec.keyFromPrivate(base64UrlToHex(privateKey), "hex");
  const publicBytes = Uint8Array.from(
    keyPair.getPublic().encode("array", false) as number[],
  );
  return bytesToBase64Url(publicBytes);
}

function normalizeFcmError(
  status: number,
  body: string,
): ProviderOutcome {
  const parsed = safeJsonParse(body);
  const error = isPlainObject(parsed) && isPlainObject(parsed.error)
    ? parsed.error as Record<string, unknown>
    : null;
  const errorStatus = typeof error?.status === "string"
    ? error.status.toUpperCase()
    : "";
  const details = Array.isArray(error?.details) ? error.details : [];
  const detailCodes = details
    .map((detail) =>
      isPlainObject(detail) && typeof detail.errorCode === "string"
        ? detail.errorCode.toUpperCase()
        : ""
    )
    .filter(Boolean);

  if (
    status === 404 ||
    errorStatus === "NOT_FOUND" ||
    detailCodes.includes("UNREGISTERED") ||
    body.includes("UNREGISTERED")
  ) {
    return {
      ok: false,
      retryable: false,
      deactivateEndpoint: true,
      errorCode: "fcm_unregistered",
    };
  }

  if (status === 429 || errorStatus === "RESOURCE_EXHAUSTED") {
    return {
      ok: false,
      retryable: true,
      deactivateEndpoint: false,
      errorCode: "fcm_rate_limited",
    };
  }

  if (status >= 500) {
    return {
      ok: false,
      retryable: true,
      deactivateEndpoint: false,
      errorCode: "fcm_server_error",
    };
  }

  if (status === 401 || status === 403) {
    return {
      ok: false,
      retryable: false,
      deactivateEndpoint: false,
      errorCode: "fcm_auth_error",
    };
  }

  return {
    ok: false,
    retryable: false,
    deactivateEndpoint: false,
    errorCode: "fcm_delivery_failed",
  };
}

function normalizeWebPushError(error: unknown): ProviderOutcome {
  const statusCode = typeof error === "object" && error &&
      "statusCode" in error &&
      typeof (error as { statusCode?: unknown }).statusCode === "number"
    ? (error as { statusCode: number }).statusCode
    : 0;

  if (statusCode === 404 || statusCode === 410) {
    return {
      ok: false,
      retryable: false,
      deactivateEndpoint: true,
      errorCode: "web_push_unregistered",
    };
  }

  if (statusCode === 429) {
    return {
      ok: false,
      retryable: true,
      deactivateEndpoint: false,
      errorCode: "web_push_rate_limited",
    };
  }

  if (statusCode >= 500) {
    return {
      ok: false,
      retryable: true,
      deactivateEndpoint: false,
      errorCode: "web_push_server_error",
    };
  }

  return {
    ok: false,
    retryable: true,
    deactivateEndpoint: false,
    errorCode: "web_push_network_error",
  };
}

function stringifyData(
  data: NotificationPayload["data"],
): Record<string, string> {
  const values: Record<string, string> = {};
  for (const [key, value] of Object.entries(data)) {
    values[key] = value === null || value === undefined ? "" : String(value);
  }
  return values;
}

function encodeValue(value: string): string {
  return encodeURIComponent(value);
}

function joinList(values: string[]): string {
  return values.map((value) => encodeValue(value)).join(",");
}

function safeJsonParse(value: string): unknown {
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

function normalizeScalarString(value: unknown): string | null {
  if (typeof value === "string") return value;
  if (Array.isArray(value) && typeof value[0] === "string") return value[0];
  if (isPlainObject(value) && typeof value.id === "string") return value.id;
  return null;
}

function normalizeScalarBoolean(value: unknown): boolean {
  if (typeof value === "boolean") return value;
  if (Array.isArray(value) && typeof value[0] === "boolean") return value[0];
  return false;
}

function normalizeSingleRow<T>(value: unknown): T | null {
  if (Array.isArray(value)) {
    return (value[0] ?? null) as T | null;
  }
  if (isPlainObject(value)) {
    return value as T;
  }
  return null;
}

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function base64UrlToHex(value: string): string {
  const bytes = base64UrlToBytes(value);
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function base64UrlToBytes(value: string): Uint8Array {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(
    normalized.length + ((4 - (normalized.length % 4)) % 4),
    "=",
  );
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function base64ToBytes(value: string): Uint8Array {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function base64UrlEncodeJson(value: Record<string, unknown>): string {
  return bytesToBase64Url(
    new TextEncoder().encode(JSON.stringify(value)),
  );
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === "object" && !Array.isArray(value);
}
