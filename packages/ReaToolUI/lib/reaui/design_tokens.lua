local contract = require("reaui.design_contract")
local M = {}

M.CONTRACT_VERSION = contract.VERSION
M.CONTRACT_STATUS = contract.STATUS
M.SCHEMA_VERSION = 1
M.THEMES = { "light", "dark" }

-- Each leaf is a typed token. Primitive leaves contain literals, Semantic
-- leaves reference Primitive or equivalent Semantic tokens, and Component
-- leaves reference Semantic or same-component tokens.
M.registry = {
  primitive = {
    color = {
      neutral = {
        [0] = { type = "color", value = 0xffffffff },
        [50] = { type = "color", value = 0xf6f7f9ff },
        [100] = { type = "color", value = 0xebeef2ff },
        [200] = { type = "color", value = 0xd8dde4ff },
        [400] = { type = "color", value = 0x96a1adff },
        [600] = { type = "color", value = 0x586370ff },
        [700] = { type = "color", value = 0x39434eff },
        [800] = { type = "color", value = 0x20272fff },
        [900] = { type = "color", value = 0x181d23ff },
        [950] = { type = "color", value = 0x11161bff },
      },
      blue = {
        [300] = { type = "color", value = 0x8cc9c5ff },
        [400] = { type = "color", value = 0x67b3afff },
        [500] = { type = "color", value = 0x3d9693ff },
        [600] = { type = "color", value = 0x287a79ff },
        [700] = { type = "color", value = 0x205f60ff },
        [800] = { type = "color", value = 0x184a4cff },
      },
      red = {
        [300] = { type = "color", value = 0xffa0a6ff },
        [400] = { type = "color", value = 0xff7b84ff },
        [500] = { type = "color", value = 0xe25560ff },
        [700] = { type = "color", value = 0xb4232fff },
        [800] = { type = "color", value = 0x8f1d27ff },
      },
      green = {
        [400] = { type = "color", value = 0x5ad0a0ff },
        [700] = { type = "color", value = 0x176b4dff },
      },
      amber = {
        [400] = { type = "color", value = 0xf4bd4fff },
        [700] = { type = "color", value = 0x8a5a00ff },
      },
      transparent = { type = "color", value = 0x00000000 },
    },
    font_family = {
      system = { type = "font_family", value = "sans-serif" },
      monospace = { type = "font_family", value = "monospace" },
    },
    font_size = {
      [75] = { type = "logical_unit", value = 12 },
      [100] = { type = "logical_unit", value = 13 },
      [125] = { type = "logical_unit", value = 14 },
      [150] = { type = "logical_unit", value = 16 },
      [200] = { type = "logical_unit", value = 20 },
    },
    font_weight = {
      regular = { type = "font_weight", value = "regular" },
      bold = { type = "font_weight", value = "bold" },
    },
    space = {
      [0] = { type = "logical_unit", value = 0 },
      [1] = { type = "logical_unit", value = 4 },
      [2] = { type = "logical_unit", value = 8 },
      [3] = { type = "logical_unit", value = 12 },
      [4] = { type = "logical_unit", value = 16 },
      [5] = { type = "logical_unit", value = 20 },
      [6] = { type = "logical_unit", value = 24 },
      [8] = { type = "logical_unit", value = 32 },
      [10] = { type = "logical_unit", value = 40 },
      [12] = { type = "logical_unit", value = 48 },
      [16] = { type = "logical_unit", value = 64 },
    },
    size = {
      [3] = { type = "logical_unit", value = 12 },
      [4] = { type = "logical_unit", value = 16 },
      [6] = { type = "logical_unit", value = 24 },
      [7] = { type = "logical_unit", value = 28 },
      [8] = { type = "logical_unit", value = 32 },
      [10] = { type = "logical_unit", value = 40 },
      [12] = { type = "logical_unit", value = 48 },
      [20] = { type = "logical_unit", value = 80 },
      [24] = { type = "logical_unit", value = 96 },
      [30] = { type = "logical_unit", value = 120 },
      [50] = { type = "logical_unit", value = 200 },
      [55] = { type = "logical_unit", value = 220 },
      [80] = { type = "logical_unit", value = 320 },
      [90] = { type = "logical_unit", value = 360 },
      [140] = { type = "logical_unit", value = 560 },
      [180] = { type = "logical_unit", value = 720 },
    },
    border_width = {
      [1] = { type = "logical_unit", value = 1 },
      [2] = { type = "logical_unit", value = 2 },
    },
    stroke_width = {
      [1] = { type = "logical_unit", value = 1 },
      [2] = { type = "logical_unit", value = 2 },
    },
    optical_offset = {
      [1] = { type = "logical_unit", value = 1 },
      [2] = { type = "logical_unit", value = 2 },
    },
    radius = {
      [0] = { type = "logical_unit", value = 0 },
      [1] = { type = "logical_unit", value = 6 },
      [2] = { type = "logical_unit", value = 10 },
    },
  },
  semantic = {
    color = {
      text = {
        primary = {
          type = "color",
          themes = {
            light = "primitive.color.neutral.900",
            dark = "primitive.color.neutral.100",
          },
        },
        disabled = {
          type = "color",
          themes = {
            light = "primitive.color.neutral.600",
            dark = "primitive.color.neutral.400",
          },
        },
        secondary = {
          type = "color",
          themes = {
            light = "primitive.color.neutral.600",
            dark = "primitive.color.neutral.400",
          },
        },
      },
      surface = {
        canvas = {
          type = "color",
          themes = {
            light = "primitive.color.neutral.50",
            dark = "primitive.color.neutral.950",
          },
        },
        panel = {
          type = "color",
          themes = {
            light = "primitive.color.neutral.0",
            dark = "primitive.color.neutral.800",
          },
        },
      },
      focus = {
        ring = {
          type = "color",
          themes = {
            light = "primitive.color.blue.600",
            dark = "primitive.color.blue.400",
          },
        },
      },
      action = {
        primary = {
          background = {
            default = { type = "color", themes = {
              light = "primitive.color.blue.600", dark = "primitive.color.blue.400",
            } },
            hover = { type = "color", themes = {
              light = "primitive.color.blue.700", dark = "primitive.color.blue.300",
            } },
            pressed = { type = "color", themes = {
              light = "primitive.color.blue.800", dark = "primitive.color.blue.500",
            } },
          },
          foreground = { default = { type = "color", themes = {
            light = "primitive.color.neutral.0", dark = "primitive.color.neutral.950",
          } } },
          border = { default = { type = "color", themes = {
            light = "primitive.color.blue.600", dark = "primitive.color.blue.400",
          } } },
        },
        secondary = {
          background = {
            default = { type = "color", themes = {
              light = "primitive.color.neutral.0", dark = "primitive.color.neutral.800",
            } },
            hover = { type = "color", themes = {
              light = "primitive.color.neutral.100", dark = "primitive.color.neutral.700",
            } },
            pressed = { type = "color", themes = {
              light = "primitive.color.neutral.200", dark = "primitive.color.neutral.600",
            } },
          },
          foreground = { default = { type = "color", themes = {
            light = "primitive.color.neutral.900", dark = "primitive.color.neutral.100",
          } } },
          border = { default = { type = "color", themes = {
            light = "primitive.color.neutral.600", dark = "primitive.color.neutral.600",
          } } },
        },
        quiet = {
          background = {
            default = { type = "color", ref = "primitive.color.transparent" },
            hover = { type = "color", themes = {
              light = "primitive.color.neutral.100", dark = "primitive.color.neutral.700",
            } },
            pressed = { type = "color", themes = {
              light = "primitive.color.neutral.200", dark = "primitive.color.neutral.600",
            } },
          },
          foreground = { default = { type = "color", themes = {
            light = "primitive.color.neutral.900", dark = "primitive.color.neutral.100",
          } } },
          border = { default = { type = "color", ref = "primitive.color.transparent" } },
        },
        danger = {
          background = {
            default = { type = "color", themes = {
              light = "primitive.color.red.700", dark = "primitive.color.red.400",
            } },
            hover = { type = "color", themes = {
              light = "primitive.color.red.800", dark = "primitive.color.red.300",
            } },
            pressed = { type = "color", themes = {
              light = "primitive.color.red.800", dark = "primitive.color.red.500",
            } },
          },
          foreground = { default = { type = "color", themes = {
            light = "primitive.color.neutral.0", dark = "primitive.color.neutral.950",
          } } },
          border = { default = { type = "color", themes = {
            light = "primitive.color.red.700", dark = "primitive.color.red.400",
          } } },
        },
      },
      validation = {
        pending = { type = "color", ref = "semantic.color.text.secondary" },
        valid = { type = "color", themes = {
          light = "primitive.color.green.700", dark = "primitive.color.green.400",
        } },
        invalid = { type = "color", themes = {
          light = "primitive.color.red.700", dark = "primitive.color.red.400",
        } },
      },
      status = {
        neutral = { type = "color", ref = "semantic.color.text.secondary" },
        ready = { type = "color", ref = "semantic.color.validation.valid" },
        warning = { type = "color", themes = {
          light = "primitive.color.amber.700", dark = "primitive.color.amber.400",
        } },
        blocked = { type = "color", ref = "semantic.color.validation.invalid" },
      },
      input = {
        background = {
          default = { type = "color", themes = {
            light = "primitive.color.neutral.0", dark = "primitive.color.neutral.800",
          } },
          hover = { type = "color", themes = {
            light = "primitive.color.neutral.50", dark = "primitive.color.neutral.700",
          } },
          focused = { type = "color", themes = {
            light = "primitive.color.neutral.0", dark = "primitive.color.neutral.800",
          } },
          read_only = { type = "color", themes = {
            light = "primitive.color.neutral.100", dark = "primitive.color.neutral.900",
          } },
        },
        foreground = {
          default = { type = "color", ref = "semantic.color.text.primary" },
        },
        border = {
          default = { type = "color", themes = {
            light = "primitive.color.neutral.600", dark = "primitive.color.neutral.600",
          } },
          invalid = { type = "color", ref = "semantic.color.validation.invalid" },
        },
      },
    },
    typography = {
      title = {
        font_family = { type = "font_family", ref = "primitive.font_family.system" },
        font_size = { type = "logical_unit", ref = "primitive.font_size.200" },
        font_weight = { type = "font_weight", ref = "primitive.font_weight.bold" },
      },
      heading = {
        font_family = { type = "font_family", ref = "primitive.font_family.system" },
        font_size = { type = "logical_unit", ref = "primitive.font_size.150" },
        font_weight = { type = "font_weight", ref = "primitive.font_weight.bold" },
      },
      body = {
        font_family = { type = "font_family", ref = "primitive.font_family.system" },
        font_size = { type = "logical_unit", ref = "primitive.font_size.100" },
        font_weight = { type = "font_weight", ref = "primitive.font_weight.regular" },
      },
      label = {
        font_family = { type = "font_family", ref = "primitive.font_family.system" },
        font_size = { type = "logical_unit", ref = "primitive.font_size.100" },
        font_weight = { type = "font_weight", ref = "primitive.font_weight.regular" },
      },
      metadata = {
        font_family = { type = "font_family", ref = "primitive.font_family.system" },
        font_size = { type = "logical_unit", ref = "primitive.font_size.75" },
        font_weight = { type = "font_weight", ref = "primitive.font_weight.regular" },
      },
      code = {
        font_family = { type = "font_family", ref = "primitive.font_family.monospace" },
        font_size = { type = "logical_unit", ref = "primitive.font_size.100" },
        font_weight = { type = "font_weight", ref = "primitive.font_weight.regular" },
      },
    },
    space = {
      inline = {
        tight = { type = "logical_unit", ref = "primitive.space.1" },
        default = { type = "logical_unit", ref = "primitive.space.2" },
      },
      stack = {
        tight = { type = "logical_unit", ref = "primitive.space.2" },
        default = { type = "logical_unit", ref = "primitive.space.3" },
      },
      section = {
        default = { type = "logical_unit", ref = "primitive.space.4" },
        loose = { type = "logical_unit", ref = "primitive.space.6" },
      },
      region = {
        default = { type = "logical_unit", ref = "primitive.space.8" },
      },
      item = {
        horizontal = { type = "logical_unit", ref = "primitive.space.2" },
        vertical = { type = "logical_unit", ref = "primitive.space.1" },
      },
      container = {
        padding = { type = "logical_unit", ref = "primitive.space.4" },
      },
      page = {
        padding = { type = "logical_unit", ref = "primitive.space.5" },
      },
      indent = {
        default = { type = "logical_unit", ref = "primitive.space.5" },
      },
      control = {
        padding_x = { type = "logical_unit", ref = "primitive.space.3" },
        gap = { type = "logical_unit", ref = "primitive.space.2" },
        compact_gap = { type = "logical_unit", ref = "primitive.space.1" },
      },
    },
    size = {
      control = {
        medium = { type = "logical_unit", ref = "primitive.size.8" },
      },
      icon = {
        medium = { type = "logical_unit", ref = "primitive.size.4" },
      },
      field = {
        minimum_input = { type = "logical_unit", ref = "primitive.size.24" },
        inline_compact = { type = "logical_unit", ref = "primitive.size.55" },
        inline_wide = { type = "logical_unit", ref = "primitive.size.90" },
      },
      list = {
        compact = { type = "logical_unit", ref = "primitive.size.30" },
        standard = { type = "logical_unit", ref = "primitive.size.50" },
      },
      footer = {
        medium = { type = "logical_unit", ref = "primitive.size.20" },
      },
    },
    layout = {
      content = {
        max_width = { type = "logical_unit", ref = "primitive.size.180" },
      },
      preview = {
        compact = { type = "logical_unit", ref = "primitive.size.80" },
        standard = { type = "logical_unit", ref = "primitive.size.140" },
        wide = { type = "logical_unit", ref = "primitive.size.180" },
      },
    },
    border = {
      control = {
        width = { type = "logical_unit", ref = "primitive.border_width.1" },
      },
      emphasis = {
        width = { type = "logical_unit", ref = "primitive.border_width.2" },
      },
      focus = {
        width = { type = "logical_unit", ref = "primitive.border_width.2" },
      },
    },
    radius = {
      control = { type = "logical_unit", ref = "primitive.radius.1" },
      container = { type = "logical_unit", ref = "primitive.radius.2" },
      popup = { type = "logical_unit", ref = "primitive.radius.2" },
    },
    stroke = {
      icon = { type = "logical_unit", ref = "primitive.stroke_width.1" },
      emphasis = { type = "logical_unit", ref = "primitive.stroke_width.2" },
    },
    optical_offset = {
      small = { type = "logical_unit", ref = "primitive.optical_offset.1" },
      medium = { type = "logical_unit", ref = "primitive.optical_offset.2" },
    },
  },
  component = {
    button = {
      primary = {
        background = {
          default = { type = "color", ref = "semantic.color.action.primary.background.default" },
          hover = { type = "color", ref = "semantic.color.action.primary.background.hover" },
          pressed = { type = "color", ref = "semantic.color.action.primary.background.pressed" },
        },
        foreground = {
          default = { type = "color", ref = "semantic.color.action.primary.foreground.default" },
        },
        border = {
          default = { type = "color", ref = "semantic.color.action.primary.border.default" },
        },
      },
      secondary = {
        background = {
          default = { type = "color", ref = "semantic.color.action.secondary.background.default" },
          hover = { type = "color", ref = "semantic.color.action.secondary.background.hover" },
          pressed = { type = "color", ref = "semantic.color.action.secondary.background.pressed" },
        },
        foreground = {
          default = { type = "color", ref = "semantic.color.action.secondary.foreground.default" },
        },
        border = {
          default = { type = "color", ref = "semantic.color.action.secondary.border.default" },
        },
      },
      quiet = {
        background = {
          default = { type = "color", ref = "semantic.color.action.quiet.background.default" },
          hover = { type = "color", ref = "semantic.color.action.quiet.background.hover" },
          pressed = { type = "color", ref = "semantic.color.action.quiet.background.pressed" },
        },
        foreground = {
          default = { type = "color", ref = "semantic.color.action.quiet.foreground.default" },
        },
        border = {
          default = { type = "color", ref = "semantic.color.action.quiet.border.default" },
        },
      },
      danger = {
        background = {
          default = { type = "color", ref = "semantic.color.action.danger.background.default" },
          hover = { type = "color", ref = "semantic.color.action.danger.background.hover" },
          pressed = { type = "color", ref = "semantic.color.action.danger.background.pressed" },
        },
        foreground = {
          default = { type = "color", ref = "semantic.color.action.danger.foreground.default" },
        },
        border = {
          default = { type = "color", ref = "semantic.color.action.danger.border.default" },
        },
      },
    },
    field_shell = {
      label = {
        foreground = {
          default = { type = "color", ref = "semantic.color.text.primary" },
        },
      },
      description = {
        foreground = {
          default = { type = "color", ref = "semantic.color.text.secondary" },
        },
      },
      message = {
        pending = {
          foreground = { default = {
            type = "color", ref = "semantic.color.validation.pending",
          } },
        },
        valid = {
          foreground = { default = {
            type = "color", ref = "semantic.color.validation.valid",
          } },
        },
        invalid = {
          foreground = { default = {
            type = "color", ref = "semantic.color.validation.invalid",
          } },
        },
      },
    },
    input_control = {
      background = {
        default = { type = "color", ref = "semantic.color.input.background.default" },
        hover = { type = "color", ref = "semantic.color.input.background.hover" },
        focused = { type = "color", ref = "semantic.color.input.background.focused" },
        read_only = { type = "color", ref = "semantic.color.input.background.read_only" },
      },
      foreground = {
        default = { type = "color", ref = "semantic.color.input.foreground.default" },
      },
      border = {
        default = { type = "color", ref = "semantic.color.input.border.default" },
        invalid = { type = "color", ref = "semantic.color.input.border.invalid" },
      },
    },
    number_field = {
      layout = {
        inline_min_width = { type = "logical_unit", ref = "semantic.size.field.inline_compact" },
        minimum_input_width = { type = "logical_unit", ref = "semantic.size.field.minimum_input" },
      },
    },
    path_field = {
      layout = {
        inline_min_width = { type = "logical_unit", ref = "semantic.size.field.inline_wide" },
      },
    },
    checkbox = {
      background = {
        default = { type = "color", ref = "semantic.color.input.background.default" },
        hover = { type = "color", ref = "semantic.color.input.background.hover" },
        pressed = { type = "color", ref = "semantic.color.input.background.focused" },
      },
      foreground = {
        default = { type = "color", ref = "semantic.color.input.foreground.default" },
      },
      check_mark = {
        default = { type = "color", ref = "semantic.color.focus.ring" },
      },
      border = {
        default = { type = "color", ref = "semantic.color.input.border.default" },
        invalid = { type = "color", ref = "semantic.color.input.border.invalid" },
      },
    },
    dropdown = {
      background = {
        default = { type = "color", ref = "semantic.color.input.background.default" },
        hover = { type = "color", ref = "semantic.color.input.background.hover" },
        pressed = { type = "color", ref = "semantic.color.input.background.focused" },
      },
      foreground = {
        default = { type = "color", ref = "semantic.color.input.foreground.default" },
      },
      border = {
        default = { type = "color", ref = "semantic.color.input.border.default" },
        invalid = { type = "color", ref = "semantic.color.input.border.invalid" },
      },
      option = {
        selected = { type = "color", ref = "semantic.color.action.secondary.background.pressed" },
        hover = { type = "color", ref = "semantic.color.action.secondary.background.hover" },
        pressed = { type = "color", ref = "semantic.color.action.secondary.background.pressed" },
      },
    },
    segmented_control = {
      selected = {
        background = {
          default = { type = "color", ref = "semantic.color.action.primary.background.default" },
          hover = { type = "color", ref = "semantic.color.action.primary.background.hover" },
          pressed = { type = "color", ref = "semantic.color.action.primary.background.pressed" },
        },
        foreground = { type = "color", ref = "semantic.color.action.primary.foreground.default" },
        border = { type = "color", ref = "semantic.color.action.primary.border.default" },
      },
      unselected = {
        background = {
          default = { type = "color", ref = "semantic.color.action.secondary.background.default" },
          hover = { type = "color", ref = "semantic.color.action.secondary.background.hover" },
          pressed = { type = "color", ref = "semantic.color.action.secondary.background.pressed" },
        },
        foreground = { type = "color", ref = "semantic.color.action.secondary.foreground.default" },
        border = { type = "color", ref = "semantic.color.action.secondary.border.default" },
      },
      invalid = {
        border = { type = "color", ref = "semantic.color.input.border.invalid" },
      },
    },
    single_selection_list = {
      background = { type = "color", ref = "semantic.color.input.background.default" },
      foreground = { type = "color", ref = "semantic.color.input.foreground.default" },
      border = {
        default = { type = "color", ref = "semantic.color.input.border.default" },
        invalid = { type = "color", ref = "semantic.color.input.border.invalid" },
      },
      row = {
        selected = { type = "color", ref = "semantic.color.action.secondary.background.pressed" },
        hover = { type = "color", ref = "semantic.color.action.secondary.background.hover" },
        pressed = { type = "color", ref = "semantic.color.action.secondary.background.pressed" },
      },
      height = {
        compact = { type = "logical_unit", ref = "semantic.size.list.compact" },
        standard = { type = "logical_unit", ref = "semantic.size.list.standard" },
      },
    },
    card = {
      background = { type = "color", ref = "semantic.color.surface.panel" },
      border = {
        default = { type = "color", ref = "semantic.color.input.border.default" },
        emphasized = { type = "color", ref = "semantic.color.focus.ring" },
      },
      title = { type = "color", ref = "semantic.color.text.primary" },
      description = { type = "color", ref = "semantic.color.text.secondary" },
    },
    status = {
      neutral = { foreground = { type = "color", ref = "semantic.color.status.neutral" } },
      ready = { foreground = { type = "color", ref = "semantic.color.status.ready" } },
      warning = { foreground = { type = "color", ref = "semantic.color.status.warning" } },
      blocked = { foreground = { type = "color", ref = "semantic.color.status.blocked" } },
    },
    notice = {
      background = { type = "color", ref = "semantic.color.surface.panel" },
      neutral = { foreground = { type = "color", ref = "semantic.color.status.neutral" }, border = { type = "color", ref = "semantic.color.status.neutral" } },
      ready = { foreground = { type = "color", ref = "semantic.color.status.ready" }, border = { type = "color", ref = "semantic.color.status.ready" } },
      warning = { foreground = { type = "color", ref = "semantic.color.status.warning" }, border = { type = "color", ref = "semantic.color.status.warning" } },
      blocked = { foreground = { type = "color", ref = "semantic.color.status.blocked" }, border = { type = "color", ref = "semantic.color.status.blocked" } },
    },
    review_shell = {
      content = { max_width = { type = "logical_unit", ref = "semantic.layout.content.max_width" } },
      footer = { height = { type = "logical_unit", ref = "semantic.size.footer.medium" } },
    },
  },
}

