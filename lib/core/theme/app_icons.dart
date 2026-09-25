import 'package:flutter/widgets.dart';

/// Every icon of the app, in one place (swap the set here). Phosphor (MIT): one
/// consistent fine-line family; Regular by default, Fill for selected states. Only
/// these two fonts are bundled (assets/fonts) and tree-shaken to the glyphs used.
abstract final class AppIcons {
  // Tabs.
  static const IconData home = IconData(0xe2c2, fontFamily: 'PhosphorRegular'); // house
  static const IconData homeActive = IconData(0xe2c2, fontFamily: 'PhosphorFill'); // house
  static const IconData discover = IconData(0xe1c8, fontFamily: 'PhosphorRegular'); // compass
  static const IconData discoverActive = IconData(0xe1c8, fontFamily: 'PhosphorFill'); // compass
  static const IconData create = IconData(0xe3d4, fontFamily: 'PhosphorRegular'); // plus
  static const IconData activity = IconData(0xe0ce, fontFamily: 'PhosphorRegular'); // bell
  static const IconData activityActive = IconData(0xe0ce, fontFamily: 'PhosphorFill'); // bell
  static const IconData profile = IconData(0xe4c2, fontFamily: 'PhosphorRegular'); // user
  static const IconData profileActive = IconData(0xe4c2, fontFamily: 'PhosphorFill'); // user

  // Navigation and controls.
  static const IconData back = IconData(0xe138, fontFamily: 'PhosphorRegular'); // caretLeft
  static const IconData forward = IconData(0xe13a, fontFamily: 'PhosphorRegular'); // caretRight
  static const IconData expand = IconData(0xe136, fontFamily: 'PhosphorRegular'); // caretDown
  static const IconData close = IconData(0xe4f6, fontFamily: 'PhosphorRegular'); // x
  static const IconData show = IconData(0xe220, fontFamily: 'PhosphorRegular'); // eye
  static const IconData hide = IconData(0xe224, fontFamily: 'PhosphorRegular'); // eyeSlash
  static const IconData search = IconData(0xe30c, fontFamily: 'PhosphorRegular'); // magnifyingGlass
  static const IconData minus = IconData(0xe32a, fontFamily: 'PhosphorRegular'); // minus
  static const IconData plus = IconData(0xe3d4, fontFamily: 'PhosphorRegular'); // plus
  static const IconData edit = IconData(0xe3b4, fontFamily: 'PhosphorRegular'); // pencilSimple
  static const IconData settings = IconData(0xe434, fontFamily: 'PhosphorRegular'); // slidersHorizontal
  static const IconData share = IconData(0xeaf0, fontFamily: 'PhosphorRegular'); // export

  // Media.
  static const IconData play = IconData(0xe3d0, fontFamily: 'PhosphorFill'); // play
  static const IconData playOutline = IconData(0xe3d0, fontFamily: 'PhosphorRegular'); // play
  static const IconData soundOn = IconData(0xe44a, fontFamily: 'PhosphorRegular'); // speakerHigh
  static const IconData soundOff = IconData(0xe45a, fontFamily: 'PhosphorRegular'); // speakerSlash
  static const IconData video = IconData(0xe4da, fontFamily: 'PhosphorRegular'); // videoCamera
  static const IconData gallery = IconData(0xe836, fontFamily: 'PhosphorRegular'); // images
  static const IconData camera = IconData(0xe10e, fontFamily: 'PhosphorRegular'); // camera
  static const IconData feed = IconData(0xe792, fontFamily: 'PhosphorRegular'); // filmStrip
  static const IconData performance = IconData(0xe8c0, fontFamily: 'PhosphorRegular'); // filmReel
  static const IconData microphone = IconData(0xe326, fontFamily: 'PhosphorRegular'); // microphone

  // Competition.
  static const IconData trophy = IconData(0xe67e, fontFamily: 'PhosphorRegular'); // trophy
  static const IconData like = IconData(0xe2a8, fontFamily: 'PhosphorRegular'); // heart
  static const IconData liked = IconData(0xe2a8, fontFamily: 'PhosphorFill'); // heart
  static const IconData vote = IconData(0xe186, fontFamily: 'PhosphorRegular'); // checkSquare
  static const IconData battle = IconData(0xe5ba, fontFamily: 'PhosphorRegular'); // sword
  static const IconData journey = IconData(0xe39c, fontFamily: 'PhosphorRegular'); // path
  static const IconData preselection = IconData(0xe266, fontFamily: 'PhosphorRegular'); // funnel
  static const IconData payment = IconData(0xe68a, fontFamily: 'PhosphorRegular'); // wallet
  static const IconData jury = IconData(0xea32, fontFamily: 'PhosphorRegular'); // gavel

  // States.
  static const IconData done = IconData(0xe184, fontFamily: 'PhosphorFill'); // checkCircle
  static const IconData doneOutline = IconData(0xe184, fontFamily: 'PhosphorRegular'); // checkCircle
  static const IconData pending = IconData(0xe19a, fontFamily: 'PhosphorRegular'); // clock
  static const IconData uploading = IconData(0xe1ae, fontFamily: 'PhosphorRegular'); // cloudArrowUp
  static const IconData locked = IconData(0xe308, fontFamily: 'PhosphorRegular'); // lockSimple
  static const IconData error = IconData(0xe4e2, fontFamily: 'PhosphorRegular'); // warningCircle
  static const IconData offline = IconData(0xe4f2, fontFamily: 'PhosphorRegular'); // wifiSlash
  static const IconData unverified = IconData(0xe412, fontFamily: 'PhosphorRegular'); // shieldWarning

  // Account.
  static const IconData password = IconData(0xe2d6, fontFamily: 'PhosphorRegular'); // key
  static const IconData logout = IconData(0xe42a, fontFamily: 'PhosphorRegular'); // signOut
}
