
# NDICamStarter (iOS, Front Camera + Microphone → NDI)

Minimal UIKit sample that captures **front camera** (BGRA) and **microphone** (48 kHz, float32 planar) and sends them over **NDI** using the official NDI C API via a tiny ObjC++ wrapper.

> The NDI static library is stored with Git LFS. SDK headers must still be installed and configured to build.

## Git LFS

Install Git LFS before cloning this repository (on macOS: `brew install git-lfs`),
then run `git lfs install`. Git will automatically download
`NDICamStarter/libndi_advanced_ios.a` when checking out the project.
For an existing checkout, run `git lfs pull` from the project root.

The `.gitattributes` file tracks this library with LFS so that future SDK updates
also use LFS. Do not add the library to `.gitignore`.

## Requires
- Xcode 14+ / iOS 15+
- Real device (camera/mic; Simulator not supported)
- NDI® Advanced SDK for iOS (from Vizrt/NewTek)

## Setup
1. Create an empty iOS App project in Xcode named **NDICamStarter** (UIKit, Swift).
2. Add these source files into the project, preserving folders (`Capture/`, `NDI/`).
3. Add **NDICam-Bridging-Header.h** to the project and set:
   - **Build Settings → Objective‑C Bridging Header**: `$(SRCROOT)/NDICamStarter/NDICam-Bridging-Header.h`
4. Add NDI SDK to the project:
   - Drag the headers (e.g., `Processing.NDI.Lib.h`) and `libndi_ios.a` (or the provided iOS library) into the project.
   - **Header Search Paths**: point to the SDK include folder.
   - **Library Search Paths**: point to the SDK lib folder.
   - **Other Linker Flags**: add `-lc++ -ObjC`
   - **Enable Bitcode**: `No`
5. **Info.plist** already includes:
   - `NSCameraUsageDescription`
   - `NSMicrophoneUsageDescription`
   - `NSLocalNetworkUsageDescription`
   - `NSBonjourServices` with `_ndi._tcp`
6. On first run, accept **Camera**, **Microphone**, and **Local Network** permissions.

## Use
- Launch the app → tap **Start NDI**.
- Open an NDI viewer (e.g., Studio Monitor) on the same LAN, select the source named like “`<Your iPhone> FrontCam`”.

## Notes
- Video format: BGRA 720p by default (change `sessionPreset` if needed).
- Audio: AVAudioEngine → 48kHz float32 planar (converter inside `AudioCapture`).
- Timecode: Frames use CMSampleBuffer PTS; audio uses current monotonic time for simplicity.
- If you see black video or no audio in the viewer, confirm SDK linkage and local network permission.
- To flip mirroring to the NDI output, set `isVideoMirrored = false` on the video connection.

## License
For demo/testing purposes. NDI® is a registered trademark of Vizrt Group.
