#!/usr/bin/env python3
"""Writes dibs-eval ground truth next to each WildReceipt image.

WildReceipt labels every text box (item, price, quantity, subtotal, tax,
total). This pairs items with the price on their row and keeps only receipts
whose labels add up, so a mislabeled receipt never becomes ground truth.

    scripts/wildreceipt-to-truth.py Corpus/wildreceipt/wildreceipt
"""
import json
import re
import sys
from pathlib import Path

ITEM, QUANTITY, PRICE, SUBTOTAL, TAX, TOTAL = 11, 13, 15, 17, 19, 23


def amount(text):
    match = re.fullmatch(r"\$?(\d[\d,]*)\.(\d{2})", text.strip())
    return int(match.group(1).replace(",", "")) * 100 + int(match.group(2)) if match else None


def geometry(box):
    xs, ys = box[0::2], box[1::2]
    return min(xs), (min(ys) + max(ys)) / 2, max(ys) - min(ys)


def convert(record):
    boxes = [(a["label"], a["text"], *geometry(a["box"])) for a in record["annotations"]]

    def amounts(label):
        return [amount(text) for kind, text, *_ in boxes if kind == label]

    items = []
    for kind, text, _, y, height in boxes:
        if kind != PRICE:
            continue
        price = amount(text)
        if price is None:
            return None
        row = sorted((x, k, t) for k, t, x, other, _ in boxes if abs(other - y) < 0.5 * height)
        name = " ".join(t for _, k, t in row if k == ITEM)
        quantities = [t for _, k, t in row if k == QUANTITY and t.isdigit()]
        if not name:
            return None
        if price == 0:
            continue  # nothing to claim, and the app drops these
        item = {"name": name, "total": price / 100}
        if len(quantities) == 1:
            item["quantity"] = int(quantities[0])
        items.append(item)

    subtotals, taxes, totals = amounts(SUBTOTAL), amounts(TAX), amounts(TOTAL)
    if not items or None in subtotals + taxes + totals or len(subtotals) > 1 or len(set(totals)) != 1:
        return None

    items_sum = sum(round(item["total"] * 100) for item in items)
    tax, total = sum(taxes), totals[0]
    if subtotals and subtotals[0] != items_sum:
        return None
    if items_sum + tax != total:
        return None

    truth = {"items": items, "tax": tax / 100, "total": total / 100}
    if subtotals:
        truth["subtotal"] = subtotals[0] / 100
    return truth


def main(root):
    root = Path(root)
    kept = seen = 0
    for split in ("train.txt", "test.txt"):
        for line in (root / split).read_text().splitlines():
            record = json.loads(line)
            seen += 1
            truth = convert(record)
            if truth is None:
                continue
            kept += 1
            path = (root / record["file_name"]).with_suffix(".json")
            path.write_text(json.dumps(truth, indent=1) + "\n")
    print(f"{kept} of {seen} receipts have labels that add up")


if __name__ == "__main__":
    main(sys.argv[1])
