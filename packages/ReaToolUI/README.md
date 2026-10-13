# ReaToolUI

ReaToolUI is the product-neutral ReaImGui design-system package for ReaTools.
It owns the validated tokens, adapter, Components, Patterns, and contract code
originally prototyped inside ReaProjectLink. Its public Lua namespace is
`reaui`.

ReaProjectLink design-system tests and the Gallery load this package directly.
The former Product-local `design_*` implementation was removed after the full
core, Gallery, and product UI matrices passed against `reaui`. Product call
sites have not migrated, so the DS016 native gate remains in force.

With `packages/ReaToolUI/lib/?.lua` on `package.path`, consumers use:

```lua
local reaui = require("reaui")
local ui = reaui.create(ImGui, ctx, theme)
```

Product workflows, persistence, REAPER operations, Wwise or WAAPI operations,
and product-specific composition do not belong in this package.
