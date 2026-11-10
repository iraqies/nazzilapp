import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/media.dart';
import '../../state/nazzil_controller.dart';
import '../../theme/nazzil_theme.dart';
import '../widgets/heading.dart';
import '../widgets/nazzil_button.dart';
import '../widgets/paste_card.dart';
import '../widgets/photo_film.dart';
import '../widgets/quality_switch.dart';
import '../widgets/title_text.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});
  final NazzilController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.s;
    final media = controller.media;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Heading(s.tagline),
                const SizedBox(height: 10),
                Text(s.photoTagline, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                const SizedBox(height: 28),
                PasteCard(controller: controller, s: s),
                if (controller.clipOffer != null) ...[
                  const SizedBox(height: 12),
                  _ClipOffer(controller: controller, s: s),
                ],
                const SizedBox(height: 14),
                // With a result on screen the download button leads.
                NazzilButton(
                  label: controller.loading ? s.fetching : s.fetch,
                  busy: controller.loading,
                  secondary: media != null,
                  onPressed: controller.loading ? null : () => controller.fetch(),
                ),
                if (controller.loading)
                  Center(
                    child: TextButton(
                      onPressed: controller.cancelFetch,
                      child: Text(s.cancel),
                    ),
                  ),
                if (controller.error.isNotEmpty && media == null) ...[
                  const SizedBox(height: 12),
                  _ErrorLine(controller.error),
                ],
                if (media != null) ...[
                  const SizedBox(height: 28),
                  _Result(controller: controller, s: s, media: media),
                ] else ...[
                  const SizedBox(height: 28),
                  Text(s.how, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    // The icon marks it as an error where the picked colour is close to red.
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 2, end: 8),
            child: Icon(Icons.error_outline_rounded, size: 18, color: error),
          ),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: error))),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.controller,
    required this.s,
    required this.media,
  });

  final NazzilController controller;
  final S s;
  final MediaInfo media;

  @override
  Widget build(BuildContext context) {
    final photos = controller.selected?.kind == MediaKind.photo ||
        (media.isPhotoAlbum && controller.selected == null);
    final mixed = media.options.any((o) => o.label == 'Album');
    final job = controller.jobForCurrent();
    final downloading = job?.status == LibraryItem.statusDownloading;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final duration = media.duration;
    final facts = [
      s.platformName(media.platform),
      if (photos)
        mixed ? s.itemsN(media.photos.length) : s.photosN(media.photos.length)
      else if (duration != null && duration > 0)
        s.clock(duration),
    ].where((fact) => fact.isNotEmpty).join(' · ');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(NazzilRadius.card),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photos)
              PhotoFilm(
                key: ValueKey(media.id),
                urls: media.photos,
                index: controller.photoIndex,
                onChanged: controller.setPhotoIndex,
                s: s,
              )
            else
              _Poster(url: media.thumbnail),
            const SizedBox(height: 16),
            if (facts.isNotEmpty) ...[
              Text(facts, style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
            ],
            TitleText(media.title, style: theme.textTheme.headlineMedium),
            if (media.author != null) ...[
              const SizedBox(height: 4),
              TitleText(media.author!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 18),
            QualitySwitch(
              options: media.options,
              selected: controller.selected,
              onSelect: controller.select,
              s: s,
            ),
            const SizedBox(height: 16),
            NazzilButton(
              label: downloading
                  ? (controller.converting
                      ? s.converting
                      : '${s.downloading} ${(controller.progress * 100).round()}%')
                  : job?.status == LibraryItem.statusPaused
                      ? s.resume
                      : job?.status == LibraryItem.statusQueued
                          ? s.queued
                          : photos
                              ? (mixed ? s.saveAll : s.savePhotos)
                              : s.download,
              icon: job?.status == LibraryItem.statusPaused
                  ? Icons.play_arrow_rounded
                  : photos
                      ? Icons.photo_library_outlined
                      : Icons.download_rounded,
              busy: downloading,
              onPressed: job?.status == LibraryItem.statusPaused
                  ? () => controller.resumeJob(job!)
                  : job?.pending == true
                      ? null
                      : () => controller.download(),
            ),
            if (downloading) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(NazzilRadius.small),
                child: LinearProgressIndicator(value: controller.progress, minHeight: 6),
              ),
            ],
            if (job != null && job.active)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (downloading && !controller.converting)
                    TextButton(
                      onPressed: () => controller.pauseJob(job),
                      child: Text(s.pause),
                    ),
                  TextButton(
                    onPressed: () => controller.cancelJob(job),
                    child: Text(s.cancel),
                  ),
                ],
              ),
            if (photos) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: job?.active == true
                      ? null
                      : () => controller.download(onlyPhoto: controller.photoIndex),
                  child: Text(mixed ? s.saveThis : s.savePhoto),
                ),
              ),
            ],
            if (controller.error.isNotEmpty) ...[
              const SizedBox(height: 8),
              _ErrorLine(controller.error),
            ],
          ],
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Center(child: Icon(Icons.videocam_outlined, size: 42, color: scheme.onSurfaceVariant));
    return ClipRRect(
      borderRadius: BorderRadius.circular(NazzilRadius.control),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: ColoredBox(
          color: scheme.surfaceContainerHigh,
          child: url == null
              ? fallback
              : CachedNetworkImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => fallback,
                  errorWidget: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}

class _ClipOffer extends StatelessWidget {
  const _ClipOffer({required this.controller, required this.s});
  final NazzilController controller;
  final S s;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(NazzilRadius.control),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 2, 4),
        child: Row(
          children: [
            Icon(Icons.content_paste_go_rounded, color: scheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(s.clipOffer, style: theme.textTheme.bodyMedium)),
            TextButton(
              onPressed: controller.acceptClipOffer,
              child: Text(s.fetchThis),
            ),
            IconButton(
              tooltip: s.close,
              onPressed: controller.dismissClipOffer,
              icon: Icon(Icons.close_rounded, size: 18, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
