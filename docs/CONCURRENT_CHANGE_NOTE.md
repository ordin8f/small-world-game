# Concurrent Release Changes

The initial community build and its boot-reliability hotfix were developed in parallel with the playability review.

The final integration must preserve both:

- classic-script bundle generation, boot diagnostics, and start-screen smoke assertions;
- corrected screen-relative horizontal movement, a traversable garden opening, and their regression coverage.

No integration should resolve the overlap by discarding either release path.
