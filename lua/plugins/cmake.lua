return {
  {
    "mfussenegger/nvim-dap",
    optional = true,
    opts = function()
      local dap = require("dap")
      if not dap.adapters.lldb then
        dap.adapters.lldb = {
          type = "executable",
          command = "/usr/bin/lldb-dap",
          name = "lldb",
        }
      end
      for _, lang in ipairs({ "c", "cpp" }) do
        dap.configurations[lang] = dap.configurations[lang] or {}
        table.insert(dap.configurations[lang], {
          name = "Launch file (lldb-dap)",
          type = "lldb",
          request = "launch",
          program = function()
            local default_path = vim.fn.getcwd() .. "/build/debug/"
            return vim.fn.input("Path to executable: ", default_path, "file")
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
        name = "lldb",
        type = "lldb",
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
      { "<leader>cb", "<cmd>CMakeBuild<cr>", desc = "CMake Build" },
      { "<leader>cr", "<cmd>CMakeRun<cr>", desc = "CMake Run" },
      { "<leader>cd", "<cmd>CMakeDebug<cr>", desc = "CMake Debug" },
      { "<leader>cT", "<cmd>CMakeRunTest<cr>", desc = "CMake Run Tests (CTest)" },
      { "<leader>cp", "<cmd>CMakeSelectConfigurePreset<cr>", desc = "CMake Select Preset" },
      { "<leader>ct", "<cmd>CMakeSelectLaunchTarget<cr>", desc = "CMake Select Launch Target" },
      { "<leader>cg", "<cmd>CMakeGenerate<cr>", desc = "CMake Generate" },
      { "<leader>cs", "<cmd>CMakeStopRunner<cr>", desc = "CMake Stop Runner" },
      {
        "<leader>cn",
        function()
          vim.ui.select({ "cpp", "c" }, {
            prompt = "Select Language:",
          }, function(lang)
            if not lang then return end
            vim.ui.select({
              "standard  (Console / Core Systems / CTest unit tests)",
              "opengl    (Modern OpenGL 4.6 Core + GLAD 2 + GLFW 3)",
              "vulkan    (Vulkan 1.3/1.4 + GLFW 3 + GLM + SPIR-V)",
              "raylib    (Raylib 5/6 2D/3D Game & Multimedia Engine)",
              "sdl3      (SDL 3.x Modern Multimedia & Hardware Renderer)",
              "sdl2      (SDL 2.x Classic Cross-Platform Multimedia Engine)",
            }, {
              prompt = "Select Architecture / Framework Template:",
            }, function(selected)
              if not selected then return end
              local tpl = selected:match("^(%S+)")
              vim.ui.input({ prompt = "Enter Project Name: " }, function(name)
                if not name or name == "" then return end
                local cmd = string.format("px new %s %s -t %s", lang, name, tpl)
                local handle = io.popen(cmd .. " 2>&1")
                if not handle then
                  vim.notify("Failed to run " .. cmd, vim.log.levels.ERROR)
                  return
                end
                local output = handle:read("*a") or ""
                handle:close()

                local path = nil
                for line in output:gmatch("[^\r\n]+") do
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

                if path and vim.fn.isdirectory(path) == 1 then
                  vim.cmd("cd " .. vim.fn.fnameescape(path))
                  local main_file = lang == "cpp" and "src/main.cpp" or "src/main.c"
                  local main_path = path .. "/" .. main_file
                  if vim.fn.filereadable(main_path) == 1 then
                    vim.cmd("edit " .. vim.fn.fnameescape(main_path))
                  end
                  vim.notify("Created and opened " .. tpl .. " project: " .. name, vim.log.levels.INFO)
                  vim.system({ "cmake", "--preset", "debug" }, {
                    cwd = path,
                    text = true,
                  }, function(result)
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
                else
                  vim.notify("Could not create project " .. name .. "\n" .. output, vim.log.levels.ERROR)
                end
              end)
            end)
          end)
        end,
        desc = "CMake New Project",
      },
    },
  },
}
