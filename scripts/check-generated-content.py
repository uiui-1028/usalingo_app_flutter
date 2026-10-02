#!/usr/bin/env python3
"""AIが作った教材データ（V5のシート形式）を、受け取り用シートへ送る前に確かめる。

使い方は docs/operations/check-generated-content.md にある。

- 形の確かめ方は scripts/sync-sheet-to-supabase.py の build_document をそのまま使い、
  生成データ向けの確かめを足す。本番へ書くスクリプトには手を入れない。
- 入力は1つのフォルダに置いた `<シート名>.tsv` または `<シート名>.csv`。
- 確かめる範囲は、そのフォルダ（100語などの1回分）の中だけ。
  ponytail: 受け取り用シートにすでにある行とのID重複は見ない。USL-329 で鍵ができたら突き合わせを足す。
"""

from __future__ import annotations

import argparse
import csv
import importlib.util
import io
import json
import random
import re
import sys
from collections import defaultdict
from pathlib import Path

SYNC_SCRIPT = Path(__file__).resolve().parent / "sync-sheet-to-supabase.py"
_spec = importlib.util.spec_from_file_location("sync_sheet_to_supabase", SYNC_SCRIPT)
assert _spec and _spec.loader
sync = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sync)

REQUIRED_SHEETS = (
    "01_core_words", "01_core_senses", "02_content_concepts",
    "02_content_examples", "04_decks", "04_deck_words",
)
PARTS_OF_SPEECH = {
    "noun", "verb", "adjective", "adverb", "preposition", "conjunction",
    "pronoun", "determiner", "interjection", "auxiliary",
}
LIST_COLUMNS = ("synonyms", "antonyms", "derivatives", "collocations", "related")
JAPANESE = re.compile(r"[぀-ヿ㐀-鿿]")


def to_csv(name: str, text: str, is_tsv: bool, errors: list[str]) -> str:
    """TSVはCSVに直す。どちらもセルの中のタブと改行を止める。"""
    rows = list(csv.reader(io.StringIO(text), delimiter="\t", quoting=csv.QUOTE_NONE) if is_tsv
                else csv.reader(io.StringIO(text)))
    if not rows:
        return text
    width = len(rows[0])
    for line, row in enumerate(rows[1:], start=2):
        if not any(cell.strip() for cell in row):
            continue
        if is_tsv and len(row) != width:
            errors.append(f"{name} line {line}: has {len(row)} cells but the header has {width} (a tab inside a cell?)")
        if any("\t" in cell or "\n" in cell or "\r" in cell for cell in row):
            errors.append(f"{name} line {line}: a cell contains a tab or a line break")
    if not is_tsv:
        return text
    out = io.StringIO()
    csv.writer(out, lineterminator="\n").writerows(rows)
    return out.getvalue()


def read_dir(directory: Path, errors: list[str]) -> dict[str, str]:
    csvs = {}
    for name, columns in sync.SHEET_COLUMNS.items():
        tsv, plain = directory / f"{name}.tsv", directory / f"{name}.csv"
        if tsv.exists() and plain.exists():
            errors.append(f"{name}: both .tsv and .csv exist; keep one")
        elif tsv.exists() or plain.exists():
            path = tsv if tsv.exists() else plain
            csvs[name] = to_csv(name, path.read_text(encoding="utf-8-sig"), path.suffix == ".tsv", errors)
        elif name in REQUIRED_SHEETS:
            errors.append(f"{name}: {name}.tsv or {name}.csv is missing")
        else:
            # 音声のシートは生成しないので、見出しだけの空のシートとして扱う
            csvs[name] = ",".join(columns) + "\n"
    return csvs


def word_forms(word: str, inflections: str) -> set[str]:
    w = word.lower()
    forms = {w, w + "s", w + "es", w + "d", w + "ed", w + "ing", w + "er", w + "est"}
    if len(w) > 2:
        forms |= {w[:-1] + "ing", w[:-1] + "ied", w[:-1] + "ies", w[:-1] + "ier", w[:-1] + "iest",
                  w + w[-1] + "ed", w + w[-1] + "ing", w + w[-1] + "er", w + w[-1] + "est"}
    try:
        values = json.loads(inflections) if inflections else {}
    except json.JSONDecodeError:
        values = {}
    if isinstance(values, dict):
        forms |= {str(v).lower() for v in values.values() if v}
    return forms


