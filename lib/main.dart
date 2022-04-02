import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shoplist/controllers/auth_controller.dart';
import 'package:shoplist/controllers/item_list_controller.dart';
import 'package:shoplist/custom_exception.dart';
import 'package:shoplist/firebase_options.dart';

import 'models/item.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shopping List',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends HookConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(authControllerProvider.notifier);
    final user = ref.watch(authControllerProvider);
    final itemListFilter = ref.watch(itemListFilterProvider);
    final isObtainedFilter = itemListFilter == ItemListFilter.obtained;

    ref.listen<CustomException?>(
      itemListExceptionProvider,
      (previous, next) {
        if (next != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(next.message ?? 'Error'),
            ),
          );
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Shopping List'),
        leading: user != null
            ? IconButton(
                onPressed: controller.signOut,
                icon: const Icon(Icons.logout),
              )
            : null,
        actions: [
          IconButton(
            onPressed: () {
              ref.read(itemListFilterProvider.notifier).state = isObtainedFilter
                  ? ItemListFilter.all
                  : ItemListFilter.obtained;
            },
            icon: Icon(
              isObtainedFilter
                  ? Icons.check_circle
                  : Icons.check_circle_outline,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => AddItemDialog.show(context, Item.empty()),
        child: const Icon(Icons.add),
      ),
      body: const ItemList(),
    );
  }
}

class AddItemDialog extends HookConsumerWidget {
  const AddItemDialog({
    Key? key,
    required this.item,
  }) : super(key: key);

  final Item item;

  static void show(BuildContext context, Item item) {
    showDialog(
      context: context,
      builder: (context) => AddItemDialog(item: item),
    );
  }

  bool get isUpdating => item.id != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textController = useTextEditingController(text: item.name);
    final controller = ref.read(itemListControllerProvider.notifier);

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Item name'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  primary: isUpdating
                      ? Colors.orange
                      : Theme.of(context).primaryColor,
                ),
                onPressed: () {
                  isUpdating
                      ? controller.updateItem(
                          updatedItem: item.copyWith(
                            name: textController.text.trim(),
                            obtained: item.obtained,
                          ),
                        )
                      : controller.addItem(
                          name: textController.text.trim(),
                        );

                  Navigator.pop(context);
                },
                child: Text(isUpdating ? 'Update' : 'Add'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final currentItem = Provider<Item>((_) => throw UnimplementedError());

class ItemList extends HookConsumerWidget {
  const ItemList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemList = ref.watch(itemListControllerProvider);
    final filteredItemList = ref.watch(filteredItemListProvider);

    return itemList.when(
      data: (items) => items.isEmpty
          ? const Center(
              child: Text(
                'Tap + to add an item',
                style: TextStyle(fontSize: 20),
              ),
            )
          : ListView.builder(
              itemCount: filteredItemList.length,
              itemBuilder: (context, index) {
                final item = filteredItemList[index];

                return ProviderScope(
                  overrides: [currentItem.overrideWithValue(item)],
                  child: const ItemTile(),
                );
              },
            ),
      error: (error, _) => ItemListError(
        message:
            error is CustomException ? error.message! : 'Something went wrong',
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class ItemListError extends HookConsumerWidget {
  const ItemListError({
    Key? key,
    required this.message,
  }) : super(key: key);

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(itemListControllerProvider.notifier);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          message,
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            controller.retrieveItems(isRefreshing: true);
          },
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

class ItemTile extends HookConsumerWidget {
  const ItemTile({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(itemListControllerProvider.notifier);
    final item = ref.watch(currentItem);

    return ListTile(
      key: ValueKey(item.id),
      title: Text(item.name),
      trailing: Checkbox(
        value: item.obtained,
        onChanged: (val) {
          controller.updateItem(
            updatedItem: item.copyWith(obtained: !item.obtained),
          );
        },
      ),
      onTap: () => AddItemDialog.show(context, item),
      onLongPress: () {
        if (item.id != null) {
          controller.deleteItem(itemId: item.id!);
        }
      },
    );
  }
}
