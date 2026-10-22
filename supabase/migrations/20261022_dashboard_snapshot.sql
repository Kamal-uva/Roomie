-- Apply this migration BEFORE deploying the matching frontend.
-- SECURITY INVOKER preserves the caller's existing row-level security policies.
create or replace function public.get_room_dashboard(p_room_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'room', (select to_jsonb(r) from public.rooms r where r.id = p_room_id),
    'members', coalesce((
      select jsonb_agg(to_jsonb(m) order by m.joined_at, m.user_id)
      from public.room_members m where m.room_id = p_room_id
    ), '[]'::jsonb),
    'activities', coalesce((
      select jsonb_agg(to_jsonb(a) order by a.created_at desc, a.id desc)
      from (select * from public.activity where room_id = p_room_id
            order by created_at desc, id desc limit 100) a
    ), '[]'::jsonb),
    'laundry', coalesce((
      select jsonb_agg(to_jsonb(l)) from public.laundry l where l.room_id = p_room_id
    ), '[]'::jsonb),
    'lastTrash', (
      select to_jsonb(a) from public.activity a
      where a.room_id = p_room_id and a.kind = 'trash'
      order by a.created_at desc, a.id desc limit 1
    ),
    'lastVacuum', (
      select to_jsonb(a) from public.activity a
      where a.room_id = p_room_id and a.kind = 'vacuum'
      order by a.created_at desc, a.id desc limit 1
    )
  )
  where exists (
    select 1 from public.room_members m
    where m.room_id = p_room_id and m.user_id = (select auth.uid())
  );
$$;

revoke all on function public.get_room_dashboard(uuid) from public;
grant execute on function public.get_room_dashboard(uuid) to authenticated;
