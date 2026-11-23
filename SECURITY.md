# Security Policy

SnapText processes screenshots that may contain sensitive information (codes, account numbers, Wi-Fi passwords), so security reports are taken seriously.

## Reporting a vulnerability
**Please don't open a public issue.** Report privately via GitHub: go to the **Security** tab of this repository and click **Report a vulnerability**.

Include the affected version or commit, steps to reproduce, and the impact. You'll get an acknowledgement within 7 days.

## Scope
- Any path where scanned images or text could leave the device without the user's explicit action
- Data exposure through the Share Extension, clipboard or local history
- Unsafe handling of detected URLs, Wi-Fi configs or QR payloads

## Supported versions
Only the latest commit on `main` is supported.
