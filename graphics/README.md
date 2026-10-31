# Vithanco logo

These files are the Vithanco logo. They are **not** under the Apache-2.0 licence
that covers the rest of the repository. Vithanco owns the artwork, and all
rights are reserved.

| File | What it is |
|---|---|
| `Logo.svg`, `Logo.png` | The logo with the name |
| `Logo squared.png`, `Logo squared 128px.png` | Square crops for avatars and listings |
| `VLogoOnly.svg` | The V mark alone |
| `VLogoText.svg` | The name alone |

The same artwork appears elsewhere in the repository, with the same terms:

- the mark's path data in `Sources/VGraphSVG/Utils/WatermarkRenderer.swift` and
  in the `vithanco` icon of `Sources/VGraph/Domain/Icons/BuiltinIcons.swift`;
- the master copy of that path in `docs/design/Diagram Style Guide.html`, and
  the logo assets the guide loads, which are generated from the same original;
- the watermark in every exported diagram, and in the compiled WebAssembly
  module the plugins ship.

## Allowed

- Linking to the project, and referring to it in articles, talks, listings and
  documentation, with the logo unaltered.
- Leaving the watermark in diagrams you export. It credits the project.
- Switching the watermark off with `watermark: false` (see the
  [VGL Guide](../docs/VGL_GUIDE.md)).

## Not allowed

- Presenting a fork or a derived product as the Vithanco project.
- Using the name or the logo as the mark of another product or service.
- Altering the logo, or copying it into other works, without written permission.

A fork keeps the code licence but should use a name and a logo of its own.