local THEME_SET = {}
for _, theme in ipairs(M.THEMES) do THEME_SET[theme] = true end

local function split_id(id)
  local segments = {}
  for segment in tostring(id):gmatch("[^.]+") do
    table.insert(segments, segment)
  end
  return segments
end

local function lookup(registry, id)
  local node = registry
  for _, segment in ipairs(split_id(id)) do
    if type(node) ~= "table" then return nil end
    node = node[segment] or node[tonumber(segment)]
    if node == nil then return nil end
  end
  if type(node) ~= "table" or type(node.type) ~= "string" then return nil end
  return node
end

local function collect(node, segments, entries, errors)
  if type(node) ~= "table" then
    table.insert(errors, table.concat(segments, ".") .. " must be a token table")
    return
  end
  if node.type ~= nil then
    local id = table.concat(segments, ".")
    if #segments < 3 then table.insert(errors, id .. " must have at least three segments") end
    entries[id] = node
    return
  end
  for key, child in pairs(node) do
    local next_segments = {}
    for index, segment in ipairs(segments) do next_segments[index] = segment end
    table.insert(next_segments, tostring(key))
    collect(child, next_segments, entries, errors)
  end
end

local function entries_for(registry)
  local entries, errors = {}, {}
  for _, layer in ipairs({ "primitive", "semantic", "component" }) do
    if type(registry[layer]) ~= "table" then
      table.insert(errors, "missing layer " .. layer)
    else
      collect(registry[layer], { layer }, entries, errors)
    end
  end
  return entries, errors