def contains_word(sentence: str, forms: set[str]) -> bool:
    text = sentence.lower()
    return any(re.search(rf"(?<![a-z]){re.escape(form)}(?![a-z])", text) for form in forms)


def extra_checks(csvs: dict[str, str]) -> tuple[list[str], list[str]]:
    """生成データ向けに足した確かめ。止める誤りと、注意だけの一覧を返す。"""
    errors: list[str] = []
    warnings: list[str] = []
    # 列の不足は build_document が報告するので、ここでは重ねて出さない
    rows = {name: sync.read_rows(name, csvs.get(name), []) for name in sync.SHEET_COLUMNS}

    words = {row["word_id"].lstrip("0"): row["word_text"] for _, row in rows["01_core_words"]}
    senses = {}
    priorities: dict[str, list[int]] = defaultdict(list)
    for line, row in rows["01_core_senses"]:
        where = f"01_core_senses line {line}"
        pos = row["part_of_speech_en"]
        if pos and pos not in PARTS_OF_SPEECH:
            errors.append(f"{where} part_of_speech_en: {pos!r} must be one of {', '.join(sorted(PARTS_OF_SPEECH))}")
        for column in LIST_COLUMNS:
            for item in (i.strip() for i in row[column].split("/&/")) if row[column] else ():
                parts = [p.strip() for p in item.split("::")]
                if len(parts) > 3:
                    errors.append(f"{where} {column}: {item!r} has more than 3 parts (word :: 訳 :: 補足)")
                elif item and not parts[0]:
                    errors.append(f"{where} {column}: {item!r} has no word before ::")
        if row["definition_jp"] and not JAPANESE.search(row["definition_jp"]):
            warnings.append(f"{where} definition_jp: {row['definition_jp']!r} has no Japanese characters")
        if row["priority"].isdigit():
            priorities[row["word_id"].lstrip("0")].append(int(row["priority"]))
        senses[row["sense_id"].lstrip("0")] = row

    for word_id, found in priorities.items():
        if sorted(found) != list(range(1, len(found) + 1)):
            errors.append(f"01_core_senses word {word_id}: priorities {sorted(found)} must be 1 to {len(found)} without gaps or repeats")

    examples: dict[tuple[str, str], int] = defaultdict(int)
    for line, row in rows["02_content_examples"]:
        where = f"02_content_examples line {line}"
        sense_id, concept_id = row["sense_id"].lstrip("0"), row["concept_id"].lstrip("0")
        examples[(sense_id, concept_id)] += 1
        if row["sentence_jp"] and not JAPANESE.search(row["sentence_jp"]):
            warnings.append(f"{where} sentence_jp: {row['sentence_jp']!r} has no Japanese characters")
        sense = senses.get(sense_id)
        word = words.get(sense["word_id"].lstrip("0")) if sense else None
        if word and row["sentence_en"] and not contains_word(row["sentence_en"], word_forms(word, sense["inflections"])):
            warnings.append(f"{where} sentence_en: {row['sentence_en']!r} does not contain {word!r}")

    deck_concepts = {row["deck_id"].lstrip("0"): row["concept_id"].lstrip("0") for _, row in rows["04_decks"]}
    for line, row in rows["04_deck_words"]:
        sense_id, deck_id = row["sense_id"].lstrip("0"), row["deck_id"].lstrip("0")
        concept_id = deck_concepts.get(deck_id)
        if sense_id in senses and concept_id and not examples[(sense_id, concept_id)]:
            errors.append(f"04_deck_words line {line}: sense {sense_id} has no example for the deck's concept {concept_id}")
    return errors, warnings


def check(directory: Path) -> tuple[list[str], list[str], dict[str, str]]:
    errors: list[str] = []
    csvs = read_dir(directory, errors)
    if any(name not in csvs for name in REQUIRED_SHEETS):
        return errors, [], csvs
    try:
        sync.build_document(csvs)
    except sync.SyncError as error:
        errors.extend(error.errors)
    extra_errors, warnings = extra_checks(csvs)
    errors.extend(extra_errors)
    return errors, warnings, csvs


SAMPLE_COLUMNS = (
    "deck_id", "word_id", "word_text", "sense_id", "part_of_speech_en", "definition_jp",
    "cefr_level", "etymology", "sentence_en", "sentence_jp", "ok", "note",
)


