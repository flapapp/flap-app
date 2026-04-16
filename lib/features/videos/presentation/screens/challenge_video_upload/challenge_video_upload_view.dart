import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:flap_app/models/challenge.dart';
import 'package:flap_app/utils/i18n.dart';
import 'cvu_tokens.dart';

/// Phases for challenge-only upload UX.
enum CvuFlowPhase { draft, uploading, success, failed }

class ChallengeVideoUploadView extends StatefulWidget {
  const ChallengeVideoUploadView({
    super.key,
    required this.challenge,
    required this.flowPhase,
    required this.uploadProgress,
    required this.pickedFileLabel,
    required this.hasVideo,
    required this.clipTitleController,
    required this.errorMessage,
    required this.onBack,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onSubmit,
    required this.onRetryAfterFailure,
    required this.onClearError,
  });

  final Challenge? challenge;
  final CvuFlowPhase flowPhase;
  final double uploadProgress;
  final String? pickedFileLabel;
  final bool hasVideo;
  final TextEditingController clipTitleController;
  final String? errorMessage;
  final VoidCallback onBack;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onSubmit;
  final VoidCallback onRetryAfterFailure;
  final VoidCallback onClearError;

  @override
  State<ChallengeVideoUploadView> createState() => _ChallengeVideoUploadViewState();
}

class _ChallengeVideoUploadViewState extends State<ChallengeVideoUploadView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  bool _briefingOpen = true;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(ChallengeVideoUploadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flowPhase != CvuFlowPhase.draft) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final c = widget.challenge;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: CvuTokens.bg0,
      ),
      child: Scaffold(
        backgroundColor: CvuTokens.bg0,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _BackdropMesh(),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(onBack: widget.onBack),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 420),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _buildMainPanel(context, mq, c),
                    ),
                  ),
                  _BottomActionBar(
                    phase: widget.flowPhase,
                    hasVideo: widget.hasVideo,
                    uploadProgress: widget.uploadProgress,
                    onSubmit: widget.onSubmit,
                  ),
                ],
              ),
            ),
            if (widget.flowPhase == CvuFlowPhase.success) _SuccessVeil(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainPanel(BuildContext context, MediaQueryData mq, Challenge? c) {
    switch (widget.flowPhase) {
      case CvuFlowPhase.uploading:
        return KeyedSubtree(
          key: const ValueKey('up'),
          child: _UploadingPane(progress: widget.uploadProgress),
        );
      case CvuFlowPhase.success:
        return KeyedSubtree(
          key: const ValueKey('ok'),
          child: const SizedBox.shrink(),
        );
      case CvuFlowPhase.failed:
        return KeyedSubtree(
          key: const ValueKey('fail'),
          child: _FailurePane(
            message: widget.errorMessage ??
                I18n.inline('Щось пішло не так', 'Something went wrong'),
            onRetry: widget.onRetryAfterFailure,
          ),
        );
      case CvuFlowPhase.draft:
        return KeyedSubtree(
          key: const ValueKey('draft'),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, 0, 20, mq.padding.bottom + 100),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroBlock(challenge: c),
                    const SizedBox(height: 22),
                    _StepRail(
                      step: widget.hasVideo ? 3 : 1,
                    ),
                    const SizedBox(height: 22),
                    _StageCard(
                      pulse: _pulse,
                      hasVideo: widget.hasVideo,
                      pickedLabel: widget.pickedFileLabel,
                      onGallery: widget.onPickGallery,
                      onCamera: widget.onPickCamera,
                    ),
                    if (widget.errorMessage != null && widget.errorMessage!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _InlineError(
                        message: widget.errorMessage!,
                        onDismiss: widget.onClearError,
                      ),
                    ],
                    const SizedBox(height: 18),
                    _BriefingPanel(
                      challenge: c,
                      expanded: _briefingOpen,
                      onToggle: () => setState(() => _briefingOpen = !_briefingOpen),
                    ),
                    const SizedBox(height: 16),
                    _OptionalClipTitleField(controller: widget.clipTitleController),
                  ],
                ),
              ),
            ),
          ),
        );
    }
  }
}

