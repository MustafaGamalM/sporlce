part of 'packs_cubit.dart';

@immutable
sealed class PacksState {}

final class PacksInitial extends PacksState {}

final class PacksLoading extends PacksState {}

final class PacksSuccess extends PacksState {
  PacksSuccess({
    required this.packs,
    required this.count,
    required this.openRooms,
  });

  final List<QuestionPack> packs;
  final int count;
  final int openRooms;
}

final class PacksFailure extends PacksState {
  PacksFailure(this.message);

  final String message;
}
