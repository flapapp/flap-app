import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum MatchStatus {
  open,
  full,
  inProgress,
  finished,
  cancelled,
}

@JsonEnum()
enum MatchLevel {
  beginner,
  intermediate,
  advanced,
  professional,
}

@JsonEnum()
enum MatchResult {
  teamAWins,
  teamBWins,
  draw,
}