class _BackdropMesh extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF05070A),
                CvuTokens.bg1,
                Color(0xFF060810),
              ],
            ),
          ),
        ),
        Positioned(
          top: -100,
          right: -80,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    CvuTokens.accent.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: -60,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    CvuTokens.accentDeep.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: CvuTokens.text, size: 20),
          ),
          Expanded(
            child: Text(
              I18n.inline('Подача відео', 'Video entry'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CvuTokens.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _HeroBlock extends StatelessWidget {
  const _HeroBlock({required this.challenge});

  final Challenge? challenge;

  @override
  Widget build(BuildContext context) {
    final title = challenge?.title.trim().isNotEmpty == true
        ? challenge!.title
        : I18n.inline('Челендж', 'Challenge');
    final deadline = challenge?.submissionDeadline;
    final urgency = deadline != null ? _urgencyLabel(deadline) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (urgency != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: CvuTokens.accent.withValues(alpha: 0.35)),
              color: CvuTokens.accent.withValues(alpha: 0.08),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule_rounded, size: 15, color: CvuTokens.accent.withValues(alpha: 0.95)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    urgency,
                    style: const TextStyle(
                      color: CvuTokens.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (urgency != null) const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            color: CvuTokens.text,
            fontSize: 30,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          I18n.inline(
            'Покажіть свій найкращий момент. Одне відео — ваша заявка.',
            'Show your best moment. One clip is your entry.',
          ),
          style: const TextStyle(
            color: CvuTokens.muted,
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  String _urgencyLabel(DateTime deadline) {
    final now = DateTime.now();
    if (deadline.isBefore(now)) {
      return I18n.inline('Дедлайн минув', 'Deadline passed');
    }
    final diff = deadline.difference(now);
    if (diff.inDays >= 1) {
      return I18n.inline(
        'Залишилось ${diff.inDays} дн.',
        '${diff.inDays}d left to submit',
      );
    }
    if (diff.inHours >= 1) {
      return I18n.inline(
        'Залишилось ${diff.inHours} год.',
        '${diff.inHours}h left to submit',
      );
    }
    final m = diff.inMinutes.clamp(1, 59);
    return I18n.inline(
      'Залишилось $m хв.',
      '$m min left',
    );
  }
}

class _StepRail extends StatelessWidget {
  const _StepRail({required this.step});

  /// 1 = preparing, 2 = clip ready, 3 = ready to send (has video).
  final int step;

  @override
  Widget build(BuildContext context) {
    final steps = [
      I18n.inline('Підготуйтесь', 'Prepare'),
      I18n.inline('Кліп', 'Clip'),
      I18n.inline('Надіслати', 'Send'),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepDot(label: steps[0], index: 1, active: step >= 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 17),
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: step >= 2
                      ? [CvuTokens.accent, CvuTokens.accent.withValues(alpha: 0.25)]
                      : [CvuTokens.stroke, CvuTokens.stroke],
                ),
              ),
            ),
          ),
        ),
        _StepDot(label: steps[1], index: 2, active: step >= 2),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 17),
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: step >= 3
                      ? [CvuTokens.accent, CvuTokens.accent.withValues(alpha: 0.25)]
                      : [CvuTokens.stroke, CvuTokens.stroke],
                ),
              ),
            ),
          ),
        ),
        _StepDot(label: steps[2], index: 3, active: step >= 3),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.label,
    required this.index,
    required this.active,
  });

  final String label;
  final int index;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? CvuTokens.accent.withValues(alpha: 0.15) : CvuTokens.surface,
            border: Border.all(
              color: active ? CvuTokens.accent : CvuTokens.stroke,
              width: active ? 2 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: CvuTokens.accent.withValues(alpha: 0.25),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Text(
            '$index',
            style: TextStyle(
              color: active ? CvuTokens.accent : CvuTokens.muted,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 72,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: active ? CvuTokens.text : CvuTokens.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.pulse,
    required this.hasVideo,
    required this.pickedLabel,
    required this.onGallery,
    required this.onCamera,
  });

  final AnimationController pulse;
  final bool hasVideo;
  final String? pickedLabel;
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final t = hasVideo ? 0.0 : pulse.value;
        final glow = 0.06 + t * 0.08;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: CvuTokens.accent.withValues(alpha: glow),
                blurRadius: 28 + t * 12,
                spreadRadius: -4,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: CvuTokens.surface.withValues(alpha: 0.94),
          border: Border.all(
            color: hasVideo ? CvuTokens.accent.withValues(alpha: 0.45) : CvuTokens.stroke,
            width: hasVideo ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  hasVideo ? Icons.movie_rounded : Icons.touch_app_rounded,
                  color: hasVideo ? CvuTokens.accent : CvuTokens.muted,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasVideo
                        ? I18n.inline('Кліп обрано', 'Clip locked in')
                        : I18n.inline('Ваша сцена', 'Your stage'),
                    style: const TextStyle(
                      color: CvuTokens.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              hasVideo
                  ? (pickedLabel ?? '')
                  : I18n.inline(
                      'MP4 · до 10 с · до 25 МБ',
                      'MP4 · up to 10s · up to 25 MB',
                    ),
              style: TextStyle(
                color: hasVideo ? CvuTokens.muted : CvuTokens.muted.withValues(alpha: 0.85),
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _SourceChip(
                    icon: Icons.photo_library_outlined,
                    label: I18n.inline('Галерея', 'Gallery'),
                    onTap: onGallery,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceChip(
                    icon: Icons.videocam_outlined,
                    label: I18n.inline('Камера', 'Camera'),
                    emphasized: true,
                    onTap: onCamera,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: emphasized ? CvuTokens.accent.withValues(alpha: 0.14) : CvuTokens.surfaceLift,
            border: Border.all(
              color: emphasized ? CvuTokens.accent.withValues(alpha: 0.4) : CvuTokens.stroke,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: emphasized ? CvuTokens.accent : CvuTokens.text, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: emphasized ? CvuTokens.accent : CvuTokens.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BriefingPanel extends StatelessWidget {
  const _BriefingPanel({
    required this.challenge,
    required this.expanded,
    required this.onToggle,
  });

  final Challenge? challenge;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final desc = challenge?.description.trim().isNotEmpty == true
        ? challenge!.description
        : I18n.inline(
            'Дотримуйтесь духу челенджу та правил платформи.',
            'Follow the challenge spirit and platform rules.',
          );
    final df = DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag());
    final line = challenge != null
        ? I18n.inline(
            'Подання до ${df.format(challenge!.submissionDeadline.toLocal())} · вхід ${challenge!.entryFee.toStringAsFixed(0)}',
            'Submit by ${df.format(challenge!.submissionDeadline.toLocal())} · entry ${challenge!.entryFee.toStringAsFixed(0)}',
          )
        : '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: CvuTokens.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CvuTokens.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.article_outlined, color: CvuTokens.muted, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      I18n.inline('Бриф і контекст', 'Brief & context'),
                      style: const TextStyle(
                        color: CvuTokens.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(Icons.expand_more_rounded, color: CvuTokens.muted),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: CvuTokens.stroke),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (line.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        line,
                        style: const TextStyle(color: CvuTokens.accent, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  Text(
                    desc,
                    style: const TextStyle(
                      color: CvuTokens.muted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _RuleChip(text: I18n.inline('10 с макс.', '10s max')),
                      _RuleChip(text: I18n.inline('25 МБ', '25 MB')),
                      _RuleChip(text: 'MP4'),
                      _RuleChip(text: I18n.inline('Один кліп', 'One clip')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: CvuTokens.surfaceLift,
        border: Border.all(color: CvuTokens.stroke),
      ),
      child: Text(
        text,
        style: const TextStyle(color: CvuTokens.text, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _OptionalClipTitleField extends StatelessWidget {
  const _OptionalClipTitleField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          I18n.inline('Назва кліпу (необовʼязково)', 'Clip title (optional)'),
          style: const TextStyle(
            color: CvuTokens.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: CvuTokens.text, fontSize: 15),
          cursorColor: CvuTokens.accent,
          decoration: InputDecoration(
            filled: true,
            fillColor: CvuTokens.surfaceLift,
            hintText: I18n.inline('Як назвемо ваш момент?', 'Name this moment'),
            hintStyle: TextStyle(color: CvuTokens.muted.withValues(alpha: 0.65)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: CvuTokens.stroke),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: CvuTokens.stroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: CvuTokens.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: CvuTokens.surfaceLift,
        border: Border.all(color: CvuTokens.stroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: CvuTokens.muted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: CvuTokens.text, fontSize: 13, height: 1.35),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, color: CvuTokens.muted, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

class _UploadingPane extends StatelessWidget {
  const _UploadingPane({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final stage = progress < 0.25
        ? I18n.inline('Підготовка…', 'Preparing…')
        : progress < 0.92
            ? I18n.inline('Відправка…', 'Sending…')
            : I18n.inline('Збереження…', 'Saving…');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 280),
                builder: (context, value, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: value,
                          strokeWidth: 5,
                          backgroundColor: CvuTokens.stroke,
                          color: CvuTokens.accent,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Text(
                        '${(value * 100).clamp(0, 100).toInt()}%',
                        style: const TextStyle(
                          color: CvuTokens.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 28),
            Text(
              stage,
              style: const TextStyle(
                color: CvuTokens.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              I18n.inline('Тримайте застосунок відкритим', 'Keep the app open'),
              textAlign: TextAlign.center,
              style: TextStyle(color: CvuTokens.muted.withValues(alpha: 0.9), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailurePane extends StatelessWidget {
  const _FailurePane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 56, color: CvuTokens.muted),
            const SizedBox(height: 18),
            Text(
              I18n.inline('Не вдалося надіслати', 'Couldn’t send'),
              style: const TextStyle(
                color: CvuTokens.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: CvuTokens.muted, height: 1.45),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: onRetry,
              child: Text(
                I18n.inline('Спробувати знову', 'Try again'),
                style: const TextStyle(
                  color: CvuTokens.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.phase,
    required this.hasVideo,
    required this.uploadProgress,
    required this.onSubmit,
  });

  final CvuFlowPhase phase;
  final bool hasVideo;
  final double uploadProgress;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final show = phase == CvuFlowPhase.draft;
    if (!show) {
      return SizedBox(height: mq.padding.bottom);
    }

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, mq.padding.bottom + 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            CvuTokens.bg0.withValues(alpha: 0),
            CvuTokens.bg0.withValues(alpha: 0.92),
            CvuTokens.bg0,
          ],
        ),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: hasVideo ? 1.0 : 0.65),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        builder: (context, emphasis, _) {
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Color.lerp(CvuTokens.surface, CvuTokens.accentDeep, emphasis * 0.35)!,
                  Color.lerp(CvuTokens.surfaceLift, CvuTokens.accent, emphasis * 0.45)!,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: CvuTokens.accent.withValues(alpha: 0.22 * emphasis),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: hasVideo ? onSubmit : null,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.rocket_launch_rounded,
                        color: hasVideo ? Colors.white : Colors.white.withValues(alpha: 0.35),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        hasVideo
                            ? I18n.inline('Надіслати виклик', 'Submit entry')
                            : I18n.inline('Оберіть кліп', 'Pick a clip first'),
                        style: TextStyle(
                          color: hasVideo ? Colors.white : Colors.white.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SuccessVeil extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Container(
            color: CvuTokens.bg0.withValues(alpha: 0.88),
            child: Center(
              child: Transform.scale(
                scale: 0.85 + 0.15 * t,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CvuTokens.accent.withValues(alpha: 0.15),
                        border: Border.all(color: CvuTokens.accent.withValues(alpha: 0.5), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: CvuTokens.accent.withValues(alpha: 0.35),
                            blurRadius: 32,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check_rounded, color: CvuTokens.accent, size: 48),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      I18n.inline('У системі!', 'You’re in!'),
                      style: const TextStyle(
                        color: CvuTokens.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      I18n.inline('Ваш кліп прийнято', 'Your clip is locked in'),
                      style: TextStyle(color: CvuTokens.muted.withValues(alpha: 0.95), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