end

local function literal_matches(value_type, value)
  if value_type == "color" then
    return type(value) == "number" and math.type(value) == "integer" and
      value >= 0 and value <= 0xffffffff
  end
  if value_type == "font_family" then return type(value) == "string" and value ~= "" end
  if value_type == "font_weight" then return value == "regular" or value == "bold" end
  if value_type == "logical_unit" then return type(value) == "number" and value >= 0 end
  return false
end

local function reference_for(entry, theme)
  if entry.ref then return entry.ref end
  if entry.themes then return entry.themes[theme] end
  return nil
end

local function reference_allowed(id, target_id)
  local layer = split_id(id)[1]
  local target = split_id(target_id)
  if layer == "semantic" then return target[1] == "primitive" or target[1] == "semantic" end
  if layer == "component" then
    if target[1] == "semantic" then return true end
    return target[1] == "component" and split_id(id)[2] == target[2]
  end
  return false
end

function M.validate(registry)
  registry = registry or M.registry
  local entries, errors = entries_for(registry)
  local seen_errors = {}
  local function add(message)
    if not seen_errors[message] then
      seen_errors[message] = true
      table.insert(errors, message)
    end
  end

  for id, entry in pairs(entries) do
    local layer = split_id(id)[1]
    if layer == "primitive" then
      if entry.ref or entry.themes then add(id .. " primitive token cannot reference another token") end
      if not literal_matches(entry.type, entry.value) then
        add(id .. " has an invalid " .. tostring(entry.type) .. " literal")
      end
    else
      if entry.value ~= nil then add(id .. " non-primitive token cannot contain a literal") end
      if entry.ref and entry.themes then add(id .. " cannot define both ref and themes") end
      if not entry.ref and not entry.themes then add(id .. " must define ref or themes") end
      if entry.themes then
        for _, theme in ipairs(M.THEMES) do
          if not entry.themes[theme] then add(id .. " is missing theme " .. theme) end
        end
        for theme in pairs(entry.themes) do
          if not THEME_SET[theme] then add(id .. " defines unknown theme " .. tostring(theme)) end
        end
      end
    end
  end

  for id, entry in pairs(entries) do
    for _, theme in ipairs(M.THEMES) do
      local target_id = reference_for(entry, theme)
      if target_id then
        local target = entries[target_id]
        if not target then
          add(id .. " references unknown token " .. tostring(target_id))
        else
          if not reference_allowed(id, target_id) then
            add(id .. " has an invalid reference to " .. target_id)
          end
          if entry.type ~= target.type then
            add(id .. " type " .. entry.type .. " does not match " .. target_id .. " type " .. target.type)
          end
        end
      end
    end
  end

  for _, theme in ipairs(M.THEMES) do
    local visiting, visited = {}, {}
    local function visit(id)
      if visiting[id] then
        add("reference cycle for " .. theme .. " at " .. id)
        return
      end
      if visited[id] then return end
      visiting[id] = true
      local entry = entries[id]
      local target_id = entry and reference_for(entry, theme)
      if target_id and entries[target_id] then visit(target_id) end
      visiting[id] = nil
      visited[id] = true
    end
    for id in pairs(entries) do visit(id) end
  end

  table.sort(errors)
  return errors
end

local function resolve_from(registry, id, theme, visiting)
  local entry = lookup(registry, id)
  if not entry then return nil, "unknown token " .. tostring(id) end
  if entry.value ~= nil then return entry.value end
  if visiting[id] then return nil, "reference cycle at " .. id end
  visiting[id] = true
  local target_id = reference_for(entry, theme)
  if not target_id then
    visiting[id] = nil
    return nil, id .. " has no value for theme " .. theme
  end
  local value, err = resolve_from(registry, target_id, theme, visiting)
  visiting[id] = nil
  return value, err
end

function M.resolve(id, theme, registry)
  if not THEME_SET[theme] then return nil, "unknown theme " .. tostring(theme) end
  return resolve_from(registry or M.registry, id, theme, {})
end

function M.ids(registry)
  local entries = entries_for(registry or M.registry)
  local ids = {}
  for id in pairs(entries) do table.insert(ids, id) end
  table.sort(ids)
  return ids
end

function M.validate_product_references(ids)
  local errors = {}
  for _, id in ipairs(ids) do
    if tostring(id):match("^primitive%.") then
      table.insert(errors, "product code cannot reference " .. id)
    end
  end
  return errors
end

return M
