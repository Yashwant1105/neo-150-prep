import {
  calculateStreak,
  createNotificationEngine,
  countCompletedToday,
  formatDateKey,
  type CompletedProgressRow,
  type NotificationDeliveryRow,
  type NotificationEndpointRow,
  type NotificationPayload,
  type NotificationProvider,
  type NotificationRepository,
  type NotificationSettingsRow,
  type ProviderOutcome,
  type UserPreferenceRow,
  isWithinReminderWindow,
  normalizeTimeZone,
  toZonedCalendar,
} from "./engine.ts";

function assertEquals<T>(actual: T, expected: T, message?: string) {
  const a = JSON.stringify(actual);
  const b = JSON.stringify(expected);
  if (a !== b) {
    throw new Error(message ?? `Expected ${b}, got ${a}`);
  }
}

class InMemoryRepository implements NotificationRepository {
  notificationSettings: NotificationSettingsRow[] = [];
  userPreferences = new Map<string, UserPreferenceRow>();
  progressRows = new Map<string, CompletedProgressRow[]>();
  deliveries: Array<NotificationDeliveryRow & { createdAt: number }> = [];
  endpoints = new Map<string, NotificationEndpointRow[]>();
  now = new Date("2026-08-23T14:00:00.000Z");
  nextDeliveryId = 1;

  async listNotificationSettings(): Promise<NotificationSettingsRow[]> {
    return [...this.notificationSettings];
  }

  async listUserPreferences(userIds: string[]): Promise<UserPreferenceRow[]> {
    return userIds.flatMap((userId) => {
      const row = this.userPreferences.get(userId);
      return row ? [row] : [];
    });
  }

  async listCompletedProgress(userIds: string[]): Promise<CompletedProgressRow[]> {
    return userIds.flatMap((userId) => this.progressRows.get(userId) ?? []);
  }

  async enqueueNotificationDelivery(input: {
    userId: string;
    category: "daily_prep" | "daily_goal" | "streak" | "achievement";
    localDate: string | null;
    eventIdentifier: string | null;
    eventVersion: string;
  }): Promise<string | null> {
    const existing = this.deliveries.find((delivery) =>
      delivery.user_id === input.userId &&
      delivery.category === input.category &&
      delivery.local_date === input.localDate &&
      delivery.event_identifier === input.eventIdentifier &&
      delivery.event_version === input.eventVersion
    );

    if (existing) {
      return null;
    }

    const id = `delivery-${this.nextDeliveryId++}`;
    this.deliveries.push({
      id,
      user_id: input.userId,
      category: input.category,
      local_date: input.localDate,
      event_identifier: input.eventIdentifier,
      event_version: input.eventVersion,
      status: "pending",
      attempt_count: 0,
      last_attempt_at: null,
      lease_expires_at: null,
      last_error_code: null,
      createdAt: this.deliveries.length,
    });

    return id;
  }

  async listDeliveriesToProcess(limit: number): Promise<NotificationDeliveryRow[]> {
    return this.deliveries
      .filter((delivery) =>
        delivery.attempt_count < 6 &&
        (
          delivery.status === "pending" ||
          delivery.status === "failed" ||
          delivery.status === "sending"
        )
      )
      .slice(0, limit)
      .map(({ createdAt: _createdAt, ...delivery }) => delivery);
  }

  async claimNotificationDelivery(
    deliveryId: string,
    leaseSeconds: number,
  ): Promise<NotificationDeliveryRow | null> {
    const delivery = this.deliveries.find((row) => row.id === deliveryId);
    if (!delivery) return null;

    const now = this.now;
    const nowIso = now.toISOString();
    const leaseExpiresAt = new Date(now.getTime() + leaseSeconds * 1000).toISOString();
    const canRetryFailed = delivery.status === "failed" && (
      delivery.last_attempt_at == null ||
      new Date(delivery.last_attempt_at).getTime() <=
        now.getTime() - (60_000 * Math.pow(2, Math.min(Math.max(delivery.attempt_count - 1, 0), 5)))
    );
    const canClaim =
      delivery.attempt_count < 6 &&
      (
        delivery.status === "pending" ||
        canRetryFailed ||
        (delivery.status === "sending" && delivery.lease_expires_at != null && new Date(delivery.lease_expires_at).getTime() <= now.getTime())
      );

    if (!canClaim) {
      return null;
    }

    delivery.status = "sending";
    delivery.attempt_count += 1;
    delivery.last_attempt_at = nowIso;
    delivery.lease_expires_at = leaseExpiresAt;

    return { ...delivery };
  }

