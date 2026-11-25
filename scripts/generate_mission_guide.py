#!/usr/bin/env python3
"""Writes docs/missions/alpha-strike-missions.md from the Alpha Strike mission files.

Run from the repo root after changing any mission JSON:  python3 scripts/generate_mission_guide.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASE = ROOT / "Resources/Content/AlphaStrike"
OUT = ROOT / "docs/missions/alpha-strike-missions.md"


def anchor(text):
    keep = "".join(c for c in text.lower() if c.isalnum() or c in " -")
    return keep.replace(" ", "-")


def main():
    catalog = json.loads((BASE / "as-scenarios.json").read_text())["scenarios"]
    out = [
        "# Alpha Strike missions: a player's guide", "",
        "Every mission in Mech Buddy, in the order the app teaches them: what you need, how to set up the table, "
        "what's new, and how to win. The app walks you through the same steps on screen. Use this page to read "
        "ahead or set up before you open the app.", "",
        "_Generated from `Resources/Content/AlphaStrike/` by `scripts/generate_mission_guide.py`. Edit the mission "
        "files and rerun the script, so the app and this guide always agree._", "",
        "## Before your first game", "",
        "- **You need:** a table about 3 feet across, the ’Mech minis (or coins, or any stand-ins), two six-sided "
        "dice, and a tape measure in inches. Alpha Strike ignores printed hexes.",
        "- **One phone runs the game** for both players. Pass it across the table, or keep it in the middle.",
        "- **Each turn has four steps:** roll for initiative, move, shoot, then clean up. The app says whose step it is.",
        "- **Your minis:** in the Force tab, tell the app which boxes you own. Each mission then says which minis "
        "you have and suggests stand-ins for the rest.",
        "- **Skip ahead any time:** tap any mission on the Play path. Replaying a cleared mission keeps your progress.",
        "- **Rules:** the Rules tab explains every rule used here, with page numbers in the Quick-Start Rulebook.", "",
        "## Missions", "",
    ]
    sections = []
    for item in catalog:
        if item.get("gated") or not item.get("bundle"):
            continue
        d = json.loads((BASE / item["bundle"]).read_text())
        label = item.get("stage") or f"Mission {d.get('missionNumber')}"
        title = f"{label}: {d['title']}"
        out.append(f"- [{title}](#{anchor(title)})")
        r, a, b = d["ruleset"], d["sides"]["lanceA"], d["sides"]["lanceB"]
        learn = d.get("introduces") or item.get("introduces") or []
        s = [f"## {title}", "",
             f"**{len(a)} vs {len(b)} · about {d.get('estimatedMinutes', '?')} minutes · up to {r.get('maxTurns', '—')} turns**", ""]
        if learn:
            s += ["**You'll learn:** " + ", ".join(learn) + ".", ""]
        s += ["**How to win:** " + d.get("winningSummary", ""), "", "**Forces**", "",
              "| Side | ’Mech | Skill | PV | Move | Armor/Structure | Damage S/M/L | Specials |",
              "|---|---|---|---|---|---|---|---|"]
        for side, units in (("A", a), ("B", b)):
            for u in units:
                s.append(f"| {side} | {u['name']} | {u['skill']} | {u['pv']} | {u['mv']} | "
                         f"{u['armor']}/{u['structure']} | {u['s']}/{u['m']}/{u['l']} | {u['abilities'] or '—'} |")
        s += [f"| | **Total PV** | | A {sum(u['pv'] for u in a)} · B {sum(u['pv'] for u in b)} | | | | |", ""]
        on = [n for k, n in (("overheatAllowed", "overheat"), ("physicalAttacksAllowed", "punches and kicks"),
                             ("forcedWithdrawal", "Forced Withdrawal")) if r.get(k)]
        lay = d.get("layout")
        if lay:
            sheets = [x["name"] for x in lay.get("sheets", [])]
            maps = (" and ".join(sheets) + ", side by side (A Game of Armored Combat)") if sheets else "none"
            s += [f"**Maps needed:** {maps}. {lay['openTable']}", "",
                  f"**Table:** {lay['width']:g} × {lay['depth']:g} inches. Side A sets up on the left edge, Side B on the right. "
                  "The app shows a top-down diagram of the layout on the mission sheet and at table setup.", ""]
        s += ["**Extra rules on:** " + (", ".join(on) if on else "none; just move and shoot") + ".", "",
              "**Set up the table**", ""]
        s += [f"{i}. {step}" for i, step in enumerate(d.get("tableSteps", []), 1)] + [""]
        if d.get("coachNotes"):
            s += ["**What's new, and tips**", ""] + [f"- {n}" for n in d["coachNotes"]] + [""]
        sections += s
    out += [""] + sections
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(out).rstrip() + "\n")
    print(f"Wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
