import 'dart:typed_data';

import '../../generated/libghostty_enums.g.dart';
import '../../types/types.dart';
import '../types.dart';

abstract interface class KittyGraphicsBindings {
  LibGhosttyHandle kittyGraphicsGet(LibGhosttyHandle terminal);
  int kittyGraphicsGetGeneration(LibGhosttyHandle graphics);
  void kittyGraphicsGetPlacements(
    LibGhosttyHandle graphics,
    LibGhosttyHandle iterator,
  );

  LibGhosttyHandle kittyGraphicsImage(LibGhosttyHandle graphics, int imageId);
  KittyImageCompression kittyGraphicsImageGetCompression(
    LibGhosttyHandle image,
  );
  KittyImageFormat kittyGraphicsImageGetFormat(LibGhosttyHandle image);
  int kittyGraphicsImageGetGeneration(LibGhosttyHandle image);
  int kittyGraphicsImageGetHeight(LibGhosttyHandle image);
  int kittyGraphicsImageGetId(LibGhosttyHandle image);
  int kittyGraphicsImageGetNumber(LibGhosttyHandle image);
  int kittyGraphicsImageGetPixelData(
    LibGhosttyHandle image,
    Uint8List destination,
  );
  int kittyGraphicsImageGetWidth(LibGhosttyHandle image);

  KittyPlacement kittyGraphicsPlacementGet(
    LibGhosttyHandle iterator,
    LibGhosttyHandle graphics,
    LibGhosttyHandle terminal,
  );
  void kittyGraphicsPlacementIteratorFree(LibGhosttyHandle iterator);
  LibGhosttyHandle kittyGraphicsPlacementIteratorNew();
  void kittyGraphicsPlacementIteratorSetLayer(
    LibGhosttyHandle iterator,
    KittyPlacementLayer layer,
  );
  bool kittyGraphicsPlacementNext(LibGhosttyHandle iterator);

  void terminalGetKittyGraphicsUnicodePlacementIterator(
    LibGhosttyHandle terminal,
    LibGhosttyHandle iterator,
  );
  RawKittyUnicodePlacement kittyGraphicsUnicodePlacementGet(
    LibGhosttyHandle iterator,
    LibGhosttyHandle terminal,
  );
  void kittyGraphicsUnicodePlacementIteratorFree(LibGhosttyHandle iterator);
  LibGhosttyHandle kittyGraphicsUnicodePlacementIteratorNew();
  bool kittyGraphicsUnicodePlacementNext(LibGhosttyHandle iterator);
}
