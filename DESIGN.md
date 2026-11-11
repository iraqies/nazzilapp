# Nazzil design direction: Cinema

Status: chosen by the owner on 2026-11-11, out of four drawn directions. The drawings are in `design/remake/`, and Cinema is `design/remake/boards/d3-cinema-tall.jpg`.

It covers the Flutter app in `flutter/`.

## Design read

Reading this as: a personal media saver for people who read Arabic or English, phone first and desktop second, in a screening room style where the interface is black and white and the saved picture is the only colour, dial ENERGY 2 / RHYTHM 2 / MOTION 2.

Dial: ENERGY 2 / RHYTHM 2 / MOTION 2

ENERGY 2: the picture is loud and the interface around it is quiet. A poster fills the top of the screen and a percentage stands 88 high beside it, while every control is black, white or grey.

RHYTHM 2: three compositions, each from its content. Home is one frame and one button. A fetched post is a poster over a short stack of controls. The library is a wall with no margins.

MOTION 2: motion reports the download. Colour moves across the poster as the file arrives, the frame takes the shape of the picture once it loads, and colour sweeps the picture once when a download lands. Screens and sheets use Flutter's own transitions. All of it switches off with the system reduce motion setting.

## Identity

Nazzil, نزّل, is Arabic for "download", said as a command. The app keeps that tone: buttons are short commands (الصق, اجلب, نزّل, استأنف, أغلق), and statuses are one or two words.

The Arabic is standard Arabic (فصحى), by the owner's call on 2026-11-11. Before that the app spoke Iraqi dialect. A count takes the form its number asks for (صورتان, 3 صور, 11 صورة). A test in `flutter/test/strings_test.dart` fails if a dialect word comes back. The download notification on Android is drawn by the system, and the app hands it the same words in its own language, so an Arabic app on an English phone still gets an Arabic notification.

The motif is colour arriving. A fetched post shows in colour, as it looks where it came from. When its download starts the picture goes grey, and colour comes back across it from the leading edge as the file arrives, with a thin line of Grape at the front. The same grey marks everything that was asked for and is not on the device: a waiting, paused, failed or removed item is grey, and a saved one is in colour. The user reads the state of a download from the picture before reading a word.

The second motif is the frame. Home opens on an empty dashed frame that asks for a link. The fetched post fills it. The library is frames edge to edge, and the last saves run along the bottom of Home as a strip.

The logo is the word نزّل written in the Ruqaa hand, with its two dots and its shadda in colour. The owner chose it on 2026-11-11 out of twenty-five concepts (number 13; the sheets are in `design/logo/boards/`). In the app it stands in the header where the name used to be set as text: the letters take the text colour and the dots are Grape. On the launcher icon the ground is paper `#F4F2EE`, the letters are ink `#111111` and the dots are Grape as well. Both are drawn from the outlines of the typeface by `design/logo/export.py`, which writes the header's outline and the icons of every platform, so the logo is never redrawn by hand. While the app starts, the phone shows the same word on the page colour of the theme the app is set to: light letters on black, or ink letters on paper when the app is set light. The phone draws that screen before the app runs, so the app tells it the theme each time it starts and each time the setting changes. Two cases are left where the phone cannot know. The very first time the app is opened it has not said anything yet, so the launch screen follows the phone's own day or night. And Android before 12 cannot be told at all, so there the launch screen is always the dark one, which is how the app opens unless the user chose otherwise.

## Colour

The interface has no colour of its own. Dark theme: page `#000000`, sheets and dialogs `#161616`, text `#F5F3EE`, muted text `#A8A49C`, hairlines `#2E2E2E`, control edges `#777777`. Light theme: page `#F4F2EE`, sheets and dialogs `#FFFFFF`, text `#111111`, muted text `#5F5B54`, hairlines `#D5D0C6`, control edges `#807B72`. Covers and thumbnails are other people's pictures, and on these neutrals they are the only colour on screen.

The accent is Grape `#8B5CF6`, and the app has no other. It goes in two places only: the fill of the one button that does the next step (Paste, Fetch, Download, Resume, Play), and the line at the front of the arriving colour. The marks of the logo carry it too. Text on that fill is ink `#0B0B0C`, never white, since ink passes 4.5:1 on Grape and white does not.

