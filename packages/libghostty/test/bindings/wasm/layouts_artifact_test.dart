@Tags(['wasm'])
library;

import 'package:test/test.dart';

import '../helpers/wasm_binding_fixture.dart';

void main() {
  test('loads frozen style layout from the WASM artifact', () async {
    final fixture = WasmBindingFixture();
    await fixture.load();
    addTearDown(fixture.close);

    final layout = fixture.layout;
    expect(layout.styleSize, 16);
    expect(layout.styleFg, 0);
    expect(layout.styleBg, 4);
    expect(layout.styleUnderlineColor, 8);
    expect(layout.styleFlags, 12);
    expect(layout.styleColorR, 1);
    expect(layout.styleColorG, 2);
    expect(layout.styleColorB, 3);
  });
}
