import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const FieldLabel(this.text, {super.key, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: AppTheme.ink,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
            height: 1.2,
          ),
          children: [
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Color? backgroundColor;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
          )
        : icon == null
            ? Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: double.infinity),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppTheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: loading ? null : onPressed,
        child: child,
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        color: AppTheme.ink,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.muted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 16),
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Differentiated Dot Status Chip
class StatusChip extends StatelessWidget {
  final String status;
  final bool compact;
  final bool showBg;

  const StatusChip(
    this.status, {
    super.key,
    this.compact = false,
    this.showBg = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    late Color bg;
    late Color dotColor;
    late Color textColor;
    late String label;

    switch (s) {
      case 'approved':
        bg = const Color(0xFFDCFCE7);
        dotColor = const Color(0xFF16A34A);
        textColor = const Color(0xFF16A34A);
        label = 'Approved';
        break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2);
        dotColor = const Color(0xFFDC2626);
        textColor = const Color(0xFFDC2626);
        label = 'Rejected';
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        dotColor = const Color(0xFFF59E0B);
        textColor = const Color(0xFFF59E0B);
        label = 'Pending';
    }

    if (!showBg) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: compact ? 11.5 : 12.5,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppTheme.primarySoft.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primary, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppTheme.ink,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class SearchInputField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const SearchInputField({
    super.key,
    required this.hint,
    required this.controller,
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, val, _) {
        final hasText = val.text.isNotEmpty;
        return TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13.5, height: 1.3),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.muted, size: 20),
            suffixIcon: hasText
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      controller.clear();
                      if (onChanged != null) onChanged!('');
                      if (onClear != null) onClear!();
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        );
      },
    );
  }
}

/// Shimmer Skeleton Loading Widget
class SkeletonCard extends StatefulWidget {
  final double height;
  final double width;
  final double borderRadius;

  const SkeletonCard({
    super.key,
    this.height = 76,
    this.width = double.infinity,
    this.borderRadius = 16,
  });

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.grey.shade300.withValues(alpha: _anim.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// List of Shimmer Skeletons
class SkeletonListLoader extends StatelessWidget {
  final int count;
  final double itemHeight;
  const SkeletonListLoader({
    super.key,
    this.count = 4,
    this.itemHeight = 76,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => SkeletonCard(height: itemHeight),
    );
  }
}

class SheetOption<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;

  const SheetOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
  });
}

/// Redesigned premium Bottom Sheet for option picking with Safe Area padding
Future<T?> showOptionBottomSheet<T>({
  required BuildContext context,
  required String title,
  required List<SheetOption<T>> options,
  T? selected,
  String? subtitle,
}) {
  final bottomInset = MediaQuery.paddingOf(context).bottom;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    elevation: 8,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.70;
      return SafeArea(
        bottom: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppTheme.ink,
                                letterSpacing: -0.2,
                                height: 1.2,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.muted,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.line),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final opt = options[index];
                      final isSelected = opt.value == selected;
                      return Material(
                        color: isSelected
                            ? AppTheme.primarySoft.withValues(alpha: 0.45)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.pop(ctx, opt.value),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppTheme.primary : AppTheme.line,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                if (opt.icon != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppTheme.primary
                                          : AppTheme.canvas,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      opt.icon,
                                      size: 16,
                                      color: isSelected
                                          ? Colors.white
                                          : AppTheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        opt.label,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          fontSize: 14,
                                          color: isSelected
                                              ? AppTheme.primary
                                              : AppTheme.ink,
                                          height: 1.2,
                                        ),
                                      ),
                                      if (opt.subtitle != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          opt.subtitle!,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: AppTheme.muted,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppTheme.primary,
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Category Selector Bottom Sheet with Search & Persisted Sorting (Most Used, A-Z, Z-A)
Future<String?> showCategoryPickerBottomSheet({
  required BuildContext context,
  required List<Map<String, dynamic>> categories,
  String? selectedUuid,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final initialSort = prefs.getString('category_sort_preference') ?? 'most_used';

  if (!context.mounted) return null;

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    elevation: 10,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return _CategoryPickerSheetContent(
        categories: categories,
        selectedUuid: selectedUuid,
        initialSort: initialSort,
        onSortChanged: (sortMode) async {
          final p = await SharedPreferences.getInstance();
          await p.setString('category_sort_preference', sortMode);
        },
      );
    },
  );
}

class _CategoryPickerSheetContent extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final String? selectedUuid;
  final String initialSort;
  final ValueChanged<String> onSortChanged;

  const _CategoryPickerSheetContent({
    required this.categories,
    required this.selectedUuid,
    required this.initialSort,
    required this.onSortChanged,
  });

  @override
  State<_CategoryPickerSheetContent> createState() => _CategoryPickerSheetContentState();
}

