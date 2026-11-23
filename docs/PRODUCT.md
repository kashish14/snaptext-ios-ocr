# Product Vision

## One line
Convert anything visible into instantly usable text, in one tap.

> Screenshot → Copy → Done, in under 2 seconds.

## The problem
Getting text out of an image is slow and scattered:
- Copying from screenshots of chats, reels, PDFs and slides takes several steps.
- Pulling out a link, address, UPI ID or tracking number means retyping it.
- Existing tools are document scanners, live inside one app, or need an account.

## Who it's for
| User | Typical use |
|------|-------------|
| Students | Notes, whiteboards, textbook pages, PDFs |
| Professionals | Emails, addresses, business details, receipts |
| Creators | Captions, scripts, quotes |
| Everyone | Links, codes, Wi-Fi passwords, tracking numbers |

## Principles
1. **One primary action.** The main call to action is always *Copy*.
2. **Fast.** Target under 2 seconds from share to clipboard.
3. **Private.** OCR and detection run 100% on-device. Images and text never leave the phone.
4. **Offline.** Every core feature works without a network connection.
5. **No friction.** No login, no mandatory onboarding, no paywall.
6. **Smart, not noisy.** Show the 3–5 most relevant actions; everything else sits under "Do more".

## Core flows
**Share Extension (primary)**
```
Screenshot → Share → SnapText → OCR → copied to clipboard → feedback → dismiss
```

**In-app**
```
Capture (camera / gallery / document / QR) → OCR → detect entities → ranked actions → copy / act / open a tool
```

## Data policy
- Uses Apple Vision on-device; no images are stored on any server.
- History is local (SwiftData) and user-clearable.
- No analytics or third-party SDKs.

## Success signals
- Time from share to clipboard
- Scans per active user per day
- Share Extension usage versus in-app capture
- Actions taken on detected entities

See [ROADMAP.md](../ROADMAP.md) for what's shipped and what's next.
