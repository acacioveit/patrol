import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:patrol_devtools_extension/native_inspector/native_inspector_tree.dart';
import 'package:patrol_devtools_extension/native_inspector/node.dart';
import 'package:patrol_devtools_extension/native_inspector/node_details.dart';

class NativeInspectorView extends HookWidget {
  const NativeInspectorView({
    super.key,
    required this.onNodeChanged,
    required this.onRefreshPressed,
    required this.roots,
    required this.currentNode,
  });

  final List<Node> roots;
  final Node? currentNode;
  final ValueChanged<Node?> onNodeChanged;
  final VoidCallback onRefreshPressed;

  @override
  Widget build(BuildContext context) {
    final fullNodeNames = useState(false);

    final splitAxis = Split.axisFor(context, 0.85);
    final child = Split(
      axis: splitAxis,
      initialFractions: const [0.6, 0.4],
      children: [
        RoundedOutlinedBorder(
          clip: true,
          child: Column(
            children: [
              _InspectorTreeControls(
                onRefreshPressed: onRefreshPressed,
                fullNodeNames: fullNodeNames,
              ),
              Expanded(
                child: NativeInspectorTree(
                  roots: roots,
                  props: NodeProps(
                    currentNode: currentNode,
                    onNodeTap: onNodeChanged,
                    fullNodeName: fullNodeNames.value,
                    colorScheme: Theme.of(context).colorScheme,
                  ),
                ),
              ),
            ],
          ),
        ),
        RoundedOutlinedBorder(
          clip: true,
          child: _NativeViewDetails(currentNode: currentNode),
        ),
      ],
    );

    return child;
  }
}

class _InspectorTreeControls extends StatelessWidget {
  const _InspectorTreeControls({
    required this.onRefreshPressed,
    required this.fullNodeNames,
  });

  final VoidCallback onRefreshPressed;
  final ValueNotifier<bool> fullNodeNames;

  @override
  Widget build(BuildContext context) {
    return _HeaderDecoration(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: denseSpacing),
                    child: Text('Native view tree', maxLines: 1),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: _ControlButton(
                    message: 'Full node names',
                    onPressed: () {
                      fullNodeNames.value = !fullNodeNames.value;
                    },
                    icon: fullNodeNames.value
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                ),
                Flexible(
                  child: _ControlButton(
                    icon: Icons.refresh,
                    message: 'Refresh tree',
                    onPressed: onRefreshPressed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.message,
    required this.onPressed,
    required this.icon,
  });

  final String message;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DevToolsTooltip(
      message: message,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onPressed,
        child: Icon(
          icon,
          size: actionsIconSize,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _NativeViewDetails extends StatelessWidget {
  const _NativeViewDetails({required this.currentNode});

  final Node? currentNode;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _HeaderDecoration(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: denseSpacing),
            child: SizedBox(
              width: double.infinity,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Native view details',
                  maxLines: 1,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: currentNode != null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: denseSpacing),
                  child: NodeDetails(node: currentNode!),
                )
              : const Center(child: Text('Select a node to view its details')),
        ),
      ],
    );
  }
}

class _HeaderDecoration extends StatelessWidget {
  const _HeaderDecoration({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: defaultHeaderHeight(isDense: _isDense()),
      decoration: BoxDecoration(
        border: Border(
          bottom: defaultBorderSide(Theme.of(context)),
        ),
      ),
      child: child,
    );
  }

  bool _isDense() {
    return ideTheme.embed;
  }
}
