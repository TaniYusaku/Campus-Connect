import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_connect_app/models/user.dart';
import 'package:campus_connect_app/repositories/encounter_repository.dart';

// 状態の定義
class EncounterState {
  final List<User> encounters;
  final bool isLoading;
  final String? errorMessage;

  EncounterState({
    this.encounters = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  EncounterState copyWith({
    List<User>? encounters,
    bool? isLoading,
    String? errorMessage,
  }) {
    return EncounterState(
      encounters: encounters ?? this.encounters,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// Notifierの定義
class EncounterNotifier extends StateNotifier<EncounterState> {
  final EncounterRepository _repository;

  EncounterNotifier(this._repository) : super(EncounterState()) {
    fetchEncounters();
  }

  Future<void> fetchEncounters() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final encounters = await _repository.getEncounters();
      state = state.copyWith(encounters: encounters, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void addNewEncounter(User user) {
    // 重複をチェック
    if (!state.encounters.any((element) => element.id == user.id)) {
        state = state.copyWith(encounters: [user, ...state.encounters]);
    }
  }
}

// Providerの定義
final encounterProvider = StateNotifierProvider<EncounterNotifier, EncounterState>((ref) {
  final repository = ref.watch(encounterRepositoryProvider);
  return EncounterNotifier(repository);
});