  async completeNotificationDelivery(
    deliveryId: string,
    succeeded: boolean,
    errorCode?: string | null,
  ): Promise<boolean> {
    const delivery = this.deliveries.find((row) => row.id === deliveryId);
    if (!delivery || delivery.status !== "sending") return false;

    delivery.status = succeeded ? "sent" : "failed";
    delivery.lease_expires_at = null;
    delivery.last_error_code = succeeded ? null : errorCode ?? null;
    return true;
  }

  async listActiveEndpoints(userId: string): Promise<NotificationEndpointRow[]> {
    return [...(this.endpoints.get(userId) ?? [])].filter((row) => row.active);
  }

  async deactivateEndpoint(endpointId: string): Promise<void> {
    for (const endpoints of this.endpoints.values()) {
      const match = endpoints.find((endpoint) => endpoint.id === endpointId);
      if (match) {
        match.active = false;
      }
    }
  }
}

class ScriptedProvider implements NotificationProvider {
  calls: Array<{ endpointId: string; payload: NotificationPayload }> = [];

  constructor(
    private outcomeByEndpointId:
      | Record<string, ProviderOutcome>
      | ((endpoint: NotificationEndpointRow, payload: NotificationPayload) => ProviderOutcome),
  ) {}

  async send(
    endpoint: NotificationEndpointRow,
    payload: NotificationPayload,
  ): Promise<ProviderOutcome> {
    this.calls.push({ endpointId: endpoint.id, payload });
    if (typeof this.outcomeByEndpointId === "function") {
      return this.outcomeByEndpointId(endpoint, payload);
    }

    return this.outcomeByEndpointId[endpoint.id] ?? { ok: true };
  }

  setOutcome(
    outcomeByEndpointId:
      | Record<string, ProviderOutcome>
      | ((endpoint: NotificationEndpointRow, payload: NotificationPayload) => ProviderOutcome),
  ) {
    this.outcomeByEndpointId = outcomeByEndpointId;
  }
}

function buildEngine(options: {
  repository: InMemoryRepository;
  fcmProvider?: NotificationProvider;
  webPushProvider?: NotificationProvider;
}) {
  return createNotificationEngine({
    repository: options.repository,
    fcmProvider:
      options.fcmProvider ??
      new ScriptedProvider({} as Record<string, ProviderOutcome>),
    webPushProvider:
      options.webPushProvider ??
      new ScriptedProvider({} as Record<string, ProviderOutcome>),
    schedulerKey: "scheduler-secret",
    clock: { now: () => options.repository.now },
    logger: {
      info: () => {},
      warn: () => {},
      error: () => {},
      debug: () => {},
    },
    claimLeaseSeconds: 300,
    pendingBatchSize: 50,
  });
}

Deno.test("FCM success marks the delivery sent", async () => {
  const repo = new InMemoryRepository();
  repo.deliveries.push({
    id: "delivery-1",
    user_id: "user-1",
    category: "daily_prep",
    local_date: "2026-08-23",
    event_identifier: null,
    event_version: "v1",
    status: "pending",
    attempt_count: 0,
    last_attempt_at: null,
    lease_expires_at: null,
    last_error_code: null,
    createdAt: 0,
  });
  repo.endpoints.set("user-1", [
    {
      id: "endpoint-1",
      user_id: "user-1",
      provider: "fcm",
      platform: "android",
      device_token: "token-1",
      endpoint: null,
      p256dh: null,
      auth: null,
      active: true,
    },
  ]);

  const fcm = new ScriptedProvider({ "endpoint-1": { ok: true } });
  const engine = buildEngine({ repository: repo, fcmProvider: fcm });
  const result = await engine.runProcessPending();

  assertEquals(result.sent, 1);
  assertEquals(repo.deliveries[0].status, "sent");
  assertEquals(fcm.calls.length, 1);
});

