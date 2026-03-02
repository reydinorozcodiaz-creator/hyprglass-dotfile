return {
  -- DAP: Debugger (breakpoints, variables, call stack como VS Code)
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      -- DAP UI: interfaz visual del debugger
      {
        "rcarriga/nvim-dap-ui",
        dependencies = { "nvim-neotest/nvim-nio" },
        config = function()
          local dapui = require("dapui")
          dapui.setup()

          -- Abrir/cerrar UI automáticamente al iniciar/detener debug
          local dap = require("dap")
          dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
          dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
          dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end
        end,
      },
      -- Instala adapters de debug automáticamente via Mason
      {
        "jay-babu/mason-nvim-dap.nvim",
        dependencies = { "williamboman/mason.nvim" },
        config = function()
          require("mason-nvim-dap").setup({
            ensure_installed = { "python", "node2", "bash" },
            automatic_installation = true,
          })
        end,
      },
      -- Textos virtuales con valores de variables mientras debugeas
      {
        "theHamsta/nvim-dap-virtual-text",
        config = function()
          require("nvim-dap-virtual-text").setup()
        end,
      },
    },
    config = function()
      local dap = require("dap")

      -- Signos visuales (como VS Code: círculo rojo = breakpoint)
      vim.fn.sign_define("DapBreakpoint",          { text = "●", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "◐", texthl = "DiagnosticWarn" })
      vim.fn.sign_define("DapStopped",             { text = "▶", texthl = "DiagnosticInfo" })

      -- Keymaps estilo VS Code
      vim.keymap.set("n", "<F5>",       dap.continue,          { desc = "Debug: Continue" })
      vim.keymap.set("n", "<F10>",      dap.step_over,         { desc = "Debug: Step Over" })
      vim.keymap.set("n", "<F11>",      dap.step_into,         { desc = "Debug: Step Into" })
      vim.keymap.set("n", "<F12>",      dap.step_out,          { desc = "Debug: Step Out" })
      vim.keymap.set("n", "<F9>",       dap.toggle_breakpoint, { desc = "Debug: Toggle Breakpoint" })
      vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Debug: Toggle Breakpoint" })
      vim.keymap.set("n", "<leader>dc", dap.continue,          { desc = "Debug: Continue" })
      vim.keymap.set("n", "<leader>du", function() require("dapui").toggle() end, { desc = "Debug: Toggle UI" })
      vim.keymap.set("n", "<leader>dt", dap.terminate,         { desc = "Debug: Terminate" })
    end,
  },
}
