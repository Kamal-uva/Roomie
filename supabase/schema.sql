-- Fresh Supabase project only; do not rerun on an existing Roomie project.
create table public.rooms(id uuid primary key default gen_random_uuid(),name text not null,invite_code text not null unique,created_at timestamptz not null default now());
create table public.room_members(room_id uuid not null references public.rooms(id) on delete cascade,user_id uuid not null references auth.users(id) on delete cascade,display_name text not null,joined_at timestamptz not null default now(),primary key(room_id,user_id),unique(user_id));
create table public.activity(id bigint generated always as identity primary key,room_id uuid not null references public.rooms(id) on delete cascade,kind text not null check(kind in('trash','vacuum','washer','dryer')),member_id uuid not null references auth.users(id),actor_id uuid not null references auth.users(id),created_at timestamptz not null default now());
create table public.laundry(room_id uuid not null references public.rooms(id) on delete cascade,machine text not null check(machine in('washer','dryer')),owner_id uuid references auth.users(id),updated_at timestamptz not null default now(),primary key(room_id,machine));
create index activity_room_date on public.activity(room_id,created_at desc);
alter table public.rooms enable row level security;
alter table public.room_members enable row level security;
alter table public.activity enable row level security;
alter table public.laundry enable row level security;
create function public.is_room_member(p_room_id uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.room_members where room_id=p_room_id and user_id=auth.uid())$$;
create policy rooms_read on public.rooms for select to authenticated using(public.is_room_member(id));
create policy members_read on public.room_members for select to authenticated using(public.is_room_member(room_id));
create policy activity_read on public.activity for select to authenticated using(public.is_room_member(room_id));
create policy laundry_read on public.laundry for select to authenticated using(public.is_room_member(room_id));
create function public.create_room(p_room_name text,p_display_name text) returns uuid language plpgsql security definer set search_path='' as $$
declare rid uuid; code text;
begin
if auth.uid() is null then raise exception 'Sign in first'; end if;
if exists(select 1 from public.room_members where user_id=auth.uid()) then raise exception 'Already in an apartment'; end if;
if length(trim(p_room_name)) not between 1 and 40 or length(trim(p_display_name)) not between 1 and 24 then raise exception 'Invalid names'; end if;
loop
code:=upper(substring(replace(pg_catalog.gen_random_uuid()::text,'-','') from 1 for 6));
begin insert into public.rooms(name,invite_code) values(trim(p_room_name),code) returning id into rid;exit;
exception when unique_violation then null;end;
end loop;
insert into public.room_members(room_id,user_id,display_name) values(rid,auth.uid(),trim(p_display_name));
insert into public.laundry(room_id,machine) values(rid,'washer'),(rid,'dryer');
return rid;
end $$;
create function public.join_room(p_invite_code text,p_display_name text) returns uuid language plpgsql security definer set search_path='' as $$
declare rid uuid; people int;
begin
if auth.uid() is null then raise exception 'Sign in first';end if;
if exists(select 1 from public.room_members where user_id=auth.uid()) then raise exception 'Already in an apartment';end if;
if length(trim(p_display_name)) not between 1 and 24 then raise exception 'Invalid name';end if;
select id into rid from public.rooms where invite_code=upper(trim(p_invite_code)) for update;
if rid is null then raise exception 'Invite code not found';end if;
select count(*) into people from public.room_members where room_id=rid;
if people>=4 then raise exception 'Apartment is full';end if;
insert into public.room_members(room_id,user_id,display_name) values(rid,auth.uid(),trim(p_display_name));
return rid;
end $$;
create function public.log_chore(p_kind text,p_member_id uuid) returns void language plpgsql security definer set search_path='' as $$
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
select coalesce((select rm2.user_id from public.room_members rm2 where rm2.room_id=rid and (rm2.joined_at,rm2.user_id)>(lastm.joined_at,lastm.user_id) order by rm2.joined_at,rm2.user_id limit 1),expected) into expected
from(select rm.joined_at,rm.user_id from public.activity a join public.room_members rm on rm.user_id=a.member_id and rm.room_id=a.room_id where a.room_id=rid and a.kind='vacuum' order by a.created_at desc,a.id desc limit 1) lastm;
if p_member_id is distinct from expected then raise exception 'Vacuum turn changed, refresh';end if;
end if;
insert into public.activity(room_id,kind,member_id,actor_id) values(rid,p_kind,p_member_id,auth.uid());
end $$;
create function public.update_machine(p_machine text,p_owner_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare rid uuid;
begin
if p_machine not in('washer','dryer') then raise exception 'Invalid machine';end if;
select room_id into rid from public.room_members where user_id=auth.uid();
if rid is null then raise exception 'Not in apartment';end if;
if p_owner_id is not null and not exists(select 1 from public.room_members where room_id=rid and user_id=p_owner_id) then raise exception 'Not a roommate';end if;
update public.laundry set owner_id=p_owner_id,updated_at=now() where room_id=rid and machine=p_machine;
insert into public.activity(room_id,kind,member_id,actor_id) values(rid,p_machine,coalesce(p_owner_id,auth.uid()),auth.uid());
end $$;
revoke all on function public.is_room_member(uuid) from public;
revoke all on function public.create_room(text,text) from public;
revoke all on function public.join_room(text,text) from public;
revoke all on function public.log_chore(text,uuid) from public;
revoke all on function public.update_machine(text,uuid) from public;
grant execute on function public.is_room_member(uuid) to authenticated;
grant execute on function public.create_room(text,text) to authenticated;
grant execute on function public.join_room(text,text) to authenticated;
grant execute on function public.log_chore(text,uuid) to authenticated;
grant execute on function public.update_machine(text,uuid) to authenticated;
alter publication supabase_realtime add table public.rooms;
alter publication supabase_realtime add table public.room_members;
alter publication supabase_realtime add table public.activity;
alter publication supabase_realtime add table public.laundry;