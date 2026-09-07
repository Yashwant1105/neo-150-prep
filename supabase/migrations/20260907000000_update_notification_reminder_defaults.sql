alter table public.notification_settings
  alter column streak_reminder_time set default '14:30:00'::time,
  alter column preferred_reminder_time set default '14:30:00'::time;