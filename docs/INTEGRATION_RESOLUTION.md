# Integration Resolution

The review branch is rebased conceptually onto the boot-reliability hotfix with the following resolution:

- keep the classic bundled player, boot diagnostics, and start-screen assertions from `main`;
- keep the screen-relative movement fix and garden-opening fix from the playability review;
- keep both sets of browser-smoke assertions;
- regenerate the public bundle from corrected source during verification and Pages packaging;
- retain the agent handoffs and community-test documentation.
