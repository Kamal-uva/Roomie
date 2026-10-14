-- Apply ONCE to existing Supabase Roomie databases via SQL Editor.
-- This does not recreate tables or erase any data.
create or replace function public.log_chore(p_kind text,p_member_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare rid uuid; expected uuid;
begin
if p_kind not in('trash','vacuum') then raise exception 'Invalid chore';end if;
select room_id into rid from public.room_members where user_id=auth.uid();
if rid is null then raise exception 'Not in apartment';end if;
if not exists(select 1 from public.room_members where room_id=rid and user_id=p_member_id) then raise exception 'Not a roommate';end if;
if p_kind='trash' and p_member_id<>auth.uid() then raise exception 'You can only log your own trash duty';end if;
if p_kind='vacuum' then
perform 1 from public.rooms where id=rid for update;
select rm.user_id into expected from public.room_members rm where rm.room_id=rid order by rm.joined_at,rm.user_id limit 1;
-- A scalar subquery preserves the first roommate when no vacuum log exists.
select coalesce((
  select rm2.user_id from public.room_members rm2
  join public.room_members lastm on lastm.room_id=rid
  where lastm.user_id=(
    select a.member_id from public.activity a
    where a.room_id=rid and a.kind='vacuum'
    order by a.created_at desc,a.id desc limit 1
  )
  and rm2.room_id=rid
  and (rm2.joined_at,rm2.user_id)>(lastm.joined_at,lastm.user_id)
  order by rm2.joined_at,rm2.user_id limit 1
),expected) into expected;
if p_member_id is distinct from expected then raise exception 'Vacuum turn changed, refresh';end if;
end if;
insert into public.activity(room_id,kind,member_id,actor_id) values(rid,p_kind,p_member_id,auth.uid());
end $$;