def sample(csvs: dict[str, str], rate: float, seed: int) -> list[dict[str, str]]:
    """デッキ（シリーズの段階）ごとに rate の割合を選ぶ。どのデッキからも最低1語。"""
    rows = {name: [row for _, row in sync.read_rows(name, csvs.get(name), [])] for name in sync.SHEET_COLUMNS}
    words = {r["word_id"].lstrip("0"): r["word_text"] for r in rows["01_core_words"]}
    senses = {r["sense_id"].lstrip("0"): r for r in rows["01_core_senses"]}
    first_example: dict[tuple[str, str], dict[str, str]] = {}
    for r in rows["02_content_examples"]:
        first_example.setdefault((r["sense_id"].lstrip("0"), r["concept_id"].lstrip("0")), r)
    deck_concepts = {r["deck_id"].lstrip("0"): r["concept_id"].lstrip("0") for r in rows["04_decks"]}

    by_deck: dict[str, list[str]] = defaultdict(list)
    for r in rows["04_deck_words"]:
        by_deck[r["deck_id"].lstrip("0")].append(r["sense_id"].lstrip("0"))

    picker = random.Random(seed)
    picked, seen_words = [], set()
    for deck_id in sorted(by_deck, key=int):
        pool = by_deck[deck_id]
        for sense_id in picker.sample(pool, max(1, round(len(pool) * rate))):
            sense = senses[sense_id]
            word_id = sense["word_id"].lstrip("0")
            if word_id in seen_words:
                continue
            seen_words.add(word_id)
            example = first_example.get((sense_id, deck_concepts.get(deck_id, "")), {})
            picked.append({
                "deck_id": deck_id, "word_id": word_id, "word_text": words.get(word_id, ""),
                "sense_id": sense_id, "part_of_speech_en": sense["part_of_speech_en"],
                "definition_jp": sense["definition_jp"], "cefr_level": sense["cefr_level"],
                "etymology": sense["etymology"], "sentence_en": example.get("sentence_en", ""),
                "sentence_jp": example.get("sentence_jp", ""), "ok": "", "note": "",
            })
    return picked


def report(errors: list[str], warnings: list[str]) -> None:
    for title, messages in (("warning", warnings), ("stopped", errors)):
        if messages:
            print(f"{title}: {len(messages)}", file=sys.stderr)
            for message in messages[:50]:
                print(f"  - {message}", file=sys.stderr)
            if len(messages) > 50:
                print(f"  ... and {len(messages) - 50} more", file=sys.stderr)


def command_check(args: argparse.Namespace) -> int:
    errors, warnings, _ = check(Path(args.dir))
    report(errors, warnings)
    if errors:
        return 1
    print("generated content ok", file=sys.stderr)
    return 0


def command_sample(args: argparse.Namespace) -> int:
    errors, warnings, csvs = check(Path(args.dir))
    report(errors, warnings)
    if errors:
        return 1
    picked = sample(csvs, args.rate, args.seed)
    with open(args.output, "w", encoding="utf-8", newline="") as out:
        writer = csv.DictWriter(out, SAMPLE_COLUMNS, delimiter="\t", lineterminator="\n", quoting=csv.QUOTE_NONE, escapechar="\\")
        writer.writeheader()
        writer.writerows(picked)
    print(f"wrote {len(picked)} words to {args.output} (seed {args.seed})", file=sys.stderr)
    return 0


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = root.add_subparsers(dest="command", required=True)

    check_command = commands.add_parser("check", help="check one batch folder")
    check_command.add_argument("--dir", required=True, help="folder with <sheet name>.tsv or .csv files")
    check_command.set_defaults(handler=command_check)

    sample_command = commands.add_parser("sample", help="check, then write the words a person should review")
    sample_command.add_argument("--dir", required=True, help="folder with <sheet name>.tsv or .csv files")
    sample_command.add_argument("--output", required=True, help="TSV file to write")
    sample_command.add_argument("--rate", type=float, default=0.1)
    sample_command.add_argument("--seed", type=int, default=1)
    sample_command.set_defaults(handler=command_sample)
    return root


def main() -> int:
    args = parser().parse_args()
    return args.handler(args)


if __name__ == "__main__":
    raise SystemExit(main())
