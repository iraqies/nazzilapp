# Nazzil design direction

Status: interim. This describes the app as it stands after antislop audit 001. It holds until the owner picks a direction for the remake, and that direction replaces this file.

It covers the Flutter app in `flutter/`.

## Design read

Reading this as: a personal media saver for Iraqi phone users, phone first and desktop second, in a one loud colour on plain neutrals style, dial ENERGY 2 / RHYTHM 1 / MOTION 2.

Dial: ENERGY 2 / RHYTHM 1 / MOTION 2

ENERGY 2: a heavy headline and one saturated colour greet the user, and everything around them stays plain.

RHYTHM 1: it is a tool, and every screen is a single column. Home runs in the order of the job: paste, fetch, pick, download.

MOTION 2: screens, sheets and album photos slide, and confetti marks a finished download. Nothing moves unless the user did something or a download ended, and all of it switches off with the system reduce motion setting.

## Identity

Nazzil, نزّل, is Arabic for "download", said as a command. The app keeps that tone.

The voice is the identity motif. The headline is two short sentences, "Download the video. Keep it." and "نزّل الفيديو. خليه عندك." Buttons are one-word commands in Iraqi dialect: جيب, نزّل, كمّل, وقّف, سكّر. Statuses are one or two words. The Arabic is Iraqi, not formal Arabic, because the app is made for people who talk that way.

The mark is the letter N on a tile in the picked colour. It was in the app before the audit and only lost its gradient and glow. No other logo exists and none was drawn.

## Colour

The user picks one colour out of five: Rose `#FF4D8D` (the default), Ocean `#2F7BFF`, Emerald `#12B886`, Sunset `#FF7139`, Grape `#8B5CF6`. The five were in the app before the audit and stay, because the colour is the one thing a user can make their own.

As a fill, the colour goes on the main action of the screen and its progress bar, on the choice that is picked, and on the mark. That is the accent. On Home the fill moves from Fetch to Download once a result is showing, so one button leads at a time.

As text and icons (Paste, Clear, links, the status line while something is running) the colour uses a lighter or darker shade of the same hue per theme, tuned to pass 4.5:1.

Text on a colour fill is ink `#0B0B0C`, never white. White failed on all five colours (2.55 to 4.23 against the 4.5 needed) and ink passes on all five.

Everything else is neutral. Dark theme: page `#0B0B0C`, surfaces `#161618` and `#222225`, text `#F4F1EC`, muted text `#A9A5A0`. Light theme: page `#F5F3F0`, surfaces white and `#ECE9E4`, text `#141215`, muted text `#625D58`. The neutrals carry no tint of the picked colour, so covers and thumbnails, which are other people's pictures, are the only other colour on screen.

Red is for errors and for Delete: `#FF7A85` on dark, `#B3202C` on light. An error line also carries an icon, because Rose and Sunset sit close to red.

## Type

Outfit sets all Latin text, in both languages. It was the app's typeface before the audit. It stays because its heavy weights carry the headline, and one variable file holds every weight the app uses.

Noto Naskh Arabic sets Arabic. Outfit has no Arabic letters, so Arabic falls through to it, while a Latin title inside the Arabic app still shows in Outfit. Naskh is the usual hand for Arabic reading text. Its weights stop at bold, so the Arabic headline is bold at 34 where the English one is extra bold at 40. Arabic lines are set 0.2 taller for the marks above and below the letters, and letter spacing is always zero in Arabic because spacing breaks the joins.

The scale: headline 40 (34 in Arabic), result title 26, title 20, tile title 16, body 16 and 15, small 13. Sizes follow the system font size. The headline follows it up to 1.3 times, since it is already large.

## Shape, surface and spacing

Corners come in three sizes: 6 for tags on a cover, 10 for controls, 16 for cards, sheets and dialogs. The full pill is kept for the main button, so it reads as the one thing to press.

Surfaces are flat. There are no shadows, gradients or glow, and a 1 px outline separates a card from the page. The earlier gradient backdrop and the glow in four places had no written purpose, and flat surfaces leave the colour fill as the loudest thing on screen.

Spacing is 22 at the screen edge, 28 between groups and 8 to 16 inside a group. Space does the separating. The only divider line stands between the two panes of a wide window.

Anything tappable is at least 48 high.

## Layout

On a phone each screen is one column, at most 640 wide, with two tabs at the bottom: Home and Library. Settings opens from the header and takes the place of both.

In a window 960 wide or more, the link pane (460 wide) and the library sit side by side and the tabs go away, since there is room for both.

The library is a grid of covers. The column count follows the width, from two on a phone upward, with tiles no wider than 220. The cover gets the space because the picture is how people recognise a download. The title sits under it and small tags sit on it.

Cards mark things the user handles as a unit: the link box, a fetched result, a library item. Settings has no cards, only headings and controls.

## Icons

Material icons, the outlined and rounded sets that ship with Flutter. Every icon either sits beside its word or carries a tooltip and a screen reader name. Each one names its own thing: HD, SD, photo, video, audio, paste, download, share, delete, settings. None is decoration.

## Motion

Screens, sheets and dialogs use Flutter's own transitions, which show where a screen came from. Album photos glide for 280 ms when turned by button or key.

Confetti is the one celebration. It runs once, for 2.2 seconds, in the done dialog when a download lands, because the finished download is the moment the app exists for. It fades out fully and is skipped under reduce motion. It was in the app before the audit. If the owner wants it gone, it is one widget to remove.

## Themes

Dark, light, or follow the system, which is the default. The tests in `flutter/test/` measure text contrast in both.

## Open to the owner

The Arabic wording added in this pass (error messages, empty states, the new buttons) was written by the agent and is his to correct.

The app locks to portrait (`flutter/lib/main.dart`). Whether tablets should rotate is his call.
