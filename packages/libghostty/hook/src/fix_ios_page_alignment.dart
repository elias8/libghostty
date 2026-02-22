import 'dart:io';
import 'dart:typed_data';

const _lcSegment64 = 0x19; // LC_SEGMENT_64
const _machoHeaderSize64 = 32; // sizeof(mach_header_64)
// Mach-O 64-bit header constants (from mach-o/loader.h).
const _machoMagic64 = 0xFEEDFACF; // MH_MAGIC_64

// iOS arm64 requires 16KB page alignment for all memory-mapped segments.
// Misaligned segments cause AMFI code signature validation failures on device.
const _pageSize = 16384;

/// Patches Mach-O segment sizes to be 16KB page-aligned for iOS arm64.
///
/// Zig's linker can emit non-page-aligned segment sizes, which iOS rejects
/// during code signature validation (AMFI). This rewrites `vmsize` and
/// `filesize` fields in LC_SEGMENT_64 load commands to match Apple's
/// alignment requirements.
void fixIosPageAlignment(File libFile) {
  final bytes = libFile.readAsBytesSync();
  final data = ByteData.sublistView(bytes);

  if (bytes.length < _machoHeaderSize64) return;

  // Offset 0: magic number identifies the binary format.
  final magic = data.getUint32(0, Endian.little);
  if (magic != _machoMagic64) return;

  // Offset 16: number of load commands following the header.
  final ncmds = data.getUint32(16, Endian.little);

  final segments = _collectSegments(data, ncmds);
  if (segments.isEmpty) return;

  final patched = _patchSegments(data, segments);
  if (!patched) return;

  // Write modified bytes back. ByteData shares the same buffer as `bytes`,
  // so the patched values are already in place.
  libFile.writeAsBytesSync(bytes);
}

/// Walks the Mach-O load command list and extracts all LC_SEGMENT_64 entries.
///
/// LC_SEGMENT_64 layout (offsets relative to command start):
///   +0:  cmd          (uint32, command type)
///   +4:  cmdsize      (uint32, total command size)
///   +8:  segname[16]  (null-padded segment name)
///   +24: vmaddr       (uint64, virtual memory address)
///   +32: vmsize       (uint64, virtual memory size)
///   +40: fileoff      (uint64, file offset)
///   +48: filesize     (uint64, file size)
List<_Segment> _collectSegments(ByteData data, int ncmds) {
  final segments = <_Segment>[];
  // Load commands start immediately after the Mach-O header.
  var offset = _machoHeaderSize64;

  for (var i = 0; i < ncmds; i++) {
    final cmd = data.getUint32(offset, Endian.little);
    final cmdsize = data.getUint32(offset + 4, Endian.little);

    if (cmd == _lcSegment64) {
      // Read the 16-byte null-padded segment name.
      final nameBytes = Uint8List.sublistView(
        data.buffer.asUint8List(),
        offset + 8,
        offset + 24,
      );
      final nullIndex = nameBytes.indexOf(0);
      final name = String.fromCharCodes(
        nullIndex >= 0 ? nameBytes.sublist(0, nullIndex) : nameBytes,
      );

      segments.add(
        _Segment(
          cmdOffset: offset,
          name: name,
          vmaddr: data.getUint64(offset + 24, Endian.little),
          vmsize: data.getUint64(offset + 32, Endian.little),
          fileoff: data.getUint64(offset + 40, Endian.little),
          filesize: data.getUint64(offset + 48, Endian.little),
        ),
      );
    }

    // Advance to the next load command.
    offset += cmdsize;
  }

  return segments;
}

/// Adjusts vmsize and filesize of each segment to satisfy iOS page alignment.
///
/// Three cases:
/// - `__LINKEDIT`: round vmsize up to page boundary; preserve filesize since
///   it maps code signature data and must match the actual file content.
/// - Consecutive segments: derive sizes from the gap to the next segment's
///   address. This ensures segments tile the virtual address space without
///   gaps or overlaps.
/// - Last segment (non-LINKEDIT): round both sizes up to page boundary.
bool _patchSegments(ByteData data, List<_Segment> segments) {
  var changed = false;

  for (var i = 0; i < segments.length; i++) {
    final seg = segments[i];
    int newVmsize;
    int newFilesize;

    if (seg.name == '__LINKEDIT') {
      // __LINKEDIT contains the code signature. Expanding filesize would
      // invalidate the signature, so only align vmsize.
      newVmsize = _roundUp(seg.vmsize, _pageSize);
      newFilesize = seg.filesize;
    } else if (i + 1 < segments.length) {
      // For consecutive segments, sizes are the distance to the next segment.
      // This guarantees page-aligned boundaries between segments.
      final next = segments[i + 1];
      newVmsize = next.vmaddr - seg.vmaddr;
      newFilesize = next.fileoff - seg.fileoff;
    } else {
      newVmsize = _roundUp(seg.vmsize, _pageSize);
      newFilesize = _roundUp(seg.filesize, _pageSize);
    }

    // Patch vmsize at offset +32 from the load command start.
    if (newVmsize != seg.vmsize) {
      data.setUint64(seg.cmdOffset + 32, newVmsize, Endian.little);
      changed = true;
    }
    // Patch filesize at offset +48 from the load command start.
    if (newFilesize != seg.filesize) {
      data.setUint64(seg.cmdOffset + 48, newFilesize, Endian.little);
      changed = true;
    }
  }

  return changed;
}

/// Rounds [value] up to the nearest multiple of [alignment].
int _roundUp(int value, int alignment) {
  return (value + alignment - 1) & ~(alignment - 1);
}

class _Segment {
  final int cmdOffset;
  final String name;
  final int vmaddr;
  final int vmsize;
  final int fileoff;
  final int filesize;

  _Segment({
    required this.cmdOffset,
    required this.name,
    required this.vmaddr,
    required this.vmsize,
    required this.fileoff,
    required this.filesize,
  });
}
