// Resolve a drag-dropped File to a path an agent can actually read.
//
// Normal drops resolve via pathForFile and are returned untouched. The macOS
// screenshot floating thumbnail is the exception: its path points into a
// TCC-protected, ephemeral .../T/TemporaryItems/NSIRD_screencaptureui_*/ dir
// that returns EPERM on read even with the command sandbox fully disabled, and
// is deleted when the thumbnail dismisses. At drop time the File's BYTES are
// still readable in the renderer, so stash them to a readable temp file over
// IPC and attach by that path instead. Returns '' when nothing usable exists.
const UNREADABLE = ['/TemporaryItems/', 'NSIRD_screencaptureui'];

export async function resolveDroppedPath(f: File): Promise<string> {
  const p = window.cth.pathForFile(f);
  if (p && !UNREADABLE.some((s) => p.includes(s))) return p;
  try {
    const bytes = new Uint8Array(await f.arrayBuffer());
    // Chunked encode: String.fromCharCode(...allBytes) overflows the argument
    // stack on multi-MB screenshots.
    let bin = '';
    const CHUNK = 0x8000;
    for (let i = 0; i < bytes.length; i += CHUNK) {
      bin += String.fromCharCode(...bytes.subarray(i, i + CHUNK));
    }
    const res = await window.cth.stashDroppedFile(f.name, btoa(bin));
    return res.ok ? res.file.path : '';
  } catch {
    return '';
  }
}
