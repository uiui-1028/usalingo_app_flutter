-- デッキ追加画面に出す容量と易・中・難の列を固定する。値は教材の同期が入れる。

begin;

create extension if not exists pgtap with schema extensions;

select plan(6);

select col_type_is('public', 'decks', 'media_bytes', 'bigint', 'media_bytes is bigint');
select col_type_is('public', 'decks', 'difficulty', 'text', 'difficulty is text');
select ok(
  has_column_privilege('authenticated', 'public.decks', 'media_bytes', 'select')
    and has_column_privilege('authenticated', 'public.decks', 'difficulty', 'select'),
  'the app can read media_bytes and difficulty'
);

insert into public.decks (deck_name) values ('deck-gallery-facts');

select lives_ok(
  $$update public.decks set media_bytes = 11480246, difficulty = 'medium' where deck_name = 'deck-gallery-facts'$$,
  'a deck takes a size and one of easy / medium / hard'
);

select throws_ok(
  $$update public.decks set difficulty = 'normal' where deck_name = 'deck-gallery-facts'$$,
  '23514',
  null,
  'difficulty rejects other words'
);

select throws_ok(
  $$update public.decks set media_bytes = -1 where deck_name = 'deck-gallery-facts'$$,
  '23514',
  null,
  'media_bytes rejects a negative size'
);

select * from finish();

rollback;
