from __future__ import annotations

import csv
import importlib.util
import subprocess
import sys
import tempfile
from pathlib import Path
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "check-generated-content.py"
SPEC = importlib.util.spec_from_file_location("check_generated_content", SCRIPT)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

SENSE_HEADER = (
    "sense_id\tword_id\tpriority\tpart_of_speech_jp\tpart_of_speech_en\tdefinition_jp\tcefr_level\t"
    "pronunciation_ipa\tpronunciation_kana\tetymology\tsynonyms\tantonyms\tinflections\tderivatives\t"
    "collocations\trelated\n"
)


def sheets(**overrides: str) -> dict[str, str]:
    files = {
        "01_core_words.tsv": "word_id\tword_text\n1\tcreate\n2\tincrease\n",
        "01_core_senses.tsv": SENSE_HEADER + (
            '1\t1\t1\t動詞\tverb\t作り出す\tA2\t\t\t\tmake :: 作る /&/ produce :: 生産する\t\t{"past": "created"}\t\t\t\n'
            "2\t2\t1\t動詞\tverb\t増加する\tB1\t\t\t\t\t\t\t\t\t\n"
            "3\t2\t2\t名詞\tnoun\t増加\tB1\t\t\t\t\t\t\t\t\t\n"
        ),
        "02_content_concepts.tsv": "concept_id\tconcept_code\tconcept_name\tdescription\tis_active\n1\tsimple\tシンプル\t\tTRUE\n",
        "02_content_examples.tsv": (
            "example_id\tsense_id\tconcept_id\tsentence_en\tsentence_jp\timage_asset_path\n"
            "1\t1\t1\tShe created a new app.\t彼女は新しいアプリを作った。\t\n"
            "2\t2\t1\tSales are increasing.\t売上が増えている。\t\n"
        ),
        "04_deck_boxes.tsv": "box_id\tbox_name\tdescription\tgenre\tconcept_id\tcover_example_id\n1\t大学受験\t\texam\t1\t\n",
        "04_decks.tsv": "deck_id\tdeck_name\tbox_id\n1\t高校\t1\n",
        "04_deck_words.tsv": "deck_id\tsense_id\n1\t1\n1\t2\n",
    }
    files.update(overrides)
    return files


