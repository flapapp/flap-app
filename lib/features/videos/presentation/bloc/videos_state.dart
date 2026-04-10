import 'package:equatable/equatable.dart';

import '../../domain/entities/library_video.dart';

sealed class VideosState extends Equatable {
  const VideosState();

  @override
  List<Object?> get props => [];
}

final class VideosInitial extends VideosState {
  const VideosInitial();
}

final class VideosFeedLoading extends VideosState {
  const VideosFeedLoading();
}

final class VideosFeedReady extends VideosState {
  const VideosFeedReady(this.videos);

  final List<LibraryVideo> videos;

  @override
  List<Object?> get props => [videos];
}

final class VideosFeedError extends VideosState {
  const VideosFeedError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
