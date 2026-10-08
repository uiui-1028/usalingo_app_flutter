-- 公式デッキを箱でまとめる表。読めるのはログインした利用者だけで、箱を消してもデッキは残る。

begin;

create extension if not exists pgtap with schema extensions;

select plan(7);

select fk_ok('public', 'decks', 'box_id', 'public', 'deck_boxes', 'id', 'decks.box_id references deck_boxes');
select fk_ok('public', 'deck_boxes', 'concept_id', 'public', 'content_concepts', 'id',
  'deck_boxes.concept_id references content_concepts');
select ok(
  has_table_privilege('authenticated', 'public.deck_boxes', 'select')
    and not has_table_privilege('authenticated', 'public.deck_boxes', 'insert')
    and not has_table_privilege('anon', 'public.deck_boxes', 'select'),
  'signed-in users only read deck_boxes'
);

insert into public.deck_boxes (id, box_name, genre, concept_id)
values (900001, 'deck-boxes-test', 'exam', public.default_content_concept_id());
insert into public.decks (deck_name, box_id) values ('deck-boxes-test-deck', 900001);

select throws_ok(
  $$insert into public.deck_boxes (id, box_name, genre, concept_id)
    values (900002, 'other', 'eiken', public.default_content_concept_id())$$,
  '23514',
  null,
  'genre rejects other words'
);

select throws_ok(
  $$update public.deck_boxes set media_bytes = -1 where id = 900001$$,
  '23514',
  null,
  'media_bytes rejects a negative size'
);

delete from public.deck_boxes where id = 900001;

select is(
  (select box_id from public.decks where deck_name = 'deck-boxes-test-deck'),
  null,
  'deleting a box keeps its decks'
);

select ok(
  (select relrowsecurity from pg_class where oid = 'public.deck_boxes'::regclass),
  'deck_boxes has row level security'
);

select * from finish();

rollback;
