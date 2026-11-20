# Ridge Line play session — 2026-11-18

Device: iPhone 17 simulator, iOS 27.0 (`C3CA7CF6-9F36-42CC-B331-6A1BBCBE4B6B`).
Build: Mech Buddy 0.2.0 (1), `com.jacobrozell.tablemech`, Debug-iphonesimulator from 2026-11-01.

## Issues

1. **Simulator.app is missing from Xcode 27.1.** `Contents/Applications` has Accessibility Inspector, Instruments, and others, but no Simulator.app. `open -a Simulator` fails. The booted simulator still renders, and `simctl io screenshot` works. Computer Use cannot attach to a Simulator window because there is no window.

2. **idb 1.1.8 accessibility is empty on iOS 27.** `idb ui describe-all` returns a single Application node with a 0×0 frame and no children.

3. **idb taps do not land.** Companion 1.1.8 looks for SimulatorKit at `Xcode.app/Contents/Developer/Library/PrivateFrameworks`. It lives at `Contents/SharedFrameworks`. A throwaway `DEVELOPER_DIR` shim outside Xcode lets the companion load SimulatorKit. HID then reports touch-down and touch-up success, but the Play Ridge Line button does not move. Tried point coordinates (201, 490) and pixel coordinates (602, 1473). No symlink was added inside Xcode.

4. **Play home itself looks fine.** Ridge Line card, Side A Shadow Hawk and Commando, Side B Wolverine and Locust, Play / Force / Rules / Settings. “New here?” nudge is showing.

5. **Start battle covers the table checklist until you scroll.** On the first briefing screen the dock sits on top of steps 3–5 (`04-table-briefing.png`). After a scroll, all five steps and How you win are readable, and the button sits below them (`05-briefing-scrolled.png`). The checklist still does not block Start battle.

## Screenshots

- `01-launch.png` — Play home after install and launch
- `02-after-play-tap.png` — unchanged after the point tap
- `03-after-pixel-tap.png` — unchanged after the pixel tap
- `04-table-briefing.png` — briefing, dock covering the checklist
- `05-briefing-scrolled.png` — full checklist and how you win
- `06-initiative.png` — turn 1, waiting on four dice
- `07-table-proposed.jpg` — one terrain sheet, 'Mechs already down
- `08-after-initiative.png` — Side B places first. Phase chips clip to "Shoot t" and "Clea n up".

## This game

Player is Side B (Wolverine WVR-6M, Locust LCT-1V). App side is Side A (Shadow Hawk SHD-2H, Commando COM-2D). No swap.

Physical cards match the bundled numbers for PV, move, damage, armor, and structure. Skill lines on the cards are blank. Ridge Line uses skill 4.

Card differences to watch:

- Shadow Hawk is printed TMM 2/2. The shot solver treats a jump as target TMM + 1, so a jumping Shadow Hawk becomes 3 in the app. The card stays 2.
- Wolverine is printed TMM 2/3. TMM + 1 matches that 3.
- Wolverine OV is 1. This mission leaves overheat off, so the heat scale stays unused.
- Shadow Hawk special line on the card is IF0* (1–3 = 0 damage, 4–6 = 1). The bundle also stores JMPW1, which is not on that special line. Jump is printed in the move (10"/6"j).

Map photo shows the corner of Grassland #2 only. `07-table-proposed.jpg` is one terrain sheet (road, water, hills). Shadow Hawk and Commando sit up-map by the road and the light woods. The orange Wolverine is low-left by the water, and a base is cut off at the low-right corner. Only woods will count.

Initiative: Side B 4+5 = 9, Side A 6+6 = 12. Side A wins and moves last. Side B places and moves first. Phase chips clip: "Shoot" reads "Shoot t", "Clean up" reads "Clea n up".

`10-desert-sides.jpg` is Desert on both sheets, joined the right way. A blue pond and rocky ridges are printed. Woods are the green tree patches. 'Mechs are off the far edge on the felt, not in the 6" strip.