class _CategoryPickerSheetContentState extends State<_CategoryPickerSheetContent> {
  late String _sortMode;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _sortMode = widget.initialSort;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _setSort(String mode) {
    setState(() => _sortMode = mode);
    widget.onSortChanged(mode);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.75;

    // Filter & Sort logic
    var list = widget.categories.where((c) {
      if (_searchQuery.isEmpty) return true;
      final name = (c['category_name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery);
    }).toList();

    if (_sortMode == 'a_z') {
      list.sort((a, b) => (a['category_name'] ?? '').toString().compareTo((b['category_name'] ?? '').toString()));
    } else if (_sortMode == 'z_a') {
      list.sort((a, b) => (b['category_name'] ?? '').toString().compareTo((a['category_name'] ?? '').toString()));
    }
    // 'most_used' preserves original list order

    return SafeArea(
      bottom: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Select Category',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16.5,
                          color: AppTheme.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: SearchInputField(
                  hint: 'Search category name…',
                  controller: _searchCtrl,
                  onChanged: (q) => setState(() => _searchQuery = q.trim().toLowerCase()),
                ),
              ),
              const SizedBox(height: 10),
              // Sort Option Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    _sortChip('most_used', 'Most Used'),
                    const SizedBox(width: 8),
                    _sortChip('a_z', 'A - Z'),
                    const SizedBox(width: 8),
                    _sortChip('z_a', 'Z - A'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppTheme.line),
              Flexible(
                child: list.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No categories match your search.',
                          style: TextStyle(color: AppTheme.muted, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, idx) {
                          final c = list[idx];
                          final uuid = c['uuid']?.toString() ?? '';
                          final name = c['category_name']?.toString() ?? '';
                          final isSelected = uuid == widget.selectedUuid;

                          return Material(
                            color: isSelected
                                ? AppTheme.primarySoft.withValues(alpha: 0.45)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => Navigator.pop(context, uuid),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.primary : AppTheme.line,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          fontSize: 14,
                                          color: isSelected
                                              ? AppTheme.primary
                                              : AppTheme.ink,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppTheme.primary,
                                        size: 18,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortChip(String mode, String label) {
    final selected = _sortMode == mode;
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? Colors.white : AppTheme.ink,
      ),
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.canvas,
      side: BorderSide(color: selected ? AppTheme.primary : AppTheme.line),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      onSelected: (_) => _setSort(mode),
    );
  }
}

/// Tappable field that opens options in a bottom sheet.
class BottomSheetSelectField<T> extends StatelessWidget {
  final String title;
  final String hint;
  final T? value;
  final List<SheetOption<T>> options;
  final ValueChanged<T> onChanged;
  final bool enabled;

  const BottomSheetSelectField({
    super.key,
    required this.title,
    required this.options,
    required this.onChanged,
    this.value,
    this.hint = 'Select',
    this.enabled = true,
  });

  String get _display {
    for (final o in options) {
      if (o.value == value) return o.label;
    }
    return hint;
  }

  Future<void> _open(BuildContext context) async {
    if (!enabled || options.isEmpty) return;
    final picked = await showOptionBottomSheet<T>(
      context: context,
      title: title,
      options: options,
      selected: value,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && options.any((o) => o.value == value);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? () => _open(context) : null,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: hasValue ? AppTheme.primary : AppTheme.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _display,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                    color: hasValue ? AppTheme.ink : AppTheme.muted,
                    height: 1.2,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: enabled ? AppTheme.primary : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating Capsule Navigation Bar — Home / Shops / History
class GlassmorphismCapsuleBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const GlassmorphismCapsuleBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: 60,
      right: 60,
      bottom: (bottomInset > 0 ? bottomInset + 8 : 18),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.line.withValues(alpha: 0.8)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildCapsuleTab(
                      index: 0,
                      label: 'Home',
                      icon: Icons.home_rounded,
                      outlinedIcon: Icons.home_outlined,
                    ),
                  ),
                  Expanded(
                    child: _buildCapsuleTab(
                      index: 1,
                      label: 'Shops',
                      icon: Icons.storefront_rounded,
                      outlinedIcon: Icons.storefront_outlined,
                    ),
                  ),
                  Expanded(
                    child: _buildCapsuleTab(
                      index: 2,
                      label: 'History',
                      icon: Icons.history_rounded,
                      outlinedIcon: Icons.history_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCapsuleTab({
    required int index,
    required String label,
    required IconData icon,
    required IconData outlinedIcon,
  }) {
    final isSelected = selectedIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onTabSelected(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? icon : outlinedIcon,
                size: 22,
                color: isSelected ? AppTheme.primary : AppTheme.muted,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppTheme.primary : AppTheme.muted,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Red Wave Sparkline Custom Painter matching Home dashboard image
class RedWaveSparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Draw background faint red wave line
    final pathFaint = Path();
    pathFaint.moveTo(w * 0.40, h * 0.90);
    pathFaint.cubicTo(
      w * 0.52, h * 0.70,
      w * 0.65, h * 0.32,
      w * 0.72, h * 0.32,
    );
    pathFaint.cubicTo(
      w * 0.80, h * 0.32,
      w * 0.85, h * 0.75,
      w * 0.92, h * 0.88,
    );

    final paintFaint = Paint()
      ..color = const Color(0xFFFCA5A5).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(pathFaint, paintFaint);

    // Draw main bold red wave line
    final pathMain = Path();
    pathMain.moveTo(w * 0.28, h * 0.88);
    pathMain.cubicTo(
      w * 0.42, h * 0.74,
      w * 0.50, h * 0.80,
      w * 0.58, h * 0.80,
    );
    pathMain.cubicTo(
      w * 0.68, h * 0.80,
      w * 0.74, h * 0.36,
      w * 0.84, h * 0.12,
    );
    pathMain.cubicTo(
      w * 0.89, h * 0.22,
      w * 0.93, h * 0.55,
      w * 0.98, h * 0.75,
    );

    // Smooth gradient fill below main wave
    final fillPath = Path.from(pathMain)
      ..lineTo(w * 0.98, h)
      ..lineTo(w * 0.28, h)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFDC2626).withValues(alpha: 0.22),
          const Color(0xFFDC2626).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(fillPath, fillPaint);

    // Main red stroke line
    final strokePaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(pathMain, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 3D Shop Artwork Widget matching Shop Cards & Shop Banner
class Shop3DArtworkWidget extends StatelessWidget {
  final double width;
  final double height;

  const Shop3DArtworkWidget({
    super.key,
    this.width = 90,
    this.height = 90,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/shop.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, err, stack) {
        return Image.asset(
          'assets/images/shop-banner.png',
          width: width,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, err2, stack2) {
            return SizedBox(
              width: width,
              height: height,
              child: CustomPaint(painter: _Shop3DPainter()),
            );
          },
        );
      },
    );
  }
}

class _Shop3DPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Ground shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawOval(
      Rect.fromLTWH(w * 0.08, h * 0.84, w * 0.84, h * 0.12),
      shadowPaint,
    );

    // Main Wall (Front Face)
    final frontWall = Path()
      ..moveTo(w * 0.22, h * 0.42)
      ..lineTo(w * 0.78, h * 0.42)
      ..lineTo(w * 0.78, h * 0.84)
      ..lineTo(w * 0.22, h * 0.84)
      ..close();

    final wallPaint = Paint()..color = const Color(0xFFFAF3EC);
    canvas.drawPath(frontWall, wallPaint);

    // Side Wall (3D Isometric Depth)
    final sideWall = Path()
      ..moveTo(w * 0.78, h * 0.42)
      ..lineTo(w * 0.88, h * 0.35)
      ..lineTo(w * 0.88, h * 0.76)
      ..lineTo(w * 0.78, h * 0.84)
      ..close();

    final sideWallPaint = Paint()..color = const Color(0xFFD6C8B8);
    canvas.drawPath(sideWall, sideWallPaint);

    // Shop Wooden Sign "SHOP"
    final signRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.32, h * 0.24, w * 0.36, h * 0.14),
      const Radius.circular(5),
    );
    canvas.drawRRect(signRect, Paint()..color = const Color(0xFFE5A65E));
    canvas.drawRRect(
      signRect,
      Paint()
        ..color = const Color(0xFFB45309)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Awning Canopy (Red & Beige stripes)
    final awningBg = Path()
      ..moveTo(w * 0.16, h * 0.38)
      ..lineTo(w * 0.84, h * 0.38)
      ..lineTo(w * 0.88, h * 0.49)
      ..lineTo(w * 0.12, h * 0.49)
      ..close();
    canvas.drawPath(awningBg, Paint()..color = const Color(0xFFE53935));

    final stripePaint = Paint()..color = const Color(0xFFFFF1F2);
    for (int i = 1; i < 7; i += 2) {
      final stripe = Path()
        ..moveTo(w * (0.16 + i * 0.095), h * 0.38)
        ..lineTo(w * (0.16 + (i + 1) * 0.095), h * 0.38)
        ..lineTo(w * (0.12 + (i + 1) * 0.105), h * 0.49)
        ..lineTo(w * (0.12 + i * 0.105), h * 0.49)
        ..close();
      canvas.drawPath(stripe, stripePaint);
    }

    // Door Frame & Glass
    final doorRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.45, h * 0.54, w * 0.22, h * 0.30),
      const Radius.circular(3),
    );
    canvas.drawRRect(doorRect, Paint()..color = const Color(0xFF475569));
    canvas.drawRRect(
      doorRect,
      Paint()
        ..color = const Color(0xFF1E293B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Door Handle
    canvas.drawCircle(
      Offset(w * 0.49, h * 0.68),
      1.8,
      Paint()..color = const Color(0xFFF59E0B),
    );

    // Window Frame & Glass
    final winRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.26, h * 0.54, w * 0.15, h * 0.18),
      const Radius.circular(3),
    );
    canvas.drawRRect(winRect, Paint()..color = const Color(0xFFBAE6FD));
    canvas.drawRRect(
      winRect,
      Paint()
        ..color = const Color(0xFF38BDF8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Side Plant Pot
    final potRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.17, h * 0.74, w * 0.09, h * 0.10),
      const Radius.circular(2),
    );
    canvas.drawRRect(potRect, Paint()..color = const Color(0xFFD97706));
    canvas.drawCircle(Offset(w * 0.21, h * 0.71), 4.0, Paint()..color = const Color(0xFF16A34A));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
