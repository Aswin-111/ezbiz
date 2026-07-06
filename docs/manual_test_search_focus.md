# Manual test — search field focus preservation

Automated coverage doesn't reach the "did the keyboard/cursor drop mid-fetch"
question (see [test/widget_test.dart](../test/widget_test.dart) for why),
so this needs a physical device or emulator smoke pass whenever the
loading/search interaction on any of these screens changes.

## Prerequisites
1. Emulator or device attached (`flutter devices` shows at least one).
2. Backend reachable (or use a throttled network proxy — Charles/mitmproxy — to
   deliberately slow `/shopdetails`, `/allcust`, `/order-reports` so the loading
   window is visible for several seconds; without throttling the fetch is often
   too fast to observe any regression).
3. A test account with real data in at least one comp_code (empty lists don't
   exercise the loading state properly).

## Common expected behavior for every screen below
- The cursor **must stay inside the search field** for every keystroke.
- The **keyboard must not dismiss** at any point during typing or during the
  background fetch that follows.
- When the debounced fetch fires and results reload, **the caret position and
  focus must not jump**.
- The **clear (X) button** must clear the field, refetch page 1, and re-focus
  (or leave focus where it is) — not close the keyboard.

If any of those fails on any screen: **regression, do not ship**.

---

## Screens

### 1. Home / Customer Directory (`home.dart` → `UserHeader`)
This was the specific screen with the bug. The fix here converted `UserHeader`
from `StatelessWidget` to `StatefulWidget` with a persistent
`TextEditingController` (previously it re-created the controller on every
parent rebuild).

Steps:
1. Launch the app, log in as a comp_code user with 20+ customers.
2. Land on the customer directory (home page).
3. Tap the search field. Keyboard opens, caret is at position 0.
4. Type `a`. Wait for debounce (~400ms) → fetch fires → list updates.
5. **Without** dismissing the keyboard, immediately type `b`, `c`, `d`
   rapidly (within the debounce window).
6. Confirm:
   - Field shows `abcd` in order.
   - Cursor stays after the `d`.
   - Keyboard stays open.
   - `X` clear button appears once field is non-empty.
7. Tap `X`. Confirm the field clears, list refetches page 1 (unfiltered),
   keyboard state is preserved.

### 2. Customer Detail (`userdetail.dart` → `ItemSearchBar`)
`ItemSearchBar` already takes a persistent controller from the parent — no
inline controller creation. Verify no regression from the responsive-limit
mixin (initial fetch behavior, rotation behavior).

Steps:
1. From home, tap a customer → land on `UserDetailsPage`.
2. Tap "Add Items" (or whichever action reveals the shop-details list).
3. Tap the search field. Type `mil` (or any prefix that matches items).
4. Confirm cursor/focus behavior as in Common Expected Behavior above.
5. **Rotate the device** portrait → landscape while items are visible.
6. Confirm:
   - List refetches page 1 with a larger `limit` (visibly more cards fill
     the wider screen).
   - Search field, if it had focus, still has focus after rotation.
   - Cursor position preserved.
7. Rotate back to portrait. Same checks in reverse.

### 3. Edit Order (`edit_order_page.dart` → `ItemSearchBar`)
Same widget as #2, different parent. Verify separately because the parent's
`_addedItems` cart state could cause extra rebuilds.

Steps:
1. Go to Order History → open a saved order → tap "Edit".
2. Toggle into "Add items" view.
3. Type in the search field.
4. Confirm focus behavior as in Common Expected Behavior.
5. Add an item to the cart. Return to the search view.
6. Confirm the search field still holds its previous value and the cursor
   behavior is still correct on the next keystroke.

### 4. Stock (`stock.dart` — plain `TextField` with `_searchBar()`)
Simplest form: `TextField` directly consumes the state class's
`_searchController` field. Should be structurally immune to the bug, but
confirm anyway.

Steps:
1. Drawer → "Stock".
2. Type in the search bar (`_searchBar()` on this screen).
3. Confirm focus behavior as in Common Expected Behavior.
4. Type a query that matches nothing (`zzz...`). Confirm the "No items found"
   empty state appears **without** the search bar losing focus.
5. Delete the query. Confirm items reappear and cursor is still in the field.

### 5. Order History (`order_history.dart`)
Order History does **not** have a text-search bar — it filters by
date range and status pills. Focus regression is not applicable here.

**Instead, verify rotation behavior only:**
1. Drawer → "Order History".
2. Note the number of order cards visible.
3. Rotate portrait → landscape.
4. Confirm the list refetches page 1 with a larger `limit` (matches the
   `min:5 max:20` bound override — smaller minimum than the other screens,
   larger cards).
5. Rotate back. Confirm it refetches page 1 with the smaller `limit` again.

---

## Rotation smoke checklist (applies to screens 1, 2, 3, 5)

On a **tablet or an emulator with a resizable window**, for each screen:

1. Note the visible card count in portrait.
2. Rotate to landscape (or resize the window taller in a resizable emulator).
3. **Within ~350 ms** (the debounce), the list should refetch page 1 and
   visibly show **more cards** filling the new available height.
4. Rotate back. List should refetch again and shrink to the portrait count.

If the list count doesn't change on rotation, the `ResponsivePageSizeMixin`
in [lib/helper/responsive_page_size_mixin.dart](../lib/helper/responsive_page_size_mixin.dart)
is not firing on that screen — check its `initState` post-frame callback
attaches the observer (`attachResponsivePageSize()`) after
`computeInitialLimit()`.

---

## Reporting a failure

If any of the above fails, capture:
- Screen name and step number.
- Device model, OS version, screen size.
- Whether network throttling was active (and target latency).
- A short screen-recording (< 15 s) or a series of screenshots showing the
  moment focus/cursor is lost.
- The value of `computeInitialLimit()` at open (add a `debugPrint` if it
  helps) so we can tell whether the observer was attached properly.
