# Nazzil design direction: Finery

Status: asked for by the owner on 2026-11-13, in his words "lets do this style https://finery.theiraqieslove.workers.dev/". It covers the Flutter app in `flutter/`.

This file used to describe Cinema, the direction chosen on 2026-11-11: black and white with one Grape accent, Fraunces and Ruqaa type, square pictures, no shadows. All of that is gone. Its drawings stay in `design/remake/` as history.

## How it got here

All on 2026-11-13, each step at the owner's word:

1. "rewrite the app in apple style": the iOS idiom. Inter and IBM Plex Sans Arabic replaced Fraunces and Ruqaa, settings became iOS segmented controls, and screens slide the iOS way.
2. "We dont have to use grape colour": Grape went, for Apple's blue and greys.
3. "try to copy polyfrost": a centred head on the empty Home.
4. "the download shouldnt be in the middle": the fetched post became a poster that fills the screen, with its controls at the foot. He liked this, and it stays.
5. "lets do this style": Finery, below.

On 2026-11-16 he asked: "for pc and widescreens can you improve the gui for them? It looks like a mobile app and its unoptimized for pcs". A computer's window now opens wide, and a wide window has a toolbar over one page. See Wide windows below. The phone layout is unchanged.

## Design read

Reading this as: a personal media saver for people who read Arabic or English, phone first and desktop second, dressed as Finery's product page. That means a soft grey page, white rounded tiles on soft shadows, one sapphire accent, and heavy, tight headlines under a blue eyebrow. Dial ENERGY 2 / RHYTHM 2 / MOTION 2.

ENERGY 2: the picture stays the loudest thing. A fetched poster fills the top of the screen. Around it everything is grey, white and ink, with blue on the button that does the next step.

RHYTHM 2: tiles in a column, each screen composed from its content. Home is a head, an action tile and a showcase tile. A fetched post is a poster over one tile of controls. The library is a catalogue head over a grid of rounded pictures. Settings is a stack of titled tiles.

MOTION 2: motion reports the download. The bar eases between reports, and colour crosses a picture once when it lands. Screens slide the iOS way. All of it switches off with the system reduce motion setting.

## Identity

Nazzil, نزّل, is Arabic for "download", said as a command. The app keeps that tone: buttons are short commands (الصق, اجلب, نزّل, استأنف, أغلق), and statuses are one or two words.

The Arabic is standard Arabic (فصحى), by the owner's call on 2026-11-11. Before that the app spoke Iraqi dialect. A count takes the form its number asks for (صورتان, 3 صور, 11 صورة). A test in `flutter/test/strings_test.dart` fails if a dialect word comes back. The download notification on Android is drawn by the system, and the app hands it the same words in its own language, so an Arabic app on an English phone still gets an Arabic notification.

The logo is the word نزّل written in the Ruqaa hand. The owner chose it on 2026-11-11 out of twenty-five concepts (number 13; the sheets are in `design/logo/boards/`). It stands in the header where the name used to be set as text. The letters take the text colour, and the two dots and the shadda take the accent.

On the launcher icon the ground is white and the letters are `#1D1D1F`, as the icon stands on its tile on Home. `design/logo/export.py` draws the header's outline and the icons of every platform from the outlines of the typeface, so the logo is never redrawn by hand. Its colours are in `design/logo/chosen.py`. Change them there and run it again.

While the app starts, the phone shows the same word on the page colour of the theme the app is set to: black, or `#F5F5F7` when the app is set light. The phone draws that screen before the app runs, so the app tells it the theme each time it starts and each time the setting changes. The phone cannot know in two cases. The first time the app is opened it has not said anything yet, so the launch screen follows the phone's own day or night. Android before 12 cannot be told at all, so there the launch screen is always the dark one, which is how the app opens unless the user chose otherwise.

## Colour

Light theme: page `#F5F5F7`; tiles, sheets and dialogs `#FFFFFF`; fields and tracks inside a tile `#F2F3F7`; text `#1D1D1F`; muted text `#6E6E73`; hairlines `#D2D2D7`; control edges `#6D6D72`.

Dark theme: page `#000000`; tiles, sheets and dialogs `#1C1C1E`; fields and tracks `#2C2C2E`; text `#F5F5F7`; muted text `#A1A1A6`; hairlines `#38383A`; control edges `#8A8A8E`.

The accent is Finery's sapphire, `#0071E3` (`NazzilColors.tint`). It is the only hue the interface has, and it marks these things:

- the fill of the button that does the next step (Paste, Fetch, Download, Resume, Play), which carries white letters at 4.7:1 and glows in its own blue;
- the download bar;
- the line at the front of arriving colour;
- the logo's dots.

Words in the accent take Apple's link blues instead: `#0066CC` on light and `#2997FF` on dark. That covers eyebrows, the open tab, the version number and link icons. `#0071E3` falls just short of 4.5:1 for small words on the page.

