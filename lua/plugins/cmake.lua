-- CMake integration (cmake-tools.nvim) + `px new` project scaffolding.
--
-- Keys moved from <leader>c* to <leader>m*: the old ones shadowed LazyVim's
-- <leader>cr (rename), <leader>cd (line diagnostics) and <leader>cs (symbols),
-- in every language. They are also scoped to C/C++/CMake buffers now.

-- Prefer lldb-dap when installed; otherwise reuse CodeLLDB (installed by the clangd extra).
local lldb_dap = vim.fn.exepath("lldb-dap")
if lldb_dap == "" then
  lldb_dap = vim.fn.exepath("lldb-vscode") -- older LLVM name
end
local dap_type = lldb_dap ~= "" and "lldb" or "codelldb"

local TEMPLATES = {
  "standard  (Console / Core Systems / CTest unit tests)",
  "opengl    (Modern OpenGL 4.6 Core + GLAD 2 + GLFW 3)",
  "vulkan    (Vulkan 1.3/1.4 + GLFW 3 + GLM + SPIR-V)",
  "raylib    (Raylib 5/6 2D/3D Game & Multimedia Engine)",
  "sdl3      (SDL 3.x Modern Multimedia & Hardware Renderer)",
  "sdl2      (SDL 2.x Classic Cross-Platform Multimedia Engine)",
}

local C_FILETYPES = { "c", "cpp", "cmake" }

local function cmake_key(lhs, cmd, desc)
  return { lhs, "<cmd>" .. cmd .. "<cr>", ft = C_FILETYPES, desc = desc }
end

---Runs on the main loop after `px new` finishes.
local function open_created_project(lang, name, tpl, res)
  local out = (res.stdout or "") .. (res.stderr or "")

  -- `px` prints the project path; take the last output line that is a directory.
  local path
  for line in out:gmatch("[^\r\n]+") do
    local trimmed = vim.trim(line)
    if vim.fn.isdirectory(trimmed) == 1 then
      path = trimmed
    end
  end
  if not path then
    local fallback = vim.fn.expand("~/Programming/" .. lang .. "/" .. name)
    if vim.fn.isdirectory(fallback) == 1 then
      path = fallback
    end
  end
  if not path then
    return vim.notify("Could not create project " .. name .. "\n" .. out, vim.log.levels.ERROR)
  end

  vim.cmd("cd " .. vim.fn.fnameescape(path))
  local main_path = path .. "/" .. (lang == "cpp" and "src/main.cpp" or "src/main.c")
  if vim.fn.filereadable(main_path) == 1 then
    vim.cmd("edit " .. vim.fn.fnameescape(main_path))
  end
  vim.notify("Created and opened " .. tpl .. " project: " .. name, vim.log.levels.INFO)

  vim.system({ "cmake", "--preset", "debug" }, { cwd = path, text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify(
          "CMake configuration failed for " .. name .. "\n" .. (result.stderr or result.stdout or ""),
          vim.log.levels.ERROR
        )
        return
      end
      vim.notify("CMake configured; clangd can now resolve project headers", vim.log.levels.INFO)
      vim.cmd("LspRestart clangd")
    end)
  end)
end

local function new_project()
  vim.ui.select({ "cpp", "c" }, { prompt = "Select Language:" }, function(lang)
    if not lang then
      return
    end
    vim.ui.select(TEMPLATES, { prompt = "Select Architecture / Framework Template:" }, function(selected)
      if not selected then
        return
      end
      local tpl = selected:match("^(%S+)")
      vim.ui.input({ prompt = "Enter Project Name: " }, function(name)
        if not name or name == "" then
          return
        end
        if vim.fn.executable("px") == 0 then
          return vim.notify("`px` not found in PATH", vim.log.levels.ERROR)
        end
        -- Argument list + async: no shell-quoting problems with odd names, no UI freeze.
        vim.system({ "px", "new", lang, name, "-t", tpl }, { text = true }, function(res)
          vim.schedule(function()
            open_created_project(lang, name, tpl, res)
          end)
        end)
      end)
    end)
  end)
end

return {
  -- which-key group label for the new prefix
  {
    "folke/which-key.nvim",
    opts = { spec = { { "<leader>m", group = "cmake" } } },
  },

  -- lldb-dap adapter + launch entry (only when lldb-dap exists on this machine)
  {
    "mfussenegger/nvim-dap",
    optional = true,
    opts = function()
      if lldb_dap == "" then
        return
      end
      local dap = require("dap")
      dap.adapters.lldb = dap.adapters.lldb or { type = "executable", command = lldb_dap, name = "lldb" }
      for _, lang in ipairs({ "c", "cpp" }) do
        dap.configurations[lang] = dap.configurations[lang] or {}
        table.insert(dap.configurations[lang], {
          name = "Launch file (lldb-dap)",
          type = "lldb",
          request = "launch",
          program = function()
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/build/debug/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
          args = {},
        })
      end
    end,
  },

  {
    "Civitasv/cmake-tools.nvim",
    opts = {
      cmake_command = "cmake",
      cmake_regenerate_on_save = false,
      cmake_generate_options = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" },
      cmake_build_directory = "build/${variant:buildType}",
      cmake_soft_link_compile_commands = true,
      cmake_compile_commands_from_lsp = false,
      cmake_dap_configuration = {
        name = dap_type,
        type = dap_type,
        request = "launch",
        stopOnEntry = false,
        runInTerminal = true,
      },
      cmake_executor = {
        name = "quickfix",
        opts = {},
        default_opts = {
          quickfix = {
            show = "always",
            position = "belowright",
            size = 10,
            encoding = "utf-8",
            auto_close_when_success = true,
          },
        },
      },
      cmake_runner = {
        name = "terminal",
        opts = {},
        default_opts = {
          terminal = {
            name = "Main Terminal",
            prefix_name = "[CMakeRunner]: ",
            split_direction = "horizontal",
            split_size = 11,
            auto_close_when_success = false,
          },
        },
      },
    },
    keys = {
      cmake_key("<leader>mb", "CMakeBuild", "CMake Build"),
      cmake_key("<leader>mr", "CMakeRun", "CMake Run"),
      cmake_key("<leader>md", "CMakeDebug", "CMake Debug"),
      cmake_key("<leader>mT", "CMakeRunTest", "CMake Run Tests (CTest)"),
      cmake_key("<leader>mp", "CMakeSelectConfigurePreset", "CMake Select Preset"),
      cmake_key("<leader>mt", "CMakeSelectLaunchTarget", "CMake Select Launch Target"),
      cmake_key("<leader>mg", "CMakeGenerate", "CMake Generate"),
      cmake_key("<leader>ms", "CMakeStopRunner", "CMake Stop Runner"),
      { "<leader>mn", new_project, desc = "CMake New Project" }, -- global: usable from any buffer
    },
  },
}