Deno.test("FCM invalid token deactivates the endpoint", async () => {
  const repo = new InMemoryRepository();
  repo.deliveries.push({
    id: "delivery-1",
    user_id: "user-1",
    category: "daily_prep",
    local_date: "2026-08-23",
    event_identifier: null,
    event_version: "v1",
    status: "pending",
    attempt_count: 0,
    last_attempt_at: null,
    lease_expires_at: null,
    last_error_code: null,
    createdAt: 0,
  });
  repo.endpoints.set("user-1", [
    {
      id: "endpoint-1",
      user_id: "user-1",
      provider: "fcm",
      platform: "android",
      device_token: "token-1",
      endpoint: null,
      p256dh: null,
      auth: null,
      active: true,
    },
  ]);

  const fcm = new ScriptedProvider({
    "endpoint-1": {
      ok: false,
      retryable: false,
      deactivateEndpoint: true,
      errorCode: "fcm_unregistered",
    },
  });
  const engine = buildEngine({ repository: repo, fcmProvider: fcm });
  const result = await engine.runProcessPending();

  assertEquals(result.failed, 1);
  assertEquals(repo.deliveries[0].status, "failed");
  assertEquals(repo.endpoints.get("user-1")?.[0].active, false);
});

Deno.test("FCM 429 remains retryable", async () => {
  const repo = new InMemoryRepository();
  repo.deliveries.push({
    id: "delivery-1",
    user_id: "user-1",
    category: "daily_prep",
    local_date: "2026-08-23",
    event_identifier: null,
    event_version: "v1",
    status: "pending",
    attempt_count: 0,
    last_attempt_at: null,
    lease_expires_at: null,
    last_error_code: null,
    createdAt: 0,
  });
  repo.endpoints.set("user-1", [
    {
      id: "endpoint-1",
      user_id: "user-1",
      provider: "fcm",
      platform: "android",
      device_token: "token-1",
      endpoint: null,
      p256dh: null,
      auth: null,
      active: true,
    },
  ]);

  const fcm = new ScriptedProvider({
    "endpoint-1": {
      ok: false,
      retryable: true,
      deactivateEndpoint: false,
      errorCode: "fcm_rate_limited",
    },
  });
  const engine = buildEngine({ repository: repo, fcmProvider: fcm });
  await engine.runProcessPending();

  assertEquals(repo.deliveries[0].status, "failed");
  assertEquals(repo.deliveries[0].attempt_count, 1);
  assertEquals(repo.endpoints.get("user-1")?.[0].active, true);
});

Deno.test("FCM 5xx remains retryable", async () => {
  const repo = new InMemoryRepository();
  repo.deliveries.push({
    id: "delivery-1",
    user_id: "user-1",
    category: "daily_prep",
    local_date: "2026-08-23",
    event_identifier: null,
    event_version: "v1",
    status: "pending",
    attempt_count: 0,
    last_attempt_at: null,
    lease_expires_at: null,
    last_error_code: null,
    createdAt: 0,
  });
  repo.endpoints.set("user-1", [
    {
      id: "endpoint-1",
      user_id: "user-1",
      provider: "fcm",
      platform: "android",
      device_token: "token-1",
      endpoint: null,
      p256dh: null,
      auth: null,
      active: true,
    },
  ]);

  const fcm = new ScriptedProvider({
    "endpoint-1": {
      ok: false,
      retryable: true,
      deactivateEndpoint: false,
      errorCode: "fcm_server_error",
    },
  });
  const engine = buildEngine({ repository: repo, fcmProvider: fcm });
  await engine.runProcessPending();

  assertEquals(repo.deliveries[0].status, "failed");
  assertEquals(repo.deliveries[0].attempt_count, 1);
});

