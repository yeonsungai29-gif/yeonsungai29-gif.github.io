create table public.home_board_comments(
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references public.home_board_posts(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 author_name text not null check(length(btrim(author_name)) between 1 and 30),
 body text not null check(length(btrim(body)) between 1 and 2000),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index home_board_comments_post_idx on public.home_board_comments(post_id,created_at,id);
create index home_board_comments_owner_idx on public.home_board_comments(user_id,created_at);
alter table public.home_board_comments enable row level security;
revoke all on public.home_board_comments from anon,authenticated;
grant select on public.home_board_comments to anon,authenticated;
grant insert(post_id,user_id,author_name,body) on public.home_board_comments to authenticated;
grant update(author_name,body) on public.home_board_comments to authenticated;
grant delete on public.home_board_comments to authenticated;
create policy comments_read on public.home_board_comments for select to anon,authenticated using(true);
create policy comments_insert on public.home_board_comments for insert to authenticated with check((select auth.uid())=user_id and not coalesce(((select auth.jwt())->>'is_anonymous')::boolean,false));
create policy comments_update on public.home_board_comments for update to authenticated using((select auth.uid())=user_id) with check((select auth.uid())=user_id);
create policy comments_delete on public.home_board_comments for delete to authenticated using((select auth.uid())=user_id);
create function public.home_board_comment_guard() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if TG_OP='INSERT' then
  perform pg_advisory_xact_lock(hashtextextended(new.user_id::text,274));
  if (select count(*) from public.home_board_comments where user_id=new.user_id and created_at>now()-interval '1 day')>=30 then raise exception '하루 댓글 작성 한도는 30개입니다.' using errcode='23514';end if;
  new.updated_at=new.created_at;
 else new.updated_at=clock_timestamp();end if;
 return new;
end;$$;
revoke all on function public.home_board_comment_guard() from public,anon,authenticated;
create trigger home_board_comment_guard before insert or update on public.home_board_comments for each row execute function public.home_board_comment_guard();