<p align="center">
  <img src="icon/icon.png" width="88" alt="hanneslauncher icon">
</p>

<h1 align="center">hanneslauncher</h1>

<p align="center">A minimalist Android launcher, built with Flutter.</p>

**Quick Links:**
- [Download APK](#installation)
- [Report Issues](https://github.com/Hannes-swd/Hanneslauncher/issues)
  
No app grid, no pages to swipe through. The home screen is a clock, a few
pinned apps and a letter bar along the right edge, everything else sits
behind two gestures: **run your finger down the alphabet** for the app list,
**pull down from the top** for the panel with widgets, app rows and the
calendar.

<p align="center">
  <img src="Images/home.png" width="30%" alt="Home screen with the dot matrix clock">
  <img src="Images/home-sakura.png" width="30%" alt="Home screen with the vertical clock">
  <img src="Images/app-suche.png" width="30%" alt="App list while scrubbing the letter bar">
</p>

<p align="center">
  <img src="Images/walkthrough.gif" width="32%" alt="Walkthrough: the panel, the widget editor and the app list">
  <br>
  <sub>Everything below, shown in one go.
  <a href="Images/showing.mp4">Full quality with sound</a>.</sub>
</p>

---

## Home screen

Wallpaper, clock, pinned apps, that is all there is, and every one of them
is optional.

**The wallpaper** can be a picture, an animated GIF or a video. It is always
silent, and it only moves while the home screen is actually in front of you -
open another app or pull the settings panel down and it stops where it is.

A handful of backgrounds ship with the app, and the same screen also sets
**Android's own lock screen** - a picture of your own or one out of that
library. The two are kept apart: the home screen one is drawn by the launcher,
the lock screen one is handed to Android and stays there even if you switch
launchers.

The shipped ones live in `assets/wallpapers/`. The folder is the whole list -
drop a picture in, build, and it is in the picker, named after its file
(`sakura-night.png` becomes "Sakura night"). PNG, JPG, WEBP, GIF and the
common video containers; nothing else has to be edited.

**The letter bar on the right** only ever shows the letters that actually
hold something. Running a finger over one immediately reveals that letter's
apps, with no app drawer in between. Keep dragging to the left to pick a row
directly, launching an app in a single motion without ever lifting the
finger.

At the very bottom of the bar sits the **magnifier**: releasing there opens
a full text search across all apps, web apps and folders.

**Long-pressing an entry** - a pinned icon, a row in the search results, an
icon inside a folder - opens its quick actions: swap the icon, or change the
color of a folder, without the detour through the settings. For an installed
app it also lists that app's own shortcuts (see below).

### App shortcuts

Apps publish shortcuts about themselves: the last few chats in a messenger,
"new tab" in a browser, a playlist. Long-press an app and they are right
there, tapping one goes straight in.

The bookmark next to a shortcut **keeps** it. A kept shortcut stops being a
menu item and becomes an entry like any other: it sits in the app list under
its own letter, goes into folders, can be pinned to the home screen, gets a
name and a picture of your own in *Settings -> Apps -> Customize apps*, and
can be wired to a drawn shape. A chat with one person becomes an icon on the
home screen.

Keeping one also tells Android to hold it open. That matters for the dynamic
kind: a messenger publishes its four most recent chats and drops the rest, so
a kept chat would otherwise stop working within the day. Name and picture
follow the app from then on - a contact who changes their name changes it
here too.

Android hands shortcuts to whichever app the home button opens and to nobody
else, so they only appear once hanneslauncher is actually set as the home
app; the menu says so rather than just being empty. Apps hidden in the secret
folder take the shortcuts kept out of them along, and they come back when the
app does.

**Shortcuts you draw.** Draw a shape on the home screen - a heart, a house,
a circle, whatever you will remember - and it opens an app, an address, a
countdown or the settings panel. A shape is recognised wherever it is drawn
and at whatever size: only its outline counts, and which end it starts at.
When a drawing is not clearly one saved shape rather than another, nothing
happens rather than the wrong thing, and the settings warn while saving that
two shapes look too much alike.

One rule: draw it in a single stroke, without lifting the finger. And
because a straight pull up or down is still how the settings panel is
opened, start a shape sideways or on a curve. Shapes are set up under
*Settings → Apps → Shortcuts*, where the whole thing can also be switched
off without losing any of them.

The line under the finger can be turned off, so a shape leaves no trace on
the screen and still works, and while it is on its color is picked from the
shared palette - or left following the theme's accent, which is the default.

**Notification badges** on the pinned apps are off by default and can be
switched to a plain dot ("something is waiting") or to the number of waiting
notifications, in any color from the shared palette - a pinned folder adds up
everything inside it. It needs Android's notification access, and only the
count is ever read: no text, no sender, nothing stored. The settings screen
says which of the two halves of that access is missing - switched off, or
switched on but not actually handing anything over, which is what installing
a new APK over the old one leaves behind - and links straight to the Android
screen that fixes it.

### Clock

Eight styles, each with its own colors, plus position, alignment and the
distance from the top:

<p align="center">
  <img src="Images/uhr-stile.png" width="45%" alt="The eight clock styles to choose from">
</p>

Digital · Custom word clock · Roman numerals · Bars · Dot matrix ·
Split-flap · Orbit · Vertical

---

## Design

Everything the launcher draws itself - the panel, its cards, every settings
screen and every dialog - is one theme, changed under
*Settings → Appearance → Design*:

- **Color theme**: grey, rose, green, blue or dark, and each of the six
  colors it is made of - ground, cards, text, quieter text, accent, lines -
  can be set on its own on top of that
- **Rounding**, 4 px to 32 px. It sets the roundest surfaces; smaller cards
  and controls follow a golden step behind, so a big card stays rounder than
  a small one at every setting
- **Shadows**, off to strong. Each one is three layers - a contact line, a
  short throw and a wide haze - because that is what a real shadow is; a
  single soft blur is the same grey everywhere and gives nothing a near edge
- **Input fields**: a line under them, a full box, or a tint and no edge at
  all - every text field in the app follows it, search included
- **Spacing**, **card height** and **text size**, each as a multiplier
- **Panel opacity**: how much of the wallpaper shows through the panel
- **Motion**, off to calm: how long a theme change, a page or a card takes.
  Picking a theme is a crossfade through the colours in between rather than a
  cut, and the slider comes with something to tap, because a duration in
  milliseconds is a number nobody can picture
- **Haptics**, off to firm: how hard the phone answers a touch. One tick per
  letter while a finger runs down the alphabet bar, a heavier one when the
  drag crosses into picking a row, one when the panel snaps, one when a shape
  is recognised and a double when it isn't. The occasion is named in the code,
  never the strength, so turning it up turns all of them up together - and the
  slider itself fires what it is set to, so dragging it is the preview

Every size is derived from the golden ratio rather than picked one at a time:
the three corner radii are a golden step apart, the type ramp climbs by a half
step (so two steps make the whole ratio), and the spacing ramp is 4, 8, 12,
20, 32, 52 - each the sum of the two before it, which is that same ratio in
whole pixels. Sizes chosen separately drift a pixel or two out of relation and
the eye reads the result as approximate without being able to say why.

The type does the rest. Six sizes, not ten, with the work of telling text
apart done by weight and letter-spacing instead: tracking runs tight at the
top of the ramp and open at the bottom, and weight runs the other way, so a
title is set large and light while a section heading is small, spaced out and
capitalised. Everything shouting in bold is what a default looks like.

Surfaces come in three tiers - a widget card on the panel is drawn larger,
rounder and deeper than an app row next to it - so the screen has a visible
order without anything being hidden behind a menu. Every value is bounded, so
no combination of them can break the layout, and the default is a designed
look rather than whatever Material ships with.

Two rules keep the colors honest whatever they are set to, and neither does
anything to a theme that is already fine: text is lifted until it can be read
on the ground it sits on (keeping its own hue, so a warm grey stays one), and
a card cannot end up on the other side of the light/dark line from that
ground - a pale card on a dark page would leave no text color that works on
both. A colour is picked on a hue-and-saturation field with brightness and
opacity under it; opacity is offered wherever the colour is laid *on* top of
something, which is everywhere except the two the app paints its solid
grounds with.

The home screen is deliberately left out: the clock, the app list and the
wallpaper sit on top of the picture and keep the colors set for them
separately.

---

## Icons

Where an app's icon comes from is set under *Settings → Appearance → Icon
design*, and there are four answers:

- **Standard**: the icon each app brings along itself
- **Icon pack**: an icon pack installed on the phone redraws every app it
  covers
- **Colored**: every icon reduced to its brightness and re-tinted to one
  color, so a pile of brand logos reads as one set
- **Own picture**: a picture from the gallery, for one app

The first three are one choice for all apps at once. The fourth is per app
(*Settings → Apps → Customize apps*, or straight from the icon design screen)
and always wins over the other three: switching a pack on leaves every app you
gave a picture of its own untouched, and removing that picture hands the app
straight back to the pack or the color. Nothing is ever written onto an app,
so every one of these is undone by undoing it.

An app the pack has no icon for keeps its own - dressed in the pack's frame
when the pack ships one, so the odd app out still belongs to the set. Web
apps, folders and the launcher's own screens are not part of a pack at all.

### Which icon packs work

Not quite all of them, and the launcher says so itself: the icon design screen
lists the declarations it looks for under *Recognised packs*, read from the
platform side that does the looking, so the list in the app can never promise
support that isn't there.

A pack is an ordinary app, and there is no Android standard for announcing one
- every launcher invented its own name for it. These are the ten the launcher
accepts:

```
org.adw.launcher.THEMES              com.dlto.atom.launcher.THEME
com.novalauncher.THEME               ch.deletescape.lawnchair.ICONPACK
com.teslacoilsw.launcher.THEME       net.oneplus.launcher.icons.ICONPACK
com.anddoes.launcher.THEME           com.sonymobile.home.ICON_PACK
com.fede.launcher.THEME_ICONPACK     com.gau.go.launcherex.theme
```

Nearly every pack in the store names several of these, because a pack naming
none would be invisible to every launcher rather than just to this one - so in
practice they simply work. If one doesn't show up in the list, this is the set
it failed to match.

---

## The panel

Pull down from the top edge of the screen. It follows the finger one to one
and is dismissed by the reverse of the gesture that opened it.

<p align="center">
  <img src="Images/panel.png" width="30%" alt="Panel with an app row and a weather widget">
  <img src="Images/widget-editor.png" width="30%" alt="Widget editor with preview and layer list">
</p>

The panel is made of **blocks**, which can be reordered freely:

| Block | What it shows |
|---|---|
| **App row** | 0 - 6 icons per line |
| **Widget** | A card you built yourself (see below) |
| **Calendar** | Events for the next few days, from the calendars already synced on the device. Tapping one opens it in the calendar app. |
| **Notes** | A written note with formatting |
| **Code** | A card you write yourself in HTML, CSS and JavaScript (see below) |
| **Notifications** | What is waiting right now. Tap one to go where it points, swipe it away to clear it. |

Data sources, the calendar, the notification list and the update check are
only refreshed **when the panel is opened**, a panel nobody pulls down costs
no data at all.

**The notification block** uses the access the badges already need, and goes
one step further than they do: the badge reads a number, this reads the title
and the line under it so it can draw them. Nothing is stored, nothing leaves
the phone, nothing is read while the panel is shut, and the list is dropped
the moment it closes. Apps in the secret folder are not in it. It is off until
a block is added.

---

## Building widgets

Widgets don't come from other apps, they are put together in the launcher
itself. A card is a stack of elements:

- **Text**, with `{{placeholders}}` in it
- **Icon**, switching by rule (`< 5 °C` → snowflake, `"Rain"` → cloud)
- **Image**, from a URL that may itself contain placeholders, which is how a
  map tile follows your current location
- **Box**, a plain rectangle; put behind text on a busy picture, it makes
  the text readable again
- **Action**, a button that fires an HTTP call (a smart home device on your
  own network, say), either fixed or as a toggle

Elements are placed by dragging them right in the preview, the layer list
below decides what sits in front of what. The card itself can open an app, a
web app or a folder when tapped.

### Placeholders

`{{zeit}}`, `{{datum}}`, `{{wochentag}}`, `{{ort}}` and the coordinates work
right away. Device values such as `{{akku}}`, `{{speicher_frei}}`,
`{{verbindung}}`, `{{sonnenauf}}`, `{{mondphase}}` or `{{schritte}}` come as
one package you can switch on.

Beyond that, **any JSON URL** can be added as a data source. Once it has
been tested successfully, every value in it is reachable by its path:

```
{{wetter.current.temperature_2m}}
{{wetter.daily.temperature_2m_max[0]}}
```

The full list is in **[PLACEHOLDERS.md](PLACEHOLDERS.md)**, and live in the
app under *Edit widget → tap an element → "Insert value"*.

---

## Code widgets

Where a widget card is assembled from elements, a **code widget** is written:
HTML, CSS and JavaScript of your own, running inside the card. That is what
makes your own buttons and input fields, a canvas, a small game or a picture
shown only under some condition possible at all.

Each one gets its own folder on the device, so uploaded pictures and data
files are referenced by their plain name (`<img src="bild.png">`), and one
`launcher` object reaches the rest of the app:

```js
launcher.get('wetter.current.temperature_2m')  // a value from a data source
launcher.fetch(url, {useSource: 'wetter'})     // your own API call, no CORS
launcher.store('score', 12)                    // survives a restart
launcher.open('com.example.app')               // opens an app
```

Written under *Settings → Panel & data → Code widgets*, with a full-screen
preview that shows errors and `console.log` underneath it.

The whole thing - the API in full, examples, and what to watch out for - is
in **[CODE_WIDGETS.md](CODE_WIDGETS.md)**.

---

## More features

- **Folders**, nestable to any depth, each with its own color
- **App shortcuts**: an app's own shortcuts on a long press, and keeping one
  turns it into a full entry (see above)
- **Web apps**: treat links and PWAs like apps, and pick per entry which
  browser they open in
- **Customize apps**: rename, set your own icon, uninstall
- **Design**: theme, rounding, shadows, spacing and text size for the whole
  app (see above)
- **Icon design**: standard icons, an installed icon pack, one color for all
  of them, or your own picture per app (see above)
- **App list**: font, size, line spacing, color, sort order
- **Language**: German or English, following the system language by default
- **App pairs**: two apps as one entry, opening side by side in split screen.
  It goes in the app list, into folders, onto the home screen and onto a drawn
  shape like anything else
- **Search**: the magnifier ranks by how well a name matches rather than
  filtering and sorting alphabetically - a name that starts with what was
  typed beats one that merely contains it, `ytm` finds YouTube Music - and it
  answers sums, finds settings, and optionally contacts and a web search
- **Backup**: the app keeps its own, in `Download/hanneslauncher`, once a day
  and always right before it installs an update - the folder survives
  uninstalling the app, which is the moment the copy is for. Restore one with
  a tap, or send a copy off the phone. Everything is in it, pictures included
  (see below)
- **Update**: the app checks GitHub for new releases and installs the APK
  directly (see [RELEASE.md](RELEASE.md))
- **Settings search**: across every setting, in both languages at once, so
  typing German also finds the English terms

---

## Installation

Download a ready-made APK from the
[releases](https://github.com/Hannes-swd/Hanneslauncher/releases) and
install it. Then set it as the home app in Android once; the app helps with
that on first launch and also keeps it under *Settings → App → Default home
app*.

> **Before updating by hand:** Android only installs over an existing app if
> both are signed with the same key. If you ever do have to uninstall, every
> setting goes with the app - which is why the launcher now writes a snapshot
> into `Download/hanneslauncher` by itself, once a day and always right
> before it installs an update. That folder is outside the app, so it is
> still there afterwards; *Settings → App → Backup* lists what is in it and
> puts one back. (On Android 9 and older the snapshots live in the app's own
> external folder instead, which does not survive an uninstall - copy one off
> the phone first there.)

## Building it yourself

```powershell
flutter pub get
flutter run                  # to the connected device
flutter build apk --release  # build/app/outputs/flutter-apk/app-release.apk
```

Needs the Flutter SDK with Dart `^3.12.2`. A release including the GitHub
upload is one command, `.\tool\release.ps1 1.5.0`, details in
[RELEASE.md](RELEASE.md).

```powershell
flutter test      # tests
flutter analyze   # linter
```

## Permissions

All of them are optional; without one, exactly one feature is missing.

| Permission | What for |
|---|---|
| Internet | The widgets' data sources, the update check |
| Location (coarse) | `{{ort}}`, coordinates, sunrise/sunset |
| Read calendar | The calendar block on the panel |
| Network state | `{{verbindung}}` |
| Activity recognition | `{{schritte}}` |
| Usage access | `{{meistgenutzt}}` (granted by hand in the Android settings) |
| Install apps | Updating straight from the app |
| Set wallpaper | Putting a picture on Android's lock screen |

## How it is put together

Plain Flutter, no state management package: every area has a singleton
`ValueNotifier` controller (`*_controller.dart`) keeping its state in
`SharedPreferences`. Every key one of them writes is listed in
`settings_keys.dart` with what a backup does with it, and
`test/settings_keys_test.dart` reads the keys back out of the source and
fails while one of them is unclassified - so a new setting cannot be added
without the backup question being asked. What Flutter can't do itself, the app list, the
calendar, device sensors, excluding the screen edge from the system
gestures, runs through method channels in
`android/app/src/main/kotlin/.../MainActivity.kt`.

Nothing picks a color, a corner radius or a text size of its own:
`design_tokens.dart` holds them all, hands them to Material as a `ThemeData`
plus a `ThemeExtension`, and everything else reads `context.design`. The home
screen is the one thing outside it, for the reason given above.

Code widgets are the one part that doesn't live in `SharedPreferences`: each
one keeps its HTML, CSS, JavaScript and uploaded files in its own folder
under the app's documents directory, and runs in a WebView that reaches the
app only through a named channel (`code_widget_bridge.dart`).

The app list is read once and then only when Android says the installed apps
changed (`installed_packages_watch.dart`); it used to be re-read, icons and
all, every time the launcher came back to the foreground. Apps are started
through `app_launcher.dart` with the rectangle of the icon that was tapped,
which is what makes the window grow out of it.

| File | Contents |
|---|---|
| [PLACEHOLDERS.md](PLACEHOLDERS.md) | Every widget placeholder |
| [CODE_WIDGETS.md](CODE_WIDGETS.md) | Writing a widget in HTML, CSS and JavaScript |
| [RELEASE.md](RELEASE.md) | Bump the version, build, publish on GitHub |

---

<sub>Note: parts of this project, including this documentation, were written
with the help of AI.</sub>
