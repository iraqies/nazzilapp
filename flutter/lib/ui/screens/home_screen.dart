import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/media.dart';
import '../../state/nazzil_controller.dart';
import '../../theme/nazzil_theme.dart';
import '../widgets/nazzil_button.dart';
import '../widgets/paste_card.dart';
import '../widgets/photo_film.dart';
import '../widgets/platform_pills.dart';
import '../widgets/quality_switch.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});
  final NazzilController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.s;
    final media = controller.media;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.tagline, style: displayStyle(context, size: 42)),
                const SizedBox(height: 10),
                Text(
                  s.photoTagline,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 28),
                PasteCard(controller: controller, s: s),
                if (controller.clipOffer != null) ...[
                  const SizedBox(height: 12),
                  _ClipOffer(controller: controller, s: s),
                ],
                const SizedBox(height: 14),
                NazzilButton(
                  label: controller.loading ? s.fetching : s.fetch,
                  icon: Icons.arrow_outward_rounded,
                  busy: controller.loading,
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
                  Text(
                    controller.error,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 18),
                const PlatformPills(),
                if (media != null) ...[
                  const SizedBox(height: 28),
                  _Result(controller: controller, s: s, media: media),
                ] else ...[
                  const SizedBox(height: 36),
                  _How(s: s),
                ],
              ],
            ),
          ),
        ),
      ],
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
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: photos
              ? NazzilColors.lilac.withValues(alpha: 0.4)
              : NazzilColors.rose.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
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
              _Poster(url: media.thumbnail, platform: media.platform, s: s),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Badge(
                  label: s.platformName(media.platform),
                  color: NazzilColors.rose,
                ),
                if (photos)
                  _Badge(
                    label: mixed ? s.itemsN(media.photos.length) : s.photosN(media.photos.length),
                    color: NazzilColors.lilac,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(media.title, style: Theme.of(context).textTheme.headlineMedium),
            if (media.author != null) ...[
              const SizedBox(height: 4),
              Text(media.author!, style: Theme.of(context).textTheme.bodySmall),
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
              label: job?.status == LibraryItem.statusDownloading
                  ? s.downloading
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
              tint: photos ? NazzilColors.lilac : NazzilColors.rose,
              busy: job?.status == LibraryItem.statusDownloading,
              progress: job?.status == LibraryItem.statusDownloading ? controller.progress : null,
              onPressed: job?.status == LibraryItem.statusPaused
                  ? () => controller.resumeJob(job!)
                  : job?.pending == true
                      ? null
                      : () => controller.download(),
            ),
            if (job != null && job.active)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (job.status == LibraryItem.statusDownloading)
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
              Text(controller.error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({
    required this.url,
    required this.platform,
    required this.s,
  });
  final String? url;
  final PlatformId platform;
  final S s;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Theme.of(context).colorScheme.surfaceContainer),
            if (url != null)
              CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover)
            else
              const Center(child: Icon(Icons.videocam_outlined, size: 42, color: NazzilColors.rose)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x88000000)],
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: _Badge(label: s.platformName(platform), color: NazzilColors.rose),
            ),
          ],
        ),
      ),
    );
  }
}

class _How extends StatelessWidget {
  const _How({required this.s});
  final S s;

  @override
  Widget build(BuildContext context) {
    final steps = [s.step1, s.step2, s.step3];
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.howTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: scheme.outline),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [NazzilColors.rose, NazzilColors.roseDeep],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: NazzilColors.rose.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(steps[i], style: Theme.of(context).textTheme.bodyMedium)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ClipOffer extends StatelessWidget {
  const _ClipOffer({required this.controller, required this.s});
  final NazzilController controller;
  final S s;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NazzilColors.rose.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: NazzilColors.rose.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            const Icon(Icons.content_paste_go_rounded, color: NazzilColors.rose, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(s.clipOffer, style: Theme.of(context).textTheme.bodyMedium),
            ),
            TextButton(
              onPressed: controller.acceptClipOffer,
              child: Text(s.fetchThis),
            ),
            IconButton(
              onPressed: controller.dismissClipOffer,
              icon: Icon(Icons.close_rounded, size: 18, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