Deno.test("Web Push success marks the delivery sent", async () => {
  const repo = new InMemoryRepository();
  repo.deliveries.push({
    id: "delivery-1",
    user_id: "user-1",
    category: "achievement",
    local_date: null,
    event_identifier: "ach-1",
    event_version: "v1",
    status: "pending",
    attempt_count: 0,
    last_attempt_at: null,
    lease_expires_at: null,
    last_error_code: null,
    createdAt: 0,
  });
  repo.endpoints.set("user-1", [
    {
      id: "endpoint-web",
      user_id: "user-1",
      provider: "web_push",
      platform: "web",
      device_token: null,
      endpoint: "https://example.com/push",
      p256dh: "p256dh",
      auth: "auth",
      active: true,
    },
  ]);

  const webPush = new ScriptedProvider({ "endpoint-web": { ok: true } });
  const engine = buildEngine({ repository: repo, webPushProvider: webPush });
  const result = await engine.runProcessPending();

  assertEquals(result.sent, 1);
  assertEquals(repo.deliveries[0].status, "sent");
});

Deno.test("Web Push 404 and 410 deactivate the endpoint", async () => {
  const repo = new InMemoryRepository();
  repo.deliveries.push({
    id: "delivery-1",
    user_id: "user-1",
    category: "achievement",
    local_date: null,
    event_identifier: "ach-1",
    event_version: "v1",
    status: "pending",
    attempt_count: 0,
    last_attempt_at: null,
    lease_expires_at: null,
    last_error_code: null,
    createdAt: 0,
  });
  repo.endpoints.set("user-1", [
    {
      id: "endpoint-web",
      user_id: "user-1",
      provider: "web_push",
      platform: "web",
      device_token: null,
      endpoint: "https://example.com/push",
      p256dh: "p256dh",
      auth: "auth",
      active: true,
    },
  ]);

  const webPush = new ScriptedProvider({
    "endpoint-web": {
      ok: false,
      retryable: false,
      deactivateEndpoint: true,
      errorCode: "web_push_unregistered",
    },
  });
  const engine = buildEngine({ repository: repo, webPushProvider: webPush });
  await engine.runProcessPending();

  assertEquals(repo.endpoints.get("user-1")?.[0].active, false);
  assertEquals(repo.deliveries[0].status, "failed");
});

Deno.test("Web Push 429 stays retryable", async () => {
  const repo = new InMemoryRepository();
  repo.deliveries.push({
    id: "delivery-1",
    user_id: "user-1",
    category: "achievement",
    local_date: null,
    event_identifier: "ach-1",
    event_version: "v1",
    status: "pending",
    attempt_count: 0,
    last_attempt_at: null,
    lease_expires_at: null,
    last_error_code: null,
    createdAt: 0,
  });
  repo.endpoints.set("user-1", [
    {
      id: "endpoint-web",
      user_id: "user-1",
      provider: "web_push",
      platform: "web",
      device_token: null,
      endpoint: "https://example.com/push",
      p256dh: "p256dh",
      auth: "auth",
      active: true,
    },
  ]);

  const webPush = new ScriptedProvider({
    "endpoint-web": {
      ok: false,
      retryable: true,
      deactivateEndpoint: false,
      errorCode: "web_push_rate_limited",
    },
  });
  const engine = buildEngine({ repository: repo, webPushProvider: webPush });
  await engine.runProcessPending();

  assertEquals(repo.deliveries[0].status, "failed");
  assertEquals(repo.deliveries[0].attempt_count, 1);
});

Deno.test("multiple endpoints allow one success to complete delivery", async () => {
  const repo = new InMemoryRepository();
  repo.deliveries.push({
    id: "delivery-1",
    user_id: "user-1",
    category: "daily_goal",
    local_date: "2026-08-23",
    event_identifier: null,
    event_version: "v1",
    status: "pending",
    attempt_count: 0,
    last_attempt_at: null,
    lease_expires_at: null,
    last_error_code: null,
    createdAt: 0,
  });
  repo.endpoints.set("user-1", [
    {
      id: "endpoint-1",
      user_id: "user-1",
      provider: "fcm",
      platform: "android",
      device_token: "token-1",
      endpoint: null,
      p256dh: null,
      auth: null,
      active: true,
    },
    {
      id: "endpoint-2",
      user_id: "user-1",
      provider: "web_push",
      platform: "web",
      device_token: null,
      endpoint: "https://example.com/ok",
      p256dh: "p256dh",
      auth: "auth",
      active: true,
    },
  ]);

  const fcm = new ScriptedProvider({
    "endpoint-1": {
      ok: false,
      retryable: true,
      deactivateEndpoint: false,
      errorCode: "fcm_rate_limited",
    },
  });
  const webPush = new ScriptedProvider({
    "endpoint-2": { ok: true },
  });
  const engine = buildEngine({
    repository: repo,
    fcmProvider: fcm,
    webPushProvider: webPush,
  });
  const result = await engine.runProcessPending();

  assertEquals(result.sent, 1);
  assertEquals(repo.deliveries[0].status, "sent");
  assertEquals(fcm.calls.length, 1);
  assertEquals(webPush.calls.length, 1);
});

