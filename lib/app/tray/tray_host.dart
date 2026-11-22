import 'dart:io';

import 'package:tray_manager/tray_manager.dart';

/// What the tray menu shows.
final class TrayMenuState {
  const TrayMenuState({
    required this.status,
    required this.bypassChecked,
    required this.bypassEnabled,
  });

  /// Current status, shown as a disabled first item and as the tooltip.
  final String status;
  final bool bypassChecked;
  final bool bypassEnabled;
}

/// The menu-bar (macOS) / notification-area (Windows) icon and its menu.
/// An interface so `TrayController` can be tested without a real tray.
abstract interface class TrayHost {
  /// Shows the icon with its menu; the callbacks run on menu clicks.
  void show({
    required TrayMenuState initial,
    required void Function() onToggleBypass,
    required void Function() onOpen,
    required void Function() onQuit,
  });

  void update(TrayMenuState state);

  void dispose();
}

/// [TrayHost] on `tray_manager`'s native API.
final class NativeTrayHost implements TrayHost {
  static const _macosIcon = 'assets/tray/tray_icon_macos_template.png';
  static const _windowsIcon = 'assets/tray/tray_icon.ico';

  // Kept for as long as the icon is shown: a collected TrayIcon removes it.
  TrayIcon? _icon;
  MenuItem? _status;
  MenuItem? _bypass;

  @override
  void show({
    required TrayMenuState initial,
    required void Function() onToggleBypass,
    required void Function() onOpen,
    required void Function() onQuit,
  }) {
    final icon = TrayIcon.create();
    final menu = Menu.create();
    if (icon == null || menu == null) return;

    MenuItem? item(String label, MenuItemType type, void Function()? onClick) {
      final i = MenuItem.createWithLabelAndType(label, type);
      if (i == null) return null;
      if (onClick != null) {
        i.addListener((event) {
          if (event is MenuItemClickedEvent) onClick();
        });
      }
      menu.addItem(i);
      return i;
    }

    _status = item(initial.status, .normal, null)?..isEnabled = false;
    menu.addSeparator();
    _bypass = item('Bypass', .checkbox, onToggleBypass);
    item('Open Mute Around', .normal, onOpen);
    menu.addSeparator();
    item('Quit Mute Around', .normal, onQuit);

    if (Platform.isMacOS) {
      icon
        ..icon = ImageAsset.fromAsset(_macosIcon)
        ..isIconTemplate = true;
    } else {
      icon.icon = ImageAsset.fromAsset(_windowsIcon);
    }
    icon
      ..setContextMenu(menu)
      // Windows opens the menu on right-click; macOS on any click.
      ..setContextMenuTrigger(
        Platform.isMacOS ? .clicked : .rightClicked,
      )
      ..setVisible(true);
    // A left click on Windows opens the window.
    if (!Platform.isMacOS) {
      icon.addListener((event) {
        if (event is TrayIconClickedEvent) onOpen();
      });
    }
    _icon = icon;
    update(initial);
  }

  @override
  void update(TrayMenuState state) {
    _status?.label = state.status;
    _bypass
      ?..state = state.bypassChecked ? .checked : .unchecked
      ..isEnabled = state.bypassEnabled;
    _icon?.setTooltip('Mute Around — ${state.status}');
  }

  @override
  void dispose() {
    _icon?.dispose();
    _icon = null;
  }
}
