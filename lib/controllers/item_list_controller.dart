import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shoplist/controllers/auth_controller.dart';
import 'package:shoplist/custom_exception.dart';
import 'package:shoplist/models/item.dart';
import 'package:shoplist/repositories/item_repository.dart';

enum ItemListFilter {
  all,
  obtained,
}

final itemListFilterProvider =
    StateProvider<ItemListFilter>((_) => ItemListFilter.all);

final filteredItemListProvider = StateProvider<List<Item>>((ref) {
  final itemListFilter = ref.watch(itemListFilterProvider);
  final itemList = ref.watch(itemListControllerProvider);

  return itemList.maybeWhen(
    data: (items) {
      switch (itemListFilter) {
        case ItemListFilter.obtained:
          return items.where((item) => item.obtained).toList();
        default:
          return items;
      }
    },
    orElse: () => [],
  );
});

final itemListExceptionProvider = StateProvider<CustomException?>((_) => null);

final itemListControllerProvider =
    StateNotifierProvider<ItemListController, AsyncValue<List<Item>>>(
  (ref) {
    final user = ref.watch(authControllerProvider);
    return ItemListController(ref.read, user?.uid)..retrieveItems();
  },
);

class ItemListController extends StateNotifier<AsyncValue<List<Item>>> {
  ItemListController(this._read, this._userId)
      : super(const AsyncValue.loading());

  final Reader _read;
  final String? _userId;

  Future<void> retrieveItems({bool isRefreshing = false}) async {
    if (isRefreshing) state = const AsyncValue.loading();

    try {
      if (_userId != null) {
        final items =
            await _read(itemRepositoryProvider).retrieveItems(userId: _userId!);

        if (mounted) {
          state = AsyncValue.data(items);
        }
      }
    } on CustomException catch (e, st) {
      state = AsyncValue.error(e, stackTrace: st);
    }
  }

  Future<void> addItem({required String name, bool obtained = false}) async {
    try {
      if (_userId != null) {
        final item = Item(name: name, obtained: obtained);

        final itemId = await _read(itemRepositoryProvider).createItem(
          userId: _userId!,
          item: item,
        );

        state.whenData(
          (items) => state = AsyncValue.data(
            items..add(item.copyWith(id: itemId)),
          ),
        );
      }
    } on CustomException catch (e) {
      _read(itemListExceptionProvider.notifier).state = e;
    }
  }

  Future<void> updateItem({required Item updatedItem}) async {
    try {
      if (_userId != null) {
        await _read(itemRepositoryProvider).updateItem(
          userId: _userId!,
          item: updatedItem,
        );

        state.whenData(
          (items) => state = AsyncValue.data([
            for (final item in items)
              if (item.id == updatedItem.id) updatedItem else item
          ]),
        );
      }
    } on CustomException catch (e) {
      _read(itemListExceptionProvider.notifier).state = e;
    }
  }

  Future<void> deleteItem({required String itemId}) async {
    try {
      if (_userId != null) {
        await _read(itemRepositoryProvider).deleteItem(
          userId: _userId!,
          itemId: itemId,
        );

        state.whenData(
          (items) => state = AsyncValue.data(
            items..removeWhere((item) => item.id == itemId),
          ),
        );
      }
    } on CustomException catch (e) {
      _read(itemListExceptionProvider.notifier).state = e;
    }
  }
}