Finery gilds the first badge in its row to put its main product forward. Nazzil's badges name the apps a link can come from, and none of them comes first, so every badge is the same plain pill and nothing is gold. YouTube's badge was gold until the owner asked why on 2026-11-14.

A picked choice shows without the accent, so the accent stays for the next step alone:

- In a segmented control, the thumb is white on a `#EEEEF0` track, or `#636366` on dark, and sits a little proud of the track in light.
- A picked filter pill is filled with the text colour and lettered in the page colour.

A picture that is not saved is drawn in grey at 42% brightness. Tags on a picture are white on a black scrim at 72%, which holds 4.5:1 over a white photo.

Red is for errors and for Delete: `#FF6961` on dark, `#D70015` on light. An error line also carries an icon, so it is not told by its colour alone.

Dark is the default theme, because a saved video or photo reads best against black. Light and follow-the-system are in Settings. The viewer is black in every theme.

## Type

Inter sets English, and every digit and Latin name in the Arabic app too. IBM Plex Sans Arabic sets Arabic. Each language sets its own typeface first and the other behind it. A run of the other script (an English title in the Arabic app, a link, a language named in its own letters) is turned round, so it gets its own typeface first and its own lines (`NazzilTheme.inScript`).

Inter ships in Regular, SemiBold, Bold and ExtraBold. Plex Arabic ships in Regular, SemiBold and Bold. Both are under the SIL Open Font License, and the licence of each lies next to its files in `flutter/assets/fonts/`. Both are drawn to sit on one line at one size, so neither is enlarged.

Finery's ramp: headlines are heavy and tight, everything else is plain.

