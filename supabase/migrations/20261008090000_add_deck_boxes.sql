-- 公式デッキを「箱」でまとめる。箱は単語リストの一部 × 世界観1つで、ギャラリーで選ぶ単位になる。
--
-- 箱の中身は今までの公式デッキ（100語ずつ）で、デッキは自分の箱を box_id で指す。
-- 世界観とジャンルは箱が持ち、教材の同期が箱の世界観を decks.concept_id へ写す。
-- 容量と易・中・難は、デッキと同じく同期が計算して入れ、アプリは読むだけ。
-- 要件は docs/plans/deck-box-requirements.md。
--
-- 公開範囲は decks と同じ。ログインした利用者が読むだけで、書くのは同期（service_role）だけ。

begin;

create table public.deck_boxes (
  id integer primary key check (id > 0),
  box_name text not null check (btrim(box_name) <> ''),
  description text,
  genre text not null check (genre in ('exam', 'toeic')),
  concept_id integer not null references public.content_concepts(id) on delete restrict,
  cover_example_id integer references public.example_contents(id) on delete set null,
  sort_order integer not null default 0,
  media_bytes bigint check (media_bytes >= 0),
  difficulty text check (difficulty in ('easy', 'medium', 'hard'))
);

comment on table public.deck_boxes is
  'Official deck boxes shown in the deck gallery: part of a word list with one concept. Synced from the sheet.';
comment on column public.deck_boxes.genre is 'Gallery genre: exam or toeic.';
comment on column public.deck_boxes.cover_example_id is
  'Example whose image is the box cover. NULL lets the app pick one from the words.';
comment on column public.deck_boxes.sort_order is 'Gallery order. The row order of the sheet.';
comment on column public.deck_boxes.media_bytes is
  'Bytes of the images and audio of every deck in the box. Set by the sheet sync.';
comment on column public.deck_boxes.difficulty is
  'easy / medium / hard over all primary meanings in the box, by the same rule as decks.difficulty.';

create index deck_boxes_concept_id_idx on public.deck_boxes (concept_id);
create index deck_boxes_cover_example_id_idx on public.deck_boxes (cover_example_id);

alter table public.decks
  add column box_id integer references public.deck_boxes(id) on delete set null;

comment on column public.decks.box_id is 'The box this official deck belongs to. NULL shows the deck on its own.';

create index decks_box_id_idx on public.decks (box_id);

alter table public.deck_boxes enable row level security;

create policy deck_boxes_select_authenticated
  on public.deck_boxes for select to authenticated using (true);

revoke all on table public.deck_boxes from public, anon, authenticated;
grant select on table public.deck_boxes to authenticated;
grant select, insert, update, delete on table public.deck_boxes to service_role;

-- 検証。揃っていなければ適用せずに止める。
do $$
begin
  if has_table_privilege('anon', 'public.deck_boxes', 'select') then
    raise exception 'deck boxes stopped: anon can read deck_boxes.';
  end if;
  if not has_table_privilege('authenticated', 'public.deck_boxes', 'select')
    or has_table_privilege('authenticated', 'public.deck_boxes', 'insert') then
    raise exception 'deck boxes stopped: grants for authenticated are incorrect.';
  end if;
end
$$;

commit;
