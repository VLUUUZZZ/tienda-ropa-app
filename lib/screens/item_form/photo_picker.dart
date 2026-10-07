import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/clothing_repository.dart';
import '../../widgets/snackbars.dart';

/// A tappable square showing the garment's photo, if it has one, or a
/// placeholder to add one. Saves straight to [ClothingRepository] the moment
/// a photo is picked or removed — independent of the rest of the form's
/// save/discard flow, like the quick stock shortcuts elsewhere in the app.
///
/// The photo stays on this phone only: it's never part of [ClothingItem] and
/// never synced, since that needs a file storage backend (Firebase Storage)
/// this app doesn't use yet.
class ItemPhotoPicker extends StatefulWidget {
  const ItemPhotoPicker({super.key, required this.repo, required this.itemId});

  final ClothingRepository repo;
  final String itemId;

  @override
  State<ItemPhotoPicker> createState() => _ItemPhotoPickerState();
}

class _ItemPhotoPickerState extends State<ItemPhotoPicker> {
  late String? _path = widget.repo.photoPathFor(widget.itemId);
  bool _busy = false;

  Future<void> _choose() async {
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, _PhotoAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, _PhotoAction.gallery),
            ),
            if (_path != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Quitar foto'),
                onTap: () => Navigator.pop(ctx, _PhotoAction.remove),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _PhotoAction.camera:
        await _pick(ImageSource.camera);
      case _PhotoAction.gallery:
        await _pick(ImageSource.gallery);
      case _PhotoAction.remove:
        await _remove();
    }
  }

  Future<void> _pick(ImageSource source) async {
    final XFile? picked;
    try {
      // The photo is only ever shown at 120x120, so there's no reason to
      // keep it at full camera resolution (often several MB): downsampling
      // at pick time keeps storage and decoding cheap on low-end phones.
      picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'No se pudo abrir la cámara/galería.');
      }
      return;
    }
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final dir = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/fotos',
      );
      await dir.create(recursive: true);
      final saved = File('${dir.path}/${widget.itemId}.jpg');
      await saved.writeAsBytes(await picked.readAsBytes());
      await widget.repo.setPhotoPath(widget.itemId, saved.path);
      // The path doesn't change when replacing a photo, so the image cache
      // (keyed by path) would otherwise keep showing the old picture here
      // and on the catalog card until the app restarts.
      await FileImage(saved).evict();
      if (mounted) setState(() => _path = saved.path);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'No se pudo guardar la foto.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final path = _path;
    if (path == null) return;
    setState(() => _busy = true);
    try {
      await widget.repo.removePhotoPath(widget.itemId);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showErrorSnackBar(context, 'No se pudo quitar la foto.');
      }
      return;
    }
    // Best-effort: the file may already be gone, and what matters (the
    // stored path) is already cleared above.
    try {
      await File(path).delete();
    } catch (e) {
      // Ignored.
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _path = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final path = _path;

    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _busy ? null : _choose,
        child: Container(
          width: 120,
          height: 120,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: _busy
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : path == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Agregar foto',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
              : Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.broken_image_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
      ),
    );
  }
}

enum _PhotoAction { camera, gallery, remove }