Deno.test("no active endpoints fails cleanly", async () => {
  const repo = new InMemoryRepository();
  repo.deliveries.push({
    id: "delivery-1",
    user_id: "user-1",
    category: "achievement",
    local_date: null,
    event_identifier: "ach-1",
    event_version: "v1",
    status: "pending",
    attempt_count: 0,
    last_attempt_at: null,
    lease_expires_at: null,
    last_error_code: null,
    createdAt: 0,
  });
  const engine = buildEngine({ repository: repo });
  await engine.runProcessPending();

  assertEquals(repo.deliveries[0].status, "failed");
  assertEquals(repo.deliveries[0].last_error_code, "no_active_endpoints");
});

Deno.test("duplicate scheduled delivery is deduplicated", async () => {
  const repo = new InMemoryRepository();
  repo.notificationSettings = [
    {
      user_id: "user-1",
      notifications_enabled: true,
      daily_prep_reminder_enabled: true,
      daily_goal_reminder_enabled: true,
      achievement_notifications_enabled: true,
      streak_reminder_enabled: true,
      preferred_reminder_time: "19:00",
      streak_reminder_time: "19:00",
      timezone: "UTC",
    },
  ];
  repo.userPreferences.set("user-1", {
    user_id: "user-1",
    daily_goal: 2,
  });
  const engine = buildEngine({ repository: repo });
  repo.now = new Date("2026-08-23T19:02:00.000Z");

  const first = await engine.runScheduled();
  const second = await engine.runScheduled();

  assertEquals(first.enqueued > 0, true);
  assertEquals(second.enqueued, 0);
  assertEquals(repo.deliveries.length, first.enqueued);
});

Deno.test("expired lease can be reclaimed", async () => {
  const repo = new InMemoryRepository();
  repo.deliveries.push({
    id: "delivery-1",
    user_id: "user-1",
    category: "daily_prep",
    local_date: "2026-08-23",
    event_identifier: null,
    event_version: "v1",
    status: "sending",
    attempt_count: 1,
    last_attempt_at: "2026-08-23T12:00:00.000Z",
    lease_expires_at: "2026-08-23T13:00:00.000Z",
    last_error_code: "retryable_delivery_failure",
    createdAt: 0,
  });
  repo.endpoints.set("user-1", [
    {
      id: "endpoint-1",
      user_id: "user-1",
      provider: "fcm",
      platform: "android",
      device_token: "token-1",
      endpoint: null,
      p256dh: null,
      auth: null,
      active: true,
    },
  ]);
  repo.now = new Date("2026-08-23T14:30:00.000Z");
  const fcm = new ScriptedProvider({ "endpoint-1": { ok: true } });
  const engine = buildEngine({ repository: repo, fcmProvider: fcm });
  const result = await engine.runProcessPending();

  assertEquals(result.claimed, 1);
  assertEquals(repo.deliveries[0].status, "sent");
  assertEquals(repo.deliveries[0].attempt_count, 2);
});