Grape is the owner's call, made on 2026-11-11 in two steps. Until then the accent was a colour the user picked out of five, and the first of them was Rose `#FF4D8D`, a pink. He found that the pink stuck out of the black and white. He was shown sixteen colours on the app's own screens (six soft ones, six strong ones and the four the app had beside Rose) and picked Grape. Later that day he asked that the app allow no other colour. So Settings has no colour to pick, and a phone that had another one picked is in Grape. Purple on a black page is a look that many generated interfaces share. Here it is his choice, and it stays where the accent was: one button, one line and the three marks of the logo, with no gradient and no glow.

A picked choice (a quality, a filter, a setting) is filled with the text colour and lettered in the page colour. That keeps the accent for the next step alone.

A picture that is not saved is drawn in grey at 42% brightness. Tags on a picture are white on a black scrim at 72%, which holds 4.5:1 over a white photo. The percentage sits on a block of the page colour, so it reads the same over any picture.

Red is for errors and for Delete: `#FF7A85` on dark, `#B3202C` on light. An error line also carries an icon, so it is not told by its colour alone.

Dark is the default theme, because a saved video or photo reads best against black, as in a cinema or a photo viewer. Light and follow-the-system are in Settings. The viewer is black in every theme.

## Type

Two typefaces, one for each script. Arabic is in the lettering of the logo, which the owner asked for on 2026-11-11. English is in Fraunces, a serif picked the same day to go with it, when he asked for an English typeface that matches the Arabic one.

Fraunces sets English, and every digit and Latin name in the Arabic app too. Nineteen typefaces were set next to the Arabic at the app's sizes, and Fraunces came closest in three ways that can be seen. Its strokes swell and thin the way a broad pen's do and end soft and round, as the Ruqaa hand does. It is as dark on the page: a line of it carries about nine tenths of the ink a line of Ruqaa does, where most serifs carry far less and look faint beside it. And it has one cut for reading sizes and another for headings. The Text cut sets reading sizes, in Regular and SemiBold. The Display cut sets headings, post titles and the percentage, in SemiBold. Those three files are the ones in the app. Nothing is set in italics or in a third weight.

Aref Ruqaa sets Arabic. It is the hand the logo is written in, so the name in the header and the words under it are one lettering. It has a regular and a bold, and the bold stands where English is SemiBold.

The app carries neither typeface as released. `design/type/build.py` makes its copies from the releases in `design/type/upstream/`, and checks that no letter, join or space is redrawn. The copies of Fraunces are three fixed cuts of the one file it is released as, all with its soft ends. Their letters are drawn a ninth larger on the body, which puts the small letters a little over half the text size tall, as a phone's own typeface has them. They also carry a second set of figures, all of one width, which the percentage uses so that it does not shake as it counts. The copies of Ruqaa hold Arabic only, so Latin letters and digits fall through to Fraunces. Their letters are drawn a third larger on the body, because Ruqaa is small for its size and would read smaller than the English beside it. The middle of a line is in the same place in both typefaces, so a line holding both scripts is no taller than a line holding one.

Each language sets its own typeface first and the other behind it. A run of the other script (an English title in the Arabic app, a link, a language named in its own letters) is turned round, so it gets its own typeface first and its own lines.

One size suits both scripts. The scale: percentage 88, screen heading 40, post title 28, frame prompt 26, dialog title 21, section label 17, button 17.5, body 16 and 15, labels 15, small 14 and 13.5, tab label 12.5. Arabic lines stand taller, for the letters Ruqaa stacks and hangs below the line. Letter spacing is always zero, because spacing breaks the joins of Arabic. Sizes follow the system font size. The large sizes follow it up to 1.3 times, since they are already large.

## Shape, surface and spacing

Pictures have square corners, because they are frames cut from a film. Controls have corners of 8, sheets and dialogs 12, tags 4. Nothing is a pill.

Surfaces are flat. There are no shadows, glows or decorative gradients. One gradient exists: a black fade over the top of a poster that runs under the phone's status bar, so the clock and battery stay readable over a bright picture. A post that came with no picture gets no fade.

