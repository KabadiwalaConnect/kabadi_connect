import 'package:flutter/material.dart';

/// Shared catalogue imagery, not photos/evidence of any user's actual goods.
const materialPhotoKeys = <String>[
  'Copper',
  'Aluminium',
  'Iron',
  'PCB',
  'Battery',
  'CRT',
  'LCD',
  'Cable',
  'Motor',
];

class MaterialPhoto extends StatelessWidget {
  const MaterialPhoto({
    required this.material,
    this.width = 72,
    this.height = 72,
    this.imageUrl,
    super.key,
  });
  final String material;
  final double width;
  final double height;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => const Center(
      child: Icon(Icons.recycling_rounded, size: 36, color: Color(0xFF21643D)),
    );
    Widget localImage() => materialPhotoKeys.contains(material)
        ? Image.asset(
            'assets/images/${material.toLowerCase()}.png',
            fit: BoxFit.contain,
            errorBuilder: (_, error, stack) => fallback(),
          )
        : fallback();
    final url = imageUrl == null ? null : Uri.tryParse(imageUrl!);
    final remote = url != null && url.scheme == 'https' && url.host.isNotEmpty;
    return ExcludeSemantics(
      // Parent labels identify the material; do not repeat decorative imagery.
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: remote
            ? Image.network(
                imageUrl!,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : localImage(),
                errorBuilder: (_, error, stack) => localImage(),
              )
            : localImage(),
      ),
    );
  }
}

/// Nine image choices. Parent owns selection, voice and navigation.
/// Rows grow with translated/large text instead of clipping fixed-height tiles.
class MaterialPhotoGrid extends StatelessWidget {
  const MaterialPhotoGrid({
    required this.labelFor,
    required this.onSelected,
    this.selected,
    this.detailFor,
    super.key,
  });
  final String Function(String) labelFor;
  final ValueChanged<String>? onSelected;
  final String? selected;
  final String? Function(String)? detailFor;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wideText = MediaQuery.textScalerOf(context).scale(14) > 20;
      final columns = constraints.maxWidth < 300 || wideText ? 2 : 3;
      final rows = <Widget>[];
      for (var start = 0; start < materialPhotoKeys.length; start += columns) {
        final children = <Widget>[];
        for (var offset = 0; offset < columns; offset++) {
          if (offset > 0) {
            children.add(const SizedBox(width: 8));
          }
          final index = start + offset;
          if (index >= materialPhotoKeys.length) {
            children.add(const Expanded(child: SizedBox()));
            continue;
          }
          final material = materialPhotoKeys[index];
          final isSelected = selected == material;
          final detail = detailFor?.call(material);
          children.add(
            Expanded(
              child: Semantics(
                selected: isSelected,
                child: Material(
                  color: isSelected
                      ? const Color(0xFF21643D)
                      : const Color(0xFFF1F7EF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF21643D)
                          : const Color(0xFFDEE9DA),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey('material_photo_$material'),
                    onTap: onSelected == null
                        ? null
                        : () => onSelected!(material),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Stack(
                            children: [
                              MaterialPhoto(
                                material: material,
                                width: double.infinity,
                                height: 82,
                              ),
                              if (isSelected)
                                const Positioned(
                                  right: 3,
                                  top: 3,
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF21643D),
                                    size: 23,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            labelFor(material),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF183A23),
                            ),
                          ),
                          if (detail != null) ...[
                            const SizedBox(height: 5),
                            Text(
                              detail,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white70
                                    : const Color(0xFF596653),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        if (rows.isNotEmpty) {
          rows.add(const SizedBox(height: 10));
        }
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        );
      }
      return Column(children: rows);
    },
  );
}
