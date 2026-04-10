import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/library_video.dart';
import '../../domain/usecases/watch_library_videos.dart';
import 'videos_event.dart';
import 'videos_state.dart';

class VideosBloc extends Bloc<VideosEvent, VideosState> {
  VideosBloc(this._watchLibraryVideos) : super(const VideosInitial()) {
    on<VideosFeedListenRequested>(_onListenRequested);
    on<VideosFeedUpdated>(_onUpdated);
    on<VideosFeedFailed>(_onFailed);
  }

  final WatchLibraryVideos _watchLibraryVideos;
  StreamSubscription<List<LibraryVideo>>? _subscription;

  Future<void> _onListenRequested(
    VideosFeedListenRequested event,
    Emitter<VideosState> emit,
  ) async {
    await _subscription?.cancel();
    emit(const VideosFeedLoading());
    _subscription = _watchLibraryVideos(
      forUserId: event.forUserId,
      limit: event.limit,
    ).listen(
      (videos) => add(VideosFeedUpdated(videos)),
      onError: (Object e) => add(VideosFeedFailed(e.toString())),
    );
  }

  void _onUpdated(VideosFeedUpdated event, Emitter<VideosState> emit) {
    emit(VideosFeedReady(event.videos));
  }

  void _onFailed(VideosFeedFailed event, Emitter<VideosState> emit) {
    emit(VideosFeedError(event.message));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