| Role | Size | Weight | Tracking |
|---|---|---|---|
| Screen heading (Finery's h1) | 34 | ExtraBold | −0.035 em |
| Section headings | 24, 22 | ExtraBold | −0.025, −0.02 em |
| Post titles | 20 | Bold | −0.02 em |
| Tile titles | 17 | Bold | −0.01 em |
| Body | 17, 16; 15 for muted lines | Regular | none |
| Buttons | 16 | SemiBold | none |
| Hints | 13 | Regular | none |
| Badges and tags | 12 | SemiBold | none |

The eyebrow is 13 Bold, in the link blue, in capitals with 0.14 em between letters. It stands over each screen heading, and it is the facts line of a post ("YOUTUBE · 9:56"). A screen reader hears it in its own case.

Arabic is never letter-spaced and never put in capitals, because spacing breaks its joins. An Arabic eyebrow is the same blue Bold with no tracking. An Arabic headline is set in Plex Bold, its heaviest weight, at the same size. A test checks that every weight the theme asks for is shipped, or close enough that the screen does not smear a lighter face.

Sizes follow the system font size. Headings follow it up to 1.3 times, since they are already large.

## Shape, surface and spacing

Corners are 28 on tiles, 26 on sheets and dialogs, 14 on fields and buttons, and 18 on library pictures. The segmented control rounds at 11 outside and 9 on its thumb. Badges, tags and filters are pills.

In light, tiles float on Finery's shadow: a hairline of shade under the edge and a wide, soft fall (0 1 1 at 4%, 0 12 34 at 6%). On the black page a shadow cannot show, so a dark tile stands on its grey.

Three other surfaces have their own treatment:

- The next-step button glows in its blue (0 8 16 at 24%).
- The showcase tile on Home has Finery's faint light from above: `#FBFBFD` to `#EAEEF5`, or `#222327` to `#141519` in dark. The icon stands on it, on a white square with a pedestal shadow.
- The poster keeps a black fade under the phone's status bar, so the clock reads over a bright picture.

Tiles sit 16 from the screen edge (12 under a poster) and 16 apart, with 20 inside. Library pictures are 12 apart, and the strip of last saves keeps 10 between frames.

Anything tappable is at least 48 high. A pill may be drawn 36 high inside its 48.

## Layout

On a phone each screen is one column, at most 640 wide. Two tabs, Home and Library, sit at the bottom on a white bar (`#1C1C1E` in dark) under a hairline. The open tab is in the link blue with a filled icon. Settings opens from the header and takes the place of both.

The header holds the logo and the way into Settings. Under the logo it says what is going on: downloading or converting, how many wait behind it, or that something is paused. With nothing going on it says nothing.

### Home, nothing fetched

- With no saves yet, Finery's head: the eyebrow "VIDEO · PHOTOS · AUDIO", the heading "Download from anywhere.", and a muted line.
- The action tile:
  - the link field;
  - the button that names the next step: Paste while the field is empty, Fetch once it holds a link;
  - the hint "or share a post to Nazzil from any app".
- With no saves yet, a "Works with" showcase follows: the icon on its pedestal, and the apps as pill badges.

Once there are saves, the head and the showcase step back for a quiet list of the apps and the strip of last saves along the bottom.

### Home, with a post fetched

The poster runs from the top edge of the screen and fills what the controls leave. Its foot is rounded at 28 until it is scrolled away, and a black disc on it closes the post.

Under it is one tile:

- the facts eyebrow;
- the title;
- who posted it;
- the choices: an iOS segmented control for HD, SD and Audio, or the choices of a photo post;
- Download.

While the post downloads, the button gives way to "Downloading… 50%" over a bar in the accent, with Pause and Cancel. The tile rests at the foot, 16 above the tabs. The owner liked this arrangement on 2026-11-13, so keep it.

### Library

The count stands as an eyebrow over the heading, centred. The kind filters and the app menu follow as pills, centred and wrapping, and then the grid.

Pictures are 3 by 4, two across on a phone and more as the width allows. Each is no wider than 220, 12 from the next, and rounded at 18. A picture carries one tag pill, saying what it is or its state, and no title. Tapping it opens a sheet with its title and every action for it.

### Settings

- The app's name as an eyebrow over the heading.
- Language and Theme, each in a titled tile with a segmented control.
- About.
- Credits, as a tile of rows parted by inset hairlines.
- The version, centred at the foot with its number in the link blue, and an update button when a newer version is out.

### Wide windows

A computer opens Nazzil at 1200 by 800, or at 90% of a smaller screen, in the middle of it. The window can be made no smaller than 400 by 560. It used to open at 480 by 880, the shape of a phone, which is much of why it looked like a phone app.

From 720 wide, and 480 high so that a phone on its side stays a phone, the tabs and the phone's header give way to a toolbar over one page:

- The toolbar runs across the window in the tiles' colour, over a hairline. It holds the logo with its line of what is going on, then the link field and the next-step button in the middle, at most 720 wide, then Settings at the end. The button says Paste, or Fetch once a new link is typed. On a computer the empty field says "Paste a link, or press Ctrl+V", or ⌘V on a Mac.
- The page under it is at most 1440 wide, in the middle of the window, and scrolls as one.
  - A fetched post leads it in one tile. Its picture stands at the start, up to 480 wide and in its own shape up to a square, with the black close disc on it. The facts, title, choices and Download stand beside it.
  - The library follows. Its count and heading stand at the start of one line and its filters at the far end. Its pictures are 3 by 4, no wider than 200 and 16 apart, each with its title (two lines at most) and its app under it.
  - With nothing saved and nothing fetched, Finery's head and the "Works with" showcase stand in the middle of the page instead.
- A picture dims a little under the pointer. A right click opens its actions where the pointer is. A click opens them in a dialog 440 wide, where a phone opens a sheet.
- Settings takes the page's place under the same toolbar, in a column 640 wide.
- Esc closes Settings, then stops a fetch, then takes the post off the page.

## Icons

Material icons, the rounded and outlined sets that ship with Flutter. Every icon either sits beside its word or carries a tooltip and a screen reader name. Each one names its own thing: paste, download, pause, close, photo, video, audio, share, delete, settings. The icon on the Home showcase is the one picture shown for its own sake, and screen readers skip it, since the header already names the app.

## Motion

- The download bar eases between progress reports over 250 ms.
- The frame takes the shape of its picture over 220 ms when the picture loads.
- When a download lands, colour crosses its picture once in the Saved dialog, over 700 ms.
- In the library, a picture still arriving is grey where its file is still to come.
- Album photos glide for 280 ms when turned by button or key.
- Screens slide in the iOS way. Sheets and dialogs use Flutter's own transitions.

Nothing loops, and nothing moves without a download or a tap behind it. Everything above is skipped under the system reduce motion setting.

## Themes and checks

Dark (the default), light, or follow the system. The tests in `flutter/test/` measure text contrast in both themes and pin the layout of each screen. `NAZZIL_SHOTS=<dir> flutter test test/shots.dart` renders every screen at 390 by 844 for review, and a computer's window at 1200 by 800, 1920 by 1080 and narrower sizes.

## Open to the owner

Every Arabic line was rewritten in standard Arabic by the agent on 2026-11-11, at the owner's request, and is his to correct. Two choices in it are his to confirm:

- Buttons stay commands (نزّل, الصق, احذف), not the nouns phone systems use (تنزيل, لصق, حذف).
- The library is called التنزيلات, from the same root as نزّل, where it was التحميلات. تحميل is kept for a picture that fails to load.

The name is written نزّل, with its shadda, as the logo writes it.

The agent picked Inter and IBM Plex Sans Arabic for the iOS look, as the closest openly licensed matches to Apple's San Francisco and SF Arabic. Putting others in their place is a change to `flutter/pubspec.yaml` and to two names in `flutter/lib/theme/nazzil_theme.dart`. The Anthropic Sans files he sent on 2026-11-11 are out of the app. They carry no licence, and they are still in the history of this repository, which matters only if the repository is ever made public.

The launcher icon moved from the warm paper `#F4F2EE` of Cinema to white, to match its tile in the app. Going back is one line in `design/logo/chosen.py`.

The app locks to portrait (`flutter/lib/main.dart`). Whether tablets should rotate is his call.

Delete removes the copy Nazzil keeps and leaves the gallery copy. Whether Delete should remove both is his call.
