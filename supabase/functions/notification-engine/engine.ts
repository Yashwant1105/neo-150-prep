export type NotificationMode = "scheduled" | "process-pending";
export type NotificationCategory =
  | "daily_prep"
  | "daily_goal"
  | "streak"
  | "achievement";

export interface NotificationSettingsRow {
  user_id: string;
  notifications_enabled: boolean;
  daily_prep_reminder_enabled: boolean;
  daily_goal_reminder_enabled: boolean;
  achievement_notifications_enabled: boolean;
  streak_reminder_enabled: boolean;
  preferred_reminder_time: string;
  streak_reminder_time: string;
  timezone: string;
}

export interface UserPreferenceRow {
  user_id: string;
  daily_goal?: number | null;
  daily_focus_date?: string | null;
  daily_focus_topics?: string[] | null;
}

export interface CompletedProgressRow {
  user_id: string;
  completed_at: string | null;
}

export interface NotificationDeliveryRow {
  id: string;
  user_id: string;
  category: NotificationCategory;
  local_date: string | null;
  event_identifier: string | null;
  event_version: string;
  status: "pending" | "sending" | "sent" | "failed";
  attempt_count: number;
  last_attempt_at: string | null;
  lease_expires_at: string | null;
  last_error_code: string | null;
}

export interface NotificationEndpointRow {
  id: string;
  user_id: string;
  provider: "fcm" | "web_push";
  platform: "android" | "ios" | "web";
  device_token: string | null;
  endpoint: string | null;
  p256dh: string | null;
  auth: string | null;
  active: boolean;
}

export interface NotificationPayload {
  title: string;
  body: string;
  data: {
    category: string;
    destination: string;
    entity_id: string | null;
    event_identifier: string | null;
    event_version: string;
  };
}

export interface NotificationRepository {
  listNotificationSettings(): Promise<NotificationSettingsRow[]>;
  listUserPreferences(userIds: string[]): Promise<UserPreferenceRow[]>;
  listCompletedProgress(userIds: string[]): Promise<CompletedProgressRow[]>;
  enqueueNotificationDelivery(input: {
    userId: string;
    category: NotificationCategory;
    localDate: string | null;
    eventIdentifier: string | null;
    eventVersion: string;
  }): Promise<string | null>;
  listDeliveriesToProcess(limit: number): Promise<NotificationDeliveryRow[]>;
  claimNotificationDelivery(
    deliveryId: string,
    leaseSeconds: number,
  ): Promise<NotificationDeliveryRow | null>;
  completeNotificationDelivery(
    deliveryId: string,
    succeeded: boolean,
    errorCode?: string | null,
  ): Promise<boolean>;
  listActiveEndpoints(userId: string): Promise<NotificationEndpointRow[]>;
  deactivateEndpoint(endpointId: string): Promise<void>;
}

export type ProviderOutcome =
  | {
    ok: true;
  }
  | {
    ok: false;
    retryable: boolean;
    deactivateEndpoint: boolean;
    errorCode: string;
  };

export interface NotificationProvider {
  send(
    endpoint: NotificationEndpointRow,
    payload: NotificationPayload,
  ): Promise<ProviderOutcome>;
}

export interface NotificationEngineDependencies {
  repository: NotificationRepository;
  fcmProvider: NotificationProvider;
  webPushProvider: NotificationProvider;
  schedulerKey: string;
  clock?: { now(): Date };
  logger?: Pick<Console, "info" | "warn" | "error" | "debug">;
  claimLeaseSeconds?: number;
  pendingBatchSize?: number;
  developmentMode?: boolean;
}

export interface ScheduledRunResult {
  inspected: number;
  enqueued: number;
}

export interface ProcessPendingResult {
  inspected: number;
  claimed: number;
  sent: number;
  failed: number;
}

export interface RequestContextResult {
  response: Response;
  scheduled?: ScheduledRunResult;
  processed?: ProcessPendingResult;
}

