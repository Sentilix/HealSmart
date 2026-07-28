# HealSmart Changelog

# HealSmart Changelog

## v0.4.0
* **Sleek New Pages:** Added `<` and `>` arrow buttons in the top right. You can now flip through multiple stat screens like a pro without opening any extra windows.
* **Page 0 (Welcome Screen):** A clean home screen that says welcome and shows a quick guide when you don't have any active combat data yet.
* **Page 1 (Healing Done):** Your classic healing meter. Shows exactly how much raw HP you pumped out, formatted with dots for big numbers, plus your percentage share of the raid's total healing (e.g., "12.450 - 24.5%").
* **Page 2 (Heal vs Overheal):** The ultimate accuracy tracker. Shows exactly how much of your healing actually hit the target versus how much was wasted into thin air (e.g., "8.200 / 10.000 - 80%").
* **Page 3 (Mana Efficiency):** The brainiac screen. Shows exactly how much healing you get out of every single mana point spent (HPM). Perfect for seeing who is spamming uselessly and who is playing smart.
* **Smart Auto-Save:** The addon now remembers exactly where you dragged the window, how big you resized it, and what page you were looking at. No more resetting every time you log out or type /reload.
* **Fight Memory:** It now saves the numbers from your very last battle, so your bars and stats don't disappear when you disconnect or load into a new zone.
* **Text Layer Fix:** Fixed an annoying bug where the colored class bars would slide over and block the healer names when the bars got more than 75% full. Text now floats perfectly on top at all times.
* **Pure Healing Mana:** Refactored the mana tracker to ONLY count real healing spells and shields. Spamming Lightning Bolts, offensive dots, or drinking mana potions will no longer mess up your HPM score.
* **Instant Solo Testing:** The addon automatically drops the group mana limit to zero when you are solo, meaning you can test your spells and see your HPM instantly on low level characters or when fighting a random mob.
* **No More Load Glitches:** Added a clean 1-second startup delay that lets your game load in fully before refreshing the bars, removing all weird visual bugs when logging in.

## v0.3.0
* **Raid Support:** The addon now automatically shows bars for all active healers in your group or raid, using their real class colors (white for Priests, navy blue for Shamans, etc.).
* **Live Sorting:** Ranks all healers on the fly during combat. The healer with the best efficiency is always pinned right at the top of the list.
* **Smooth Scrolling & Resizing:** Added a clean scroll frame so you can scroll through large raids, plus a drag-handle in the bottom right corner to resize the window exactly how you want it.
* **Class Filter Button:** Added a rapid `[ALL]` / `[MINE]` button in the header. One click lets you toggle between seeing every healer in the raid or just the ones playing your own class.
* **Zero Black Bars Bug:** Built a fast group-roster cache system that remembers everyone's class the second they join. This completely fixes the annoying bug where healer bars would randomly turn black or gray during chaotic pulls.
* **Rock-Solid Shields:** Rewrote the combat log parser to perfectly track *Power Word: Shield* absorbs, even if a monster hits you with magic spells or you are standing far away from the casting Priest.

## v0.2.0
* **Smart combat tracking:** The addon now automatically activates when you enter combat and freezes your numbers when the fight ends.
* **Boss-friendly timer:** If you leave and re-enter combat within 5 seconds (e.g., during boss phase transitions), the measurement continues seamlessly in the same session.
* **Shield support:** Precise tracking for *Power Word: Shield*. Damage absorbed by your shields is now correctly counted as effective healing.
* **New sleek design:** The window height has been reduced to 16 pixels to take up minimal space on your screen.
* **Simplified text:** Now displays only your raw efficiency percentage (e.g., "85%"), or "--%" if you haven't healed in combat yet.

## v0.1.0
* **Initial release:** Simple status bar showing your effective healing versus your overhealing.
* **Movable window:** Hold `Shift` and drag the bar with your left mouse button to position it anywhere on your screen.

