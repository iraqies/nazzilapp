# Nazzil design direction: Cinema

Status: chosen by the owner on 2026-11-11, out of four drawn directions. The drawings are in `design/remake/`, and Cinema is `design/remake/boards/d3-cinema-tall.jpg`.

It covers the Flutter app in `flutter/`.

## Design read

Reading this as: a personal media saver for Iraqi phone users, phone first and desktop second, in a screening room style where the interface is black and white and the saved picture is the only colour, dial ENERGY 2 / RHYTHM 2 / MOTION 2.

Dial: ENERGY 2 / RHYTHM 2 / MOTION 2

ENERGY 2: the picture is loud and the interface around it is quiet. A poster fills the top of the screen and a percentage stands 88 high beside it, while every control is black, white or grey.

RHYTHM 2: three compositions, each from its content. Home is one frame and one button. A fetched post is a poster over a short stack of controls. The library is a wall with no margins.

MOTION 2: motion reports the download. Colour moves across the poster as the file arrives, the frame takes the shape of the picture once it loads, and colour sweeps the picture once when a download lands. Screens and sheets use Flutter's own transitions. All of it switches off with the system reduce motion setting.

## Identity

Nazzil, نزّل, is Arabic for "download", said as a command. The app keeps that tone: buttons are one-word commands in Iraqi dialect (جيب, نزّل, كمّل, وقّف, سكّر), and statuses are one or two words. The Arabic is Iraqi, not formal Arabic, because the app is made for people who talk that way.

The motif is colour arriving. A fetched post shows in colour, as it looks where it came from. When its download starts the picture goes grey, and colour comes back across it from the leading edge as the file arrives, with a thin line of the picked colour at the front. The same grey marks everything that was asked for and is not on the device: a waiting, paused, failed or removed item is grey, and a saved one is in colour. The user reads the state of a download from the picture before reading a word.

The second motif is the frame. Home opens on an empty dashed frame that asks for a link. The fetched post fills it. The library is frames edge to edge, and the last saves run along the bottom of Home as a strip.

The name is set as text in the header. There is no logo in the app, because none was drawn. The letter N tile of the earlier design is gone, and the launcher icon is unchanged.

## Colour

The interface has no colour of its own. Dark theme: page `#000000`, sheets and dialogs `#161616`, text `#F5F3EE`, muted text `#A8A49C`, hairlines `#2E2E2E`, control edges `#777777`. Light theme: page `#F4F2EE`, sheets and dialogs `#FFFFFF`, text `#111111`, muted text `#5F5B54`, hairlines `#D5D0C6`, control edges `#807B72`. Covers and thumbnails are other people's pictures, and on these neutrals they are the only colour on screen.

The user still picks one colour out of five: Rose `#FF4D8D` (the default), Ocean `#2F7BFF`, Emerald `#12B886`, Sunset `#FF7139`, Grape `#8B5CF6`. It is the accent, and it goes in two places only: the fill of the one button that does the next step (Paste, Fetch, Download, Resume, Play), and the line at the front of the arriving colour. Text on that fill is ink `#0B0B0C`, never white, since ink passes 4.5:1 on all five and white fails on all five.

A picked choice (a quality, a filter, a setting) is filled with the text colour and lettered in the page colour. That keeps the accent for the next step alone.

A picture that is not saved is drawn in grey at 42% brightness. Tags on a picture are white on a black scrim at 72%, which holds 4.5:1 over a white photo. The percentage sits on a block of the page colour, so it reads the same over any picture.

Red is for errors and for Delete: `#FF7A85` on dark, `#B3202C` on light. An error line also carries an icon, because Rose and Sunset sit close to red.

Dark is the default theme, because a saved video or photo reads best against black, as in a cinema or a photo viewer. Light and follow-the-system are in Settings. The viewer is black in every theme.

## Type

Archivo sets Latin text. Its narrow cuts are the lettering of film posters and title cards, and one variable file holds both the regular width for reading and the narrow width for titles. Titles, the percentage and the header use width 62 to 88 at weight 800. Everything else is regular width.

Changa sets Arabic. Archivo has no Arabic letters, so Arabic falls through to it, while a Latin title inside the Arabic app still shows in Archivo. Changa is drawn with the same sturdy, squared shapes and goes up to weight 800, so an Arabic heading carries the same weight as an English one. Arabic lines are set taller for the marks above and below the letters, and letter spacing is always zero in Arabic because spacing breaks the joins.

The scale: percentage 88, screen heading 42 (36 in Arabic), post title 30, frame prompt 26, dialog title 21, section label 17, body 16 and 15, small 14 and 13.5, tab label 12.5. Sizes follow the system font size. The large sizes follow it up to 1.3 times, since they are already large.

## Shape, surface and spacing

Pictures have square corners, because they are frames cut from a film. Controls have corners of 8, sheets and dialogs 12, tags 4. Nothing is a pill.

Surfaces are flat. There are no shadows, glows or decorative gradients. One gradient exists: a black fade over the top of a poster that runs under the phone's status bar, so the clock and battery stay readable over a bright picture. A post that came with no picture gets no fade.

Spacing is 20 at the screen edge, 28 between groups and 8 to 16 inside a group. Pictures ignore the edge spacing: the poster and the library wall run to the screen edge, and 2 separates one wall tile from the next.

Anything tappable is at least 48 high.

## Layout

On a phone each screen is one column, at most 640 wide, with two tabs at the bottom: Home and Library. Settings opens from the header and takes the place of both.

The header holds the name and the way into Settings. Under the name it says what is going on, on every screen: downloading or converting, how many wait behind it, or that something is paused. With nothing going on it says nothing.

Home, with nothing fetched: the header, the frame, one button, the list of supported apps, and the strip of last saves along the bottom. The frame takes the room the rest leaves and is never flatter than 16 to 9. It is also the link field: tapping it lets the user type or edit a link. The button names the next step, so it reads Paste while the frame is empty and Fetch once it holds a link.

Home, with a post fetched: the poster runs from the top edge of the screen, in the shape of the picture. It is never flatter than 16 to 9, and never taller than 62% of the screen or than what leaves 300 for the controls under it. Under it sit where the post is from, its title, the choices and one Download button. While it downloads, the button gives way to a status line with Pause and Cancel, and the percentage stands on the poster. The close button on the poster empties the frame again.

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

The Arabic wording added with the remake was written by the agent and is his to correct, like the lines added in the fix pass. New: the Recent label (آخر التحميلات) and the two lines for a clipboard with no link (ماكو رابط منسوخ. and انسخ رابط المنشور أول.). The frame prompt and its hint are cut from lines the app already had.

The app locks to portrait (`flutter/lib/main.dart`). Whether tablets should rotate is his call.

Delete removes the copy Nazzil keeps and leaves the gallery copy. Whether Delete should remove both is his call.
