create or replace function public.enqueue_achievement_notification()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
begin
  if exists (
    select 1
    from public.notification_settings as settings
    where settings.user_id = new.user_id
      and settings.notifications_enabled = true
      and settings.achievement_notifications_enabled = true
  ) then
    perform public.enqueue_notification_delivery(
      new.user_id,
      'achievement',
      null,
      new.achievement_id::text,
      'v1'
    );
  end if;

  return new;
end;
$$;
do $$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgname = 'enqueue_achievement_notification_after_insert'
      and tgrelid = 'public.user_achievements'::regclass
      and not tgisinternal
  ) then
    create trigger enqueue_achievement_notification_after_insert
      after insert on public.user_achievements
      for each row
      execute function public.enqueue_achievement_notification();
  end if;
end;
$$;