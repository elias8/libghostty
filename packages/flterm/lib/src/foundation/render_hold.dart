import 'package:flutter/foundation.dart' show ValueGetter;

typedef RenderHoldCallback = bool Function({required bool held});

typedef RenderSurfaceCallbacks = ({
  RenderHoldCallback onRenderHold,
  ValueGetter<bool> isContentInteractionReady,
});
