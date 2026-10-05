-- デッキ追加画面に出す「容量」と「易・中・難」を、デッキごとに前もって持たせる。
--
-- 値は教材の同期（scripts/sync-sheet-to-supabase.py）が計算して入れ、アプリは読むだけ。
-- 同期を流すまでは NULL のまま。決め方は docs/plans/deck-gallery-redesign-requirements.md（D6・D8）。
--
-- decks の select 権限はテーブル単位なので、権限は足さない。

begin;

alter table public.decks
  add column media_bytes bigint check (media_bytes >= 0),
  add column difficulty text check (difficulty in ('easy', 'medium', 'hard'));

comment on column public.decks.media_bytes is
  'Bytes of the images and audio a device downloads for this deck. Set by the sheet sync; NULL until it runs.';

comment on column public.decks.difficulty is
  'easy / medium / hard from the share of B2+ primary meanings (under 20% / under 50% / 50% or more). Set by the sheet sync.';

commit;