const DEFAULT_CLAIM_LEASE_SECONDS = 300;
const DEFAULT_PENDING_BATCH_SIZE = 50;
const REMINDER_WINDOW_MINUTES = 5;

export function createNotificationEngine(
  dependencies: NotificationEngineDependencies,
) {
  const clock = dependencies.clock ?? { now: () => new Date() };
  const logger =
    dependencies.logger ??
    ({
      info: () => {},
      warn: () => {},
      error: () => {},
      debug: () => {},
    } as Pick<Console, "info" | "warn" | "error" | "debug">);
  const claimLeaseSeconds =
    dependencies.claimLeaseSeconds ?? DEFAULT_CLAIM_LEASE_SECONDS;
  const pendingBatchSize =
    dependencies.pendingBatchSize ?? DEFAULT_PENDING_BATCH_SIZE;

  async function handleRequest(request: Request): Promise<Response> {
    if (request.method !== "POST" && request.method !== "GET") {
      return jsonResponse({ error: "Method not allowed." }, 405);
    }

    const providedKey =
      request.headers.get("x-notification-scheduler-key") ??
      bearerToken(request.headers.get("authorization"));

    if (!providedKey || !timingSafeEqual(providedKey, dependencies.schedulerKey)) {
      return jsonResponse({ error: "Unauthorized." }, 401);
    }

    const body = await readJsonBody(request);
    const mode = normalizeMode(
      body?.mode ??
        new URL(request.url).searchParams.get("mode") ??
        "scheduled",
    );

    if (!mode) {
      return jsonResponse({ error: "Invalid mode." }, 400);
    }

    if (mode === "scheduled") {
      const result = await runScheduled();
      return jsonResponse(result, 200);
    }

    const result = await runProcessPending();
    return jsonResponse(result, 200);
  }

  async function runScheduled(): Promise<ScheduledRunResult> {
    const settingsRows = await dependencies.repository.listNotificationSettings();
    const eligibleUsers = settingsRows.filter(
      (row) => row.notifications_enabled,
    );

    if (eligibleUsers.length === 0) {
      return { inspected: 0, enqueued: 0 };
    }

    const now = clock.now();
    const timezoneByUser = new Map<string, string>();
    const preferenceByUser = new Map<string, UserPreferenceRow>();

    for (const row of eligibleUsers) {
      timezoneByUser.set(row.user_id, normalizeTimeZone(row.timezone));
    }

    const userIds = eligibleUsers.map((row) => row.user_id);
    const [preferences, progressRows] = await Promise.all([
      dependencies.repository.listUserPreferences(userIds),
      dependencies.repository.listCompletedProgress(userIds),
    ]);

    for (const row of preferences) {
      preferenceByUser.set(row.user_id, row);
    }

    const progressByUser = groupBy(progressRows, (row) => row.user_id);

    let enqueued = 0;
    for (const settings of eligibleUsers) {
      const timezone = timezoneByUser.get(settings.user_id) ?? "UTC";
      const userPreferences = preferenceByUser.get(settings.user_id);
      const completedRows = progressByUser.get(settings.user_id) ?? [];
      const localNow = toZonedCalendar(now, timezone);
      const localDateKey = formatDateKey(localNow);

      if (
        settings.daily_prep_reminder_enabled &&
        isWithinReminderWindow(localNow, settings.preferred_reminder_time)
      ) {
        enqueued += await enqueueDelivery({
          userId: settings.user_id,
          category: "daily_prep",
          localDate: localDateKey,
          eventIdentifier: null,
          eventVersion: "v1",
        });
      }

      const goal = Math.max(
        0,
        Math.trunc(userPreferences?.daily_goal ?? 2),
      );
      const completedToday = countCompletedToday(completedRows, timezone, now);

      if (
        settings.daily_goal_reminder_enabled &&
        goal > 0 &&
        isWithinReminderWindow(localNow, settings.preferred_reminder_time) &&
        completedToday < goal
      ) {
        enqueued += await enqueueDelivery({
          userId: settings.user_id,
          category: "daily_goal",
          localDate: localDateKey,
          eventIdentifier: null,
          eventVersion: "v1",
        });
      }

      const streak = calculateStreak(completedRows, timezone, now);
      if (
        settings.streak_reminder_enabled &&
        streak.current > 0 &&
        completedToday === 0 &&
        isWithinReminderWindow(localNow, settings.streak_reminder_time)
      ) {
        enqueued += await enqueueDelivery({
          userId: settings.user_id,
          category: "streak",
          localDate: localDateKey,
          eventIdentifier: null,
          eventVersion: "v1",
        });
      }
    }

    return { inspected: eligibleUsers.length, enqueued };
  }

  async function runProcessPending(): Promise<ProcessPendingResult> {
    const deliveries = await dependencies.repository.listDeliveriesToProcess(
      pendingBatchSize,
    );

    let claimed = 0;
    let sent = 0;
    let failed = 0;

    for (const delivery of deliveries) {
      const claim = await dependencies.repository.claimNotificationDelivery(
        delivery.id,
        claimLeaseSeconds,
      );

      if (!claim) {
        continue;
      }

      claimed++;
      const result = await processClaimedDelivery(claim);
      if (result) {
        sent++;
      } else {
        failed++;
      }
    }

    return {
      inspected: deliveries.length,
      claimed,
      sent,
      failed,
    };
  }

  async function enqueueDelivery(input: {
    userId: string;
    category: NotificationCategory;
    localDate: string;
    eventIdentifier: string | null;
    eventVersion: string;
  }): Promise<number> {
    const deliveryId = await dependencies.repository.enqueueNotificationDelivery({
      userId: input.userId,
      category: input.category,
      localDate: input.localDate,
      eventIdentifier: input.eventIdentifier,
      eventVersion: input.eventVersion,
    });

    return deliveryId ? 1 : 0;
  }

  async function processClaimedDelivery(
    delivery: NotificationDeliveryRow,
  ): Promise<boolean> {
    const endpoints = await dependencies.repository.listActiveEndpoints(
      delivery.user_id,
    );

    const notificationPayload = buildNotificationPayload(delivery);

    if (endpoints.length === 0) {
      logger.warn("No active notification endpoints.", {
        userId: delivery.user_id,
        deliveryId: delivery.id,
        category: delivery.category,
      });
      await dependencies.repository.completeNotificationDelivery(
        delivery.id,
        false,
        "no_active_endpoints",
      );
      return false;
    }

    let successCount = 0;
    let transientFailureCount = 0;
    let permanentFailureCount = 0;
    let lastErrorCode: string | null = null;

    for (const endpoint of endpoints) {
      const provider = getProvider(endpoint.provider);
      if (!provider) continue;

      try {
        const outcome = await provider.send(endpoint, notificationPayload);

        if (outcome.ok) {
          successCount++;
          continue;
        }

        lastErrorCode = outcome.errorCode;
        if (outcome.deactivateEndpoint) {
          await dependencies.repository.deactivateEndpoint(endpoint.id);
        }

        if (outcome.retryable) {
          transientFailureCount++;
        } else {
          permanentFailureCount++;
        }
      } catch (error) {
        transientFailureCount++;
        lastErrorCode = "provider_exception";
        logger.error("Notification provider error.", {
          userId: delivery.user_id,
          deliveryId: delivery.id,
          provider: endpoint.provider,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }

    if (successCount > 0) {
      await dependencies.repository.completeNotificationDelivery(
        delivery.id,
        true,
        null,
      );
      return true;
    }

    const code =
      lastErrorCode ??
      (transientFailureCount > 0
        ? "retryable_delivery_failure"
        : permanentFailureCount > 0
          ? "permanent_delivery_failure"
          : "no_active_endpoints");

    await dependencies.repository.completeNotificationDelivery(
      delivery.id,
      false,
      code,
    );
    return false;
  }

  function getProvider(provider: NotificationEndpointRow["provider"]) {
    if (provider === "fcm") {
      return dependencies.fcmProvider;
    }

    if (provider === "web_push") {
      return dependencies.webPushProvider;
    }

    return null;
  }

  return {
    handleRequest,
    runScheduled,
    runProcessPending,
  };
}

export function buildNotificationPayload(
  delivery: NotificationDeliveryRow,
): NotificationPayload {
  const commonData = {
    category: delivery.category,
    destination: "push",
    entity_id: delivery.event_identifier,
    event_identifier: delivery.event_identifier,
    event_version: delivery.event_version,
  };

  switch (delivery.category) {
    case "daily_goal":
      return {
        title: "Neo 150 Prep",
        body: "You are close to today's daily goal. Finish strong.",
        data: commonData,
      };
    case "streak":
      return {
        title: "Neo 150 Prep",
        body: "Your streak is alive. Complete one problem to protect it.",
        data: commonData,
      };
    case "achievement":
      return {
        title: "Neo 150 Prep",
        body: "You unlocked a new achievement.",
        data: commonData,
      };
    case "daily_prep":
    default:
      return {
        title: "Neo 150 Prep",
        body: "Your Daily Prep is ready.",
        data: commonData,
      };
  }
}

export function calculateStreak(
  rows: CompletedProgressRow[],
  timezone: string,
  now: Date,
): { current: number; longest: number } {
  const days = rows
    .map((row) => row.completed_at)
    .filter((value): value is string => !!value)
    .map((value) => formatDateKey(toZonedCalendar(new Date(value), timezone)))
    .sort();

  if (days.length === 0) {
    return { current: 0, longest: 0 };
  }

  const uniqueDays = [...new Set(days)];
  const daySet = new Set(uniqueDays);
  const today = formatDateKey(toZonedCalendar(now, timezone));
  let cursor = today;

  if (!daySet.has(cursor)) {
    cursor = previousDay(cursor);
  }

  let current = 0;
  while (daySet.has(cursor)) {
    current++;
    cursor = previousDay(cursor);
  }

  let longest = 1;
  let run = 1;
  for (let i = 1; i < uniqueDays.length; i++) {
    if (calendarDistance(uniqueDays[i - 1], uniqueDays[i]) === 1) {
      run++;
      if (run > longest) {
        longest = run;
      }
    } else {
      run = 1;
    }
  }

  return { current, longest };
}

export function countCompletedToday(
  rows: CompletedProgressRow[],
  timezone: string,
  now: Date,
): number {
  const today = formatDateKey(toZonedCalendar(now, timezone));
  return rows.filter((row) => {
    if (!row.completed_at) return false;
    return formatDateKey(
      toZonedCalendar(new Date(row.completed_at), timezone),
    ) === today;
  }).length;
}

export function isWithinReminderWindow(now: ZonedCalendar, time: string): boolean {
  const parsed = parseTimeOfDay(time);
  if (!parsed) return false;

  const currentMinutes = now.hour * 60 + now.minute;
  const dueMinutes = parsed.hour * 60 + parsed.minute;
  const delta = currentMinutes - dueMinutes;
  return delta >= 0 && delta < REMINDER_WINDOW_MINUTES;
}

export function toZonedCalendar(date: Date, timeZone: string): ZonedCalendar {
  const safeTimeZone = normalizeTimeZone(timeZone);
  try {
    const formatter = new Intl.DateTimeFormat("en-CA", {
      timeZone: safeTimeZone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hour12: false,
    });

    const parts = formatter.formatToParts(date);
    const year = readPart(parts, "year");
    const month = readPart(parts, "month");
    const day = readPart(parts, "day");
    const hour = readPart(parts, "hour");
    const minute = readPart(parts, "minute");
    const second = readPart(parts, "second");

    return {
      year,
      month,
      day,
      hour,
      minute,
      second,
    };
  } catch {
    return toZonedCalendar(date, "UTC");
  }
}

export function formatDateKey(value: {
  year: number;
  month: number;
  day: number;
}): string {
  return [
    value.year.toString().padStart(4, "0"),
    value.month.toString().padStart(2, "0"),
    value.day.toString().padStart(2, "0"),
  ].join("-");
}

export function normalizeTimeZone(timeZone: string | null | undefined): string {
  if (!timeZone || typeof timeZone !== "string") {
    return "UTC";
  }

  try {
    Intl.DateTimeFormat("en-US", { timeZone });
    return timeZone;
  } catch {
    return "UTC";
  }
}

function normalizeMode(value: unknown): NotificationMode | null {
  if (value === "scheduled" || value === "process-pending") {
    return value;
  }

  return null;
}

function parseTimeOfDay(time: string): { hour: number; minute: number } | null {
  const match = /^(\d{2}):(\d{2})(?::\d{2})?$/.exec(time);
  if (!match) return null;

  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (
    Number.isNaN(hour) ||
    Number.isNaN(minute) ||
    hour < 0 ||
    hour > 23 ||
    minute < 0 ||
    minute > 59
  ) {
    return null;
  }

  return { hour, minute };
}

function previousDay(dateKey: string): string {
  const [year, month, day] = dateKey.split("-").map((value) => Number(value));
  const previous = new Date(Date.UTC(year, month - 1, day - 1));
  return formatDateKey({
    year: previous.getUTCFullYear(),
    month: previous.getUTCMonth() + 1,
    day: previous.getUTCDate(),
  });
}

function calendarDistance(first: string, second: string): number {
  const [firstYear, firstMonth, firstDay] = first.split("-").map((value) =>
    Number(value)
  );
  const [secondYear, secondMonth, secondDay] = second.split("-").map((value) =>
    Number(value)
  );
  const firstUtc = Date.UTC(firstYear, firstMonth - 1, firstDay);
  const secondUtc = Date.UTC(secondYear, secondMonth - 1, secondDay);
  return Math.round((secondUtc - firstUtc) / (24 * 60 * 60 * 1000));
}

function readPart(
  parts: Intl.DateTimeFormatPart[],
  type: Intl.DateTimeFormatPartTypes,
): number {
  const part = parts.find((entry) => entry.type === type);
  return Number(part?.value ?? 0);
}

function groupBy<T, K>(items: T[], getKey: (item: T) => K): Map<K, T[]> {
  const map = new Map<K, T[]>();
  for (const item of items) {
    const key = getKey(item);
    const bucket = map.get(key);
    if (bucket) {
      bucket.push(item);
    } else {
      map.set(key, [item]);
    }
  }
  return map;
}

async function readJsonBody(request: Request): Promise<Record<string, unknown> | null> {
  try {
    const text = await request.text();
    if (!text.trim()) return null;

    const data = JSON.parse(text);
    return isPlainObject(data) ? data : null;
  } catch {
    return null;
  }
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === "object" && !Array.isArray(value);
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
    },
  });
}

function bearerToken(value: string | null): string | null {
  if (!value) return null;
  const match = /^Bearer\s+(.+)$/i.exec(value.trim());
  return match?.[1] ?? null;
}

function timingSafeEqual(left: string, right: string): boolean {
  const leftBytes = new TextEncoder().encode(left);
  const rightBytes = new TextEncoder().encode(right);
  const length = Math.max(leftBytes.length, rightBytes.length);
  let mismatch = leftBytes.length === rightBytes.length ? 0 : 1;

  for (let i = 0; i < length; i++) {
    const leftByte = leftBytes[i] ?? 0;
    const rightByte = rightBytes[i] ?? 0;
    mismatch |= leftByte ^ rightByte;
  }

  return mismatch === 0;
}

interface ZonedCalendar {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
}