Deno.test("retry behavior respects the backoff window and succeeds later", async () => {
  const repo = new InMemoryRepository();
  repo.deliveries.push({
    id: "delivery-1",
    user_id: "user-1",
    category: "daily_prep",
    local_date: "2026-08-23",
    event_identifier: null,
    event_version: "v1",
    status: "failed",
    attempt_count: 1,
    last_attempt_at: "2026-08-23T12:00:00.000Z",
    lease_expires_at: null,
    last_error_code: "retryable_delivery_failure",
    createdAt: 0,
  });
  repo.endpoints.set("user-1", [
    {
      id: "endpoint-1",
      user_id: "user-1",
      provider: "fcm",
      platform: "android",
      device_token: "token-1",
      endpoint: null,
      p256dh: null,
      auth: null,
      active: true,
    },
  ]);
  repo.now = new Date("2026-08-23T12:00:30.000Z");
  const fcm = new ScriptedProvider({
    "endpoint-1": {
      ok: false,
      retryable: true,
      deactivateEndpoint: false,
      errorCode: "fcm_rate_limited",
    },
  });
  const engine = buildEngine({ repository: repo, fcmProvider: fcm });

  const first = await engine.runProcessPending();
  assertEquals(first.claimed, 0);

  repo.now = new Date("2026-08-23T12:02:10.000Z");
  fcm.setOutcome({ "endpoint-1": { ok: true } });
  const second = await engine.runProcessPending();
  assertEquals(second.claimed, 1);
  assertEquals(repo.deliveries[0].status, "sent");
});

Deno.test("six attempt limit blocks further claims", async () => {
  const repo = new InMemoryRepository();
  repo.deliveries.push({
    id: "delivery-1",
    user_id: "user-1",
    category: "daily_prep",
    local_date: "2026-08-23",
    event_identifier: null,
    event_version: "v1",
    status: "failed",
    attempt_count: 6,
    last_attempt_at: "2026-08-23T12:00:00.000Z",
    lease_expires_at: null,
    last_error_code: "retryable_delivery_failure",
    createdAt: 0,
  });
  const engine = buildEngine({ repository: repo });
  const result = await engine.runProcessPending();

  assertEquals(result.claimed, 0);
});

Deno.test("disabled notification settings do not enqueue reminders", async () => {
  const repo = new InMemoryRepository();
  repo.notificationSettings = [
    {
      user_id: "user-1",
      notifications_enabled: false,
      daily_prep_reminder_enabled: true,
      daily_goal_reminder_enabled: true,
      achievement_notifications_enabled: true,
      streak_reminder_enabled: true,
      preferred_reminder_time: "19:00",
      streak_reminder_time: "19:00",
      timezone: "UTC",
    },
  ];
  const engine = buildEngine({ repository: repo });
  repo.now = new Date("2026-08-23T19:02:00.000Z");

  const result = await engine.runScheduled();

  assertEquals(result.enqueued, 0);
  assertEquals(repo.deliveries.length, 0);
});

Deno.test("timezone-aware scheduling uses the user timezone", async () => {
  const repo = new InMemoryRepository();
  repo.notificationSettings = [
    {
      user_id: "user-1",
      notifications_enabled: true,
      daily_prep_reminder_enabled: true,
      daily_goal_reminder_enabled: false,
      achievement_notifications_enabled: false,
      streak_reminder_enabled: false,
      preferred_reminder_time: "19:00",
      streak_reminder_time: "19:00",
      timezone: "America/New_York",
    },
  ];
  repo.now = new Date("2026-08-23T23:02:00.000Z");
  const engine = buildEngine({ repository: repo });

  const result = await engine.runScheduled();

  assertEquals(result.enqueued, 1);
  assertEquals(repo.deliveries[0].local_date, "2026-08-23");
});

Deno.test("daily goal reminder only fires when the user is below target", async () => {
  const repo = new InMemoryRepository();
  repo.notificationSettings = [
    {
      user_id: "user-1",
      notifications_enabled: true,
      daily_prep_reminder_enabled: false,
      daily_goal_reminder_enabled: true,
      achievement_notifications_enabled: false,
      streak_reminder_enabled: false,
      preferred_reminder_time: "19:00",
      streak_reminder_time: "19:00",
      timezone: "UTC",
    },
  ];
  repo.userPreferences.set("user-1", {
    user_id: "user-1",
    daily_goal: 2,
  });
  repo.progressRows.set("user-1", [
    { user_id: "user-1", completed_at: "2026-08-23T10:00:00.000Z" },
  ]);
  repo.now = new Date("2026-08-23T19:02:00.000Z");
  const engine = buildEngine({ repository: repo });

  const result = await engine.runScheduled();

  assertEquals(result.enqueued, 1);
});

