create table public.home_board_posts (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 author_name text not null check (length(btrim(author_name)) between 1 and 30),
 category text not null check(category in ('general','learning','games','music')),
 title text not null check(length(btrim(title)) between 1 and 100),
 body text not null check(length(btrim(body)) between 1 and 10000),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index home_board_posts_created_idx on public.home_board_posts(created_at desc,id);
create index home_board_posts_owner_idx on public.home_board_posts(user_id,created_at desc);
alter table public.home_board_posts enable row level security;
revoke all on public.home_board_posts from anon,authenticated;
grant select on public.home_board_posts to anon,authenticated;
grant insert(user_id,author_name,category,title,body) on public.home_board_posts to authenticated;
grant update(author_name,category,title,body) on public.home_board_posts to authenticated;
grant delete on public.home_board_posts to authenticated;
create policy board_public_read on public.home_board_posts for select to anon,authenticated using(true);
create policy board_own_insert on public.home_board_posts for insert to authenticated with check((select auth.uid())=user_id and not coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false));
create policy board_own_update on public.home_board_posts for update to authenticated using((select auth.uid())=user_id) with check((select auth.uid())=user_id);
create policy board_own_delete on public.home_board_posts for delete to authenticated using((select auth.uid())=user_id);
create function public.home_board_guard() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if TG_OP='INSERT' then
  perform pg_advisory_xact_lock(hashtextextended(new.user_id::text,273));
  if (select count(*) from public.home_board_posts where user_id=new.user_id and created_at>now()-interval '1 day')>=10 then
   raise exception '하루에 글을 10개까지 작성할 수 있습니다.' using errcode='23514';
  end if;
 end if;
 if TG_OP='INSERT' then new.updated_at=new.created_at; else new.updated_at=clock_timestamp(); end if;
 return new;
end; $$;
revoke all on function public.home_board_guard() from public,anon,authenticated;
create trigger home_board_guard before insert or update on public.home_board_posts for each row execute function public.home_board_guard();