Spacing is 20 at the screen edge, 28 between groups and 8 to 16 inside a group. Pictures ignore the edge spacing: the poster and the library wall run to the screen edge, and 2 separates one wall tile from the next.

Anything tappable is at least 48 high.

## Layout

On a phone each screen is one column, at most 640 wide, with two tabs at the bottom: Home and Library. Settings opens from the header and takes the place of both.

The header holds the logo and the way into Settings. Under the logo it says what is going on, on every screen: downloading or converting, how many wait behind it, or that something is paused. With nothing going on it says nothing.

Home, with nothing fetched: the header, the frame, one button, the list of supported apps, and the strip of last saves along the bottom. The frame takes the room the rest leaves and is never flatter than 16 to 9. It is also the link field: tapping it lets the user type or edit a link. The button names the next step, so it reads Paste while the frame is empty and Fetch once it holds a link.

Home, with a post fetched: the poster runs from the top edge of the screen, in the shape of the picture. It is never flatter than 16 to 9, and never taller than 62% of the screen or than what leaves the words and controls under it the room they need at their tallest. Under it sit where the post is from, its title, the choices and one Download button. While it downloads, the button gives way to a status line with Pause and Cancel, and the percentage stands on the poster. The close button on the poster empties the frame again.

Library: the heading and count, the kind filters as text tabs, the app filter as a menu, then the wall. Tiles are 3 by 4, two across on a phone and more as the width allows, no wider than 220. A tile carries one tag (what it is, or what state it is in) and no title. Tapping a tile opens a sheet with its title and every action for it. The picture gets the space because it is how people recognise a download.

In a window 960 wide or more, Home (460 wide) and the library sit side by side under one header, and the tabs and the strip go away, since the library is in view.

## Icons

Material icons, the rounded and outlined sets that ship with Flutter. Every icon either sits beside its word or carries a tooltip and a screen reader name. Each one names its own thing: paste, download, pause, close, photo, video, audio, share, delete, settings. None is decoration.

## Motion

The colour on a poster follows the download and eases between updates over 250 ms. The frame resizes to the picture's shape over 220 ms when the picture loads. When a download lands, colour sweeps across its picture once in the Saved dialog, over 700 ms. Album photos glide for 280 ms when turned by button or key. Screens, sheets and dialogs use Flutter's own transitions.

Nothing loops and nothing moves without a download or a tap behind it. Everything above is skipped under the system reduce motion setting.

The confetti of the earlier design is gone. The picture reaching full colour is the celebration.

## Themes

Dark (the default), light, or follow the system. The tests in `flutter/test/` measure text contrast in both.

## Open to the owner

Every Arabic line was rewritten in standard Arabic by the agent on 2026-11-11, at the owner's request, and is his to correct. Two choices in it are his to confirm. Buttons stay commands (نزّل, الصق, احذف) and are not the nouns phone systems use (تنزيل, لصق, حذف). The library is called التنزيلات, from the same root as نزّل, where it was التحميلات. تحميل is kept for a picture that fails to load. The name is written نزّل, with its shadda, as the logo writes it.

English is set in Fraunces, which the agent picked on 2026-11-11 when the owner asked for a typeface that matches the Arabic. The sheet he was sent with it shows five others set the same way: Newsreader, Alegreya, Lora, Playfair Display, and the English letters Aref Ruqaa itself carries. Putting one of them in its place is a change to `design/type/build.py`, which makes the app's copies, to `flutter/pubspec.yaml`, and to two names in `flutter/lib/theme/nazzil_theme.dart`. Fraunces and Aref Ruqaa are both under the SIL Open Font License, which lets a public app ship them, and the licence of each lies next to its files. The Anthropic Sans files he sent first are out of the app. They carry no licence, and they are still in the history of this repository, which matters only if the repository is ever made public.

The app locks to portrait (`flutter/lib/main.dart`). Whether tablets should rotate is his call.

Delete removes the copy Nazzil keeps and leaves the gallery copy. Whether Delete should remove both is his call.
