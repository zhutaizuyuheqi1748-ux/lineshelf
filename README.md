# LineShelf (晾架)

An experimental macOS file shelf based on [Tendedero](https://github.com/alejandrobujan/tendedero), by Alejandro Buján. LineShelf keeps the original screenshot and screen-recording inlets and adds two ways to keep recently received files within reach.

This is an independent fork, with its own name, icon, bundle identifier and storage folders. It is not an official Tendedero release and is not endorsed by its author. The upstream documentation retained under `docs/` describes the original project.

## Two file inlets

### Drop files from other applications

Drag a local file from another application toward the top of the screen, move into the shelf when it appears, and release. LineShelf keeps a local copy so that a source application's temporary file can disappear without losing the shelf copy.

Messaging apps such as Telegram or WhatsApp are examples of the intended workflow: keep an attachment on the shelf, then drag it into the next application, without first putting it on the Desktop. Compatibility depends on the source application providing a standard macOS file URL or file promise. These two named applications have not been individually tested; this is not an integration with their accounts, messages or APIs.

### Find new downloads and AirDrop files quickly

New files arriving in the top level of the user's Downloads folder appear on the shelf. This includes browser downloads and AirDrop files when they are saved there. Files stay in their original location. The app does not intercept network traffic or implement the AirDrop protocol.

The Downloads inlet is on by default in this experimental fork and can be turned off from the menu bar. It ignores files already present when the watcher starts. Existing screenshot, screen-recording and optional clipboard-image inlets remain available.

## Using the shelf

- Images and MP4/MOV files use previews; other file types show an icon and filename.
- Click to copy the file, double-click to open it, or long-press an ordinary file for Quick Look.
- Drag a card into another application or a folder using the original app's file-dragging behavior.
- For a download, **Take down** only removes its card. **Move to Trash**, or dropping it on the Trash, deletes the original recoverably.
- For a manually imported copy, the corner cross trashes the shelf copy; the source file remains unchanged.
- Capacity eviction removes imported copies from the visible shelf without silently deleting them. This fork defaults to 50 cards.

## Build and check

Requires macOS 14 or later and a compatible Swift toolchain. Xcode is optional.

```sh
git clone --branch feature/file-inlets https://github.com/zhutaizuyuheqi1748-ux/lineshelf.git
cd lineshelf
scripts/build-lineshelf.sh
scripts/test-lineshelf.sh
open build/晾架.app
```

`build-lineshelf.sh` creates an ad-hoc signed app for the current machine's architecture. The original `build-app.sh` is retained as upstream source history; use the LineShelf script for this modified version. macOS may ask for access to Downloads, Desktop or a selected folder.

Do not run both applications' screenshot-handling modes simultaneously: they share macOS screenshot destination settings. Quit one before using the other. This repository publishes source code; it does not contain a notarized release binary.

## Storage and privacy

- Captures: `~/Library/Application Support/LineShelf/Screenshots`
- Imported file copies: `~/Library/Application Support/LineShelf/DroppedFiles`
- Downloads: remain in Downloads; watching does not copy or move them.
- Preferences domain: `local.lineshelf.app`

No chat-account access, background chat-history scanning, analytics or network service is added. The published changes contain source code, synthetic test fixtures generated at runtime, and documentation. Personal files, local preferences, logs, recordings, build artifacts and machine-specific home paths are excluded.

## Current scope and limitations

This branch is based on upstream commit `7d60f230ba3212a7cc0e8ba4b7dd60f44fdadd60` (the 1.5-era source used for the prototype), not the latest upstream main. It is an implementation for discussion, not a ready-to-merge upstream patch.

- Download scans run every 1.5 seconds. Common temporary extensions and aria2 control files are skipped; size and modification metadata must remain stable for three seconds. A long pause while writing a final filename can still look like completion.
- The watcher does not backfill arrivals that happened while the app was closed. It watches the default Downloads location, not arbitrary custom browser destinations or chat databases.
- URL-only drags and chat text are outside scope. File promises are supported in code, but source-app compatibility needs further testing.
- Release builds, signing verification and six local checks passed on a real Mac. The checks cover historical-file exclusion, temporary/final renames, growing/deleted files, folders and aria2 sidecars, copying imports, and generic-file display/removal semantics.
- New-file pickup in Downloads was observed in the running application. A user confirmed successful direct file dragging from a messaging application. Telegram, WhatsApp and a device-to-device AirDrop transfer have not been separately verified.
- New feature text is provided in English and Simplified Chinese; additional translation review is needed before any upstream contribution.

If these workflows fit upstream's scope, the relevant feature changes can be rebased and proposed separately, without the fork's branding or personal build choices.

## License and attribution

Code is MIT licensed; see [LICENSE](LICENSE). The upstream name and icon are excluded from that license. LineShelf uses a separate name and a new icon. This implementation was developed with AI assistance and checked locally; the limitations above are part of its current test status.