Deno.test("daily goal reminder does not fire when the target is already met", async () => {
  const repo = new InMemoryRepository();
  repo.notificationSettings = [
    {
      user_id: "user-1",
      notifications_enabled: true,
      daily_prep_reminder_enabled: false,
      daily_goal_reminder_enabled: true,
      achievement_notifications_enabled: false,
      streak_reminder_enabled: false,
      preferred_reminder_time: "19:00",
      streak_reminder_time: "19:00",
      timezone: "UTC",
    },
  ];
  repo.userPreferences.set("user-1", {
    user_id: "user-1",
    daily_goal: 1,
  });
  repo.progressRows.set("user-1", [
    { user_id: "user-1", completed_at: "2026-08-23T10:00:00.000Z" },
  ]);
  repo.now = new Date("2026-08-23T19:02:00.000Z");
  const engine = buildEngine({ repository: repo });

  const result = await engine.runScheduled();

  assertEquals(result.enqueued, 0);
});

Deno.test("streak reminder only fires for an existing streak with no completion today", async () => {
  const repo = new InMemoryRepository();
  repo.notificationSettings = [
    {
      user_id: "user-1",
      notifications_enabled: true,
      daily_prep_reminder_enabled: false,
      daily_goal_reminder_enabled: false,
      achievement_notifications_enabled: false,
      streak_reminder_enabled: true,
      preferred_reminder_time: "19:00",
      streak_reminder_time: "19:00",
      timezone: "UTC",
    },
  ];
  repo.progressRows.set("user-1", [
    { user_id: "user-1", completed_at: "2026-08-21T10:00:00.000Z" },
    { user_id: "user-1", completed_at: "2026-08-22T10:00:00.000Z" },
  ]);
  repo.now = new Date("2026-08-23T19:02:00.000Z");
  const engine = buildEngine({ repository: repo });

  const result = await engine.runScheduled();

  assertEquals(result.enqueued, 1);
});

Deno.test("achievement deliveries are processed", async () => {
  const repo = new InMemoryRepository();
  repo.deliveries.push({
    id: "delivery-1",
    user_id: "user-1",
    category: "achievement",
    local_date: null,
    event_identifier: "first-blood",
    event_version: "v1",
    status: "pending",
    attempt_count: 0,
    last_attempt_at: null,
    lease_expires_at: null,
    last_error_code: null,
    createdAt: 0,
  });
  repo.endpoints.set("user-1", [
    {
      id: "endpoint-1",
      user_id: "user-1",
      provider: "fcm",
      platform: "android",
      device_token: "token-1",
      endpoint: null,
      p256dh: null,
      auth: null,
      active: true,
    },
  ]);
  const fcm = new ScriptedProvider({ "endpoint-1": { ok: true } });
  const engine = buildEngine({ repository: repo, fcmProvider: fcm });

  const result = await engine.runProcessPending();

  assertEquals(result.sent, 1);
  assertEquals(repo.deliveries[0].category, "achievement");
});

Deno.test("helper functions preserve local-date semantics", () => {
  const zoned = toZonedCalendar(
    new Date("2026-08-23T23:30:00.000Z"),
    "Asia/Kolkata",
  );

  assertEquals(formatDateKey(zoned), "2026-08-24");
  assertEquals(normalizeTimeZone("America/New_York"), "America/New_York");
  assertEquals(
    countCompletedToday(
      [{ user_id: "user-1", completed_at: "2026-08-23T23:30:00.000Z" }],
      "Asia/Kolkata",
      new Date("2026-08-23T23:45:00.000Z"),
    ),
    1,
  );
  assertEquals(
    isWithinReminderWindow(
      { year: 2026, month: 8, day: 24, hour: 19, minute: 2, second: 0 },
      "19:00",
    ),
    true,
  );
  assertEquals(
    calculateStreak(
      [
        { user_id: "user-1", completed_at: "2026-08-21T10:00:00.000Z" },
        { user_id: "user-1", completed_at: "2026-08-22T10:00:00.000Z" },
      ],
      "UTC",
      new Date("2026-08-23T19:02:00.000Z"),
    ),
    { current: 2, longest: 2 },
  );
});
