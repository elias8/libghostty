@Tags(['ffi'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:libghostty/src/hook/fix_ios_page_alignment.dart';
import 'package:test/test.dart';

const _machoMagic64 = 0xFEEDFACF;
const _lcSegment64 = 0x19;
const _segmentCmdSize = 72;
const _headerSize = 32;
const _pageSize = 16384;

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('ios_alignment_test_');
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  File writeFile(Uint8List bytes) {
    final file = File('${tmpDir.path}/test.dylib');
    file.writeAsBytesSync(bytes);
    return file;
  }

  group('fixIosPageAlignment', () {
    test('patches non-aligned vmsize to page boundary', () {
      final binary = _buildMachO([
        _SegmentSpec(
          '__TEXT',
          vmaddr: 0,
          vmsize: 0x3000,
          fileoff: 0,
          filesize: 0x3000,
        ),
      ]);

      final file = writeFile(binary);
      fixIosPageAlignment(file);

      final patched = ByteData.sublistView(file.readAsBytesSync());
      final vmsize = patched.getUint64(_headerSize + 32, Endian.little);
      expect(vmsize, equals(_pageSize));
      expect(vmsize % _pageSize, equals(0));
    });

    test('patches non-aligned filesize to page boundary', () {
      final binary = _buildMachO([
        _SegmentSpec(
          '__TEXT',
          vmaddr: 0,
          vmsize: 0x3000,
          fileoff: 0,
          filesize: 0x3000,
        ),
      ]);

      final file = writeFile(binary);
      fixIosPageAlignment(file);

      final patched = ByteData.sublistView(file.readAsBytesSync());
      final filesize = patched.getUint64(_headerSize + 48, Endian.little);
      expect(filesize, equals(_pageSize));
      expect(filesize % _pageSize, equals(0));
    });

    test('does not modify file when already page-aligned', () {
      final binary = _buildMachO([
        _SegmentSpec(
          '__TEXT',
          vmaddr: 0,
          vmsize: _pageSize,
          fileoff: 0,
          filesize: _pageSize,
        ),
      ]);

      final original = Uint8List.fromList(binary);
      final file = writeFile(binary);
      fixIosPageAlignment(file);

      expect(file.readAsBytesSync(), equals(original));
    });

    test('skips non-MachO files', () {
      final notMachO = Uint8List(128);
      ByteData.sublistView(notMachO).setUint32(0, 0x12345678, Endian.little);

      final original = Uint8List.fromList(notMachO);
      final file = writeFile(notMachO);
      fixIosPageAlignment(file);

      expect(file.readAsBytesSync(), equals(original));
    });

    test('skips files smaller than header size', () {
      final tiny = Uint8List(16);
      final original = Uint8List.fromList(tiny);
      final file = writeFile(tiny);
      fixIosPageAlignment(file);

      expect(file.readAsBytesSync(), equals(original));
    });

    test('handles __LINKEDIT: aligns vmsize but preserves filesize', () {
      final binary = _buildMachO([
        _SegmentSpec(
          '__LINKEDIT',
          vmaddr: 0,
          vmsize: 0x2800,
          fileoff: 0,
          filesize: 0x2800,
        ),
      ]);

      final file = writeFile(binary);
      fixIosPageAlignment(file);

      final patched = ByteData.sublistView(file.readAsBytesSync());
      final vmsize = patched.getUint64(_headerSize + 32, Endian.little);
      final filesize = patched.getUint64(_headerSize + 48, Endian.little);

      expect(vmsize, equals(_pageSize));
      expect(filesize, equals(0x2800));
    });

    test('consecutive segments use next segment address for sizing', () {
      final binary = _buildMachO([
        _SegmentSpec(
          '__TEXT',
          vmaddr: 0x0000,
          vmsize: 0x3000,
          fileoff: 0x0000,
          filesize: 0x3000,
        ),
        _SegmentSpec(
          '__DATA',
          vmaddr: 0x4000,
          vmsize: 0x1000,
          fileoff: 0x4000,
          filesize: 0x1000,
        ),
      ]);

      final file = writeFile(binary);
      fixIosPageAlignment(file);

      final patched = ByteData.sublistView(file.readAsBytesSync());
      final textVmsize = patched.getUint64(_headerSize + 32, Endian.little);
      expect(textVmsize, equals(0x4000));

      final textFilesize = patched.getUint64(_headerSize + 48, Endian.little);
      expect(textFilesize, equals(0x4000));
    });

    test('is idempotent', () {
      final binary = _buildMachO([
        _SegmentSpec(
          '__TEXT',
          vmaddr: 0,
          vmsize: 0x3000,
          fileoff: 0,
          filesize: 0x3000,
        ),
      ]);

      final file = writeFile(binary);
      fixIosPageAlignment(file);
      final afterFirst = file.readAsBytesSync();

      fixIosPageAlignment(file);
      final afterSecond = file.readAsBytesSync();

      expect(afterSecond, equals(afterFirst));
    });

    test('handles file with no segment commands', () {
      final binary = Uint8List(_headerSize + 64);
      final data = ByteData.sublistView(binary);
      data.setUint32(0, _machoMagic64, Endian.little);
      data.setUint32(16, 0, Endian.little);

      final original = Uint8List.fromList(binary);
      final file = writeFile(binary);
      fixIosPageAlignment(file);

      expect(file.readAsBytesSync(), equals(original));
    });
  });
}

class _SegmentSpec {
  final String name;
  final int vmaddr;
  final int vmsize;
  final int fileoff;
  final int filesize;

  _SegmentSpec(
    this.name, {
    required this.vmaddr,
    required this.vmsize,
    required this.fileoff,
    required this.filesize,
  });
}

Uint8List _buildMachO(List<_SegmentSpec> segments) {
  final totalSize = _headerSize + segments.length * _segmentCmdSize;
  final binary = Uint8List(totalSize + 256);
  final data = ByteData.sublistView(binary);

  data.setUint32(0, _machoMagic64, Endian.little);
  data.setUint32(4, 0x0100000C, Endian.little);
  data.setUint32(8, 0, Endian.little);
  data.setUint32(12, 6, Endian.little);
  data.setUint32(16, segments.length, Endian.little);
  data.setUint32(20, segments.length * _segmentCmdSize, Endian.little);
  data.setUint32(24, 0, Endian.little);
  data.setUint32(28, 0, Endian.little);

  var offset = _headerSize;
  for (final seg in segments) {
    data.setUint32(offset, _lcSegment64, Endian.little);
    data.setUint32(offset + 4, _segmentCmdSize, Endian.little);

    final nameBytes = seg.name.codeUnits;
    for (var i = 0; i < 16; i++) {
      binary[offset + 8 + i] = i < nameBytes.length ? nameBytes[i] : 0;
    }

    data.setUint64(offset + 24, seg.vmaddr, Endian.little);
    data.setUint64(offset + 32, seg.vmsize, Endian.little);
    data.setUint64(offset + 40, seg.fileoff, Endian.little);
    data.setUint64(offset + 48, seg.filesize, Endian.little);
    data.setUint32(offset + 56, 7, Endian.little);
    data.setUint32(offset + 60, 5, Endian.little);
    data.setUint32(offset + 64, 0, Endian.little);
    data.setUint32(offset + 68, 0, Endian.little);

    offset += _segmentCmdSize;
  }

  return binary;
}
