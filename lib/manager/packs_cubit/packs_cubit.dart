import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:sporcle/models/question_pack.dart';
import 'package:sporcle/services/api_service.dart';

part 'packs_state.dart';

class PacksCubit extends Cubit<PacksState> {
  PacksCubit({ApiService? apiService})
    : _apiService = apiService ?? ApiService(),
      super(PacksInitial());

  final ApiService _apiService;

  Future<void> getPacks() async {
    emit(PacksLoading());

    try {
      final response = await _apiService.getPacks();
      emit(
        PacksSuccess(
          packs: response.packs,
          count: response.count,
          openRooms: response.openRooms,
        ),
      );
    } catch (error) {
      emit(PacksFailure(error.toString()));
    }
  }
}
