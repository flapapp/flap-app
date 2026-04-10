import 'package:equatable/equatable.dart';

import '../../domain/entities/library_video.dart';

sealed class VideosEvent extends Equatable {
  const VideosEvent();

  @override
  List<Object?> get props => [];
}

final class VideosFeedListenRequested extends VideosEvent {
  const VideosFeedListenRequested({
    this.forUserId,
    this.limit = 400,
  });

  final String? forUserId;
  final int limit;

  @override
  List<Object?> get props => [forUserId, limit];
}

final class VideosFeedUpdated extends VideosEvent {
  const VideosFeedUpdated(this.videos);

  final List<LibraryVideo> videos;

  @override
  List<Object?> get props => [videos];
}

final class VideosFeedFailed extends VideosEvent {
  const VideosFeedFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