class CheckGeneratedContentTest(unittest.TestCase):
    def run_check(self, **overrides: str) -> tuple[list[str], list[str]]:
        with tempfile.TemporaryDirectory() as directory:
            for name, text in sheets(**overrides).items():
                if text is not None:
                    (Path(directory) / name).write_text(text, encoding="utf-8")
            errors, warnings, _ = MODULE.check(Path(directory))
        return errors, warnings

    def assert_stops(self, message: str, **overrides: str) -> None:
        errors, _ = self.run_check(**overrides)
        self.assertTrue(any(message in error for error in errors), errors)

    def test_accepts_a_good_tsv_batch_without_audio_sheets(self) -> None:
        self.assertEqual(self.run_check(), ([], []))

    def test_accepts_csv_files(self) -> None:
        overrides = {name: None for name in sheets()}
        for name, text in sheets().items():
            rows = [line.split("\t") for line in text.splitlines()]
            with tempfile.TemporaryFile("w+", newline="") as buffer:
                csv.writer(buffer, lineterminator="\n").writerows(rows)
                buffer.seek(0)
                overrides[name.replace(".tsv", ".csv")] = buffer.read()
        self.assertEqual(self.run_check(**overrides), ([], []))

    def test_reports_existing_sync_checks_with_line_numbers(self) -> None:
        self.assert_stops(
            "04_deck_words line 3 sense_id: deck 1 already has word 2",
            **{"04_deck_words.tsv": "deck_id\tsense_id\n1\t2\n1\t3\n"},
        )

    def test_stops_on_a_missing_required_sheet(self) -> None:
        self.assert_stops("04_decks.tsv or 04_decks.csv is missing", **{"04_decks.tsv": None})

    def test_stops_on_a_tab_inside_a_cell(self) -> None:
        self.assert_stops(
            "01_core_words line 3: has 3 cells",
            **{"01_core_words.tsv": "word_id\tword_text\n1\tcreate\n2\tin\tcrease\n"},
        )

    def test_stops_on_unknown_part_of_speech(self) -> None:
        senses = sheets()["01_core_senses.tsv"].replace("\tnoun\t", "\tNoun\t")
        self.assert_stops("01_core_senses line 4 part_of_speech_en: 'Noun'", **{"01_core_senses.tsv": senses})

    def test_stops_on_a_list_item_with_too_many_parts(self) -> None:
        senses = sheets()["01_core_senses.tsv"].replace("make :: 作る", "make :: 作る :: 一般 :: 余分")
        self.assert_stops("has more than 3 parts", **{"01_core_senses.tsv": senses})

    def test_stops_on_priority_gaps(self) -> None:
        senses = sheets()["01_core_senses.tsv"].replace("3\t2\t2\t", "3\t2\t3\t")
        self.assert_stops("priorities [1, 3] must be 1 to 2", **{"01_core_senses.tsv": senses})

    def test_stops_when_the_deck_sense_has_no_example_for_its_concept(self) -> None:
        self.assert_stops(
            "04_deck_words line 3: sense 3 has no example for the deck's concept 1",
            **{"04_deck_words.tsv": "deck_id\tsense_id\n1\t1\n1\t3\n"},
        )

    def test_warns_when_the_example_misses_the_word_or_japanese(self) -> None:
        examples = sheets()["02_content_examples.tsv"].replace("Sales are increasing.", "Prices go up.").replace(
            "売上が増えている。", "Sales up."
        )
        errors, warnings = self.run_check(**{"02_content_examples.tsv": examples})
        self.assertEqual(errors, [])
        self.assertTrue(any("does not contain 'increase'" in w for w in warnings), warnings)
        self.assertTrue(any("has no Japanese characters" in w for w in warnings), warnings)

    def test_finds_inflected_forms(self) -> None:
        self.assertTrue(MODULE.contains_word("She created it.", MODULE.word_forms("create", "")))
        self.assertTrue(MODULE.contains_word("He ran home.", MODULE.word_forms("run", '{"past": "ran"}')))
        self.assertTrue(MODULE.contains_word("They are stopping.", MODULE.word_forms("stop", "")))
        self.assertFalse(MODULE.contains_word("A recreation park.", MODULE.word_forms("create", "")))


class SampleTest(unittest.TestCase):
    def test_takes_at_least_one_word_from_each_deck_with_a_fixed_seed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            files = sheets(**{
                "04_decks.tsv": "deck_id\tdeck_name\tbox_id\n1\t中学\t1\n2\t高校\t1\n",
                "04_deck_words.tsv": "deck_id\tsense_id\n1\t1\n2\t2\n",
            })
            for name, text in files.items():
                (Path(directory) / name).write_text(text, encoding="utf-8")
            output = Path(directory) / "sample.tsv"
            command = [sys.executable, str(SCRIPT), "sample", "--dir", directory, "--output", str(output), "--seed", "7"]
            subprocess.run(command, check=True, capture_output=True)
            first = output.read_text(encoding="utf-8")
            subprocess.run(command, check=True, capture_output=True)
            self.assertEqual(output.read_text(encoding="utf-8"), first)

        lines = first.splitlines()
        self.assertEqual(lines[0].split("\t")[:3], ["deck_id", "word_id", "word_text"])
        self.assertEqual([line.split("\t")[0] for line in lines[1:]], ["1", "2"])
        self.assertIn("She created a new app.", lines[1])

    def test_check_command_exits_with_1_on_errors(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "check", "--dir", directory], capture_output=True, text=True
            )
        self.assertEqual(result.returncode, 1)
        self.assertIn("01_core_words.tsv or 01_core_words.csv is missing", result.stderr)


if __name__ == "__main__":
    unittest.main()
