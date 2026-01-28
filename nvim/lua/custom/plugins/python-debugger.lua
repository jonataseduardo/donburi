-- Python debugging support using nvim-dap with a beautiful UI
return {
  {
    'mfussenegger/nvim-dap',
    dependencies = {
      -- Creates a beautiful debugger UI
      'rcarriga/nvim-dap-ui',

      -- Required dependency for nvim-dap-ui
      'nvim-neotest/nvim-nio',

      -- Installs the debug adapters for you
      'williamboman/mason.nvim',
      'jay-babu/mason-nvim-dap.nvim',

      -- Python specific debug adapter
      'mfussenegger/nvim-dap-python',
    },
    keys = {
      -- Basic debugging keymaps (using <leader>number instead of F keys)
      {
        '<leader>5',
        function()
          require('dap').continue()
        end,
        desc = '[5] Debug: Start/Continue',
      },
      {
        '<leader>1',
        function()
          require('dap').step_into()
        end,
        desc = '[1] Debug: Step Into',
      },
      {
        '<leader>2',
        function()
          require('dap').step_over()
        end,
        desc = '[2] Debug: Step Over',
      },
      {
        '<leader>3',
        function()
          require('dap').step_out()
        end,
        desc = '[3] Debug: Step Out',
      },
      {
        '<leader>4',
        function()
          require('dap').terminate()
        end,
        desc = '[4] Debug: Terminate',
      },
      {
        '<leader>7',
        function()
          require('dapui').toggle()
        end,
        desc = '[7] Debug: Toggle UI',
      },
      {
        '<leader>b',
        function()
          require('dap').toggle_breakpoint()
        end,
        desc = 'Debug: Toggle [B]reakpoint',
      },
      {
        '<leader>B',
        function()
          require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
        end,
        desc = 'Debug: Set Conditional [B]reakpoint',
      },
      {
        '<leader>Dm',
        function()
          require('dap-python').test_method()
        end,
        desc = '[D]ebug: Test [M]ethod',
      },
      {
        '<leader>Dc',
        function()
          require('dap-python').test_class()
        end,
        desc = '[D]ebug: Test [C]lass',
      },
      {
        '<leader>Ds',
        function()
          require('dap-python').debug_selection()
        end,
        mode = 'v',
        desc = '[D]ebug: [S]election',
      },
      {
        '<leader>Dr',
        function()
          require('dap').repl.toggle()
        end,
        desc = '[D]ebug: Toggle [R]EPL',
      },
      {
        '<leader>Dl',
        function()
          require('dap').run_last()
        end,
        desc = '[D]ebug: Run [L]ast',
      },
    },
    config = function()
      local dap = require 'dap'
      local dapui = require 'dapui'

      -- Helper function to get Python path (similar to lspconfig)
      local function get_python_path()
        -- First check for VIRTUAL_ENV (Python venv)
        local venv = os.getenv 'VIRTUAL_ENV'
        if venv then
          local venv_python = venv .. '/bin/python'
          if vim.fn.executable(venv_python) == 1 then
            return venv_python
          end
        end

        -- Then check for CONDA_PREFIX (active Conda environment)
        local conda = os.getenv 'CONDA_PREFIX'
        if conda then
          local conda_python = conda .. '/bin/python'
          if vim.fn.executable(conda_python) == 1 then
            return conda_python
          end
        end

        -- Fallback to system Python
        return vim.fn.exepath 'python3' or vim.fn.exepath 'python' or 'python'
      end

      -- Mason-nvim-dap setup - auto-installs debugpy
      require('mason-nvim-dap').setup {
        automatic_installation = true,
        handlers = {},
        ensure_installed = {
          'debugpy',
        },
      }

      -- Dap UI setup with a nice layout
      dapui.setup {
        icons = { expanded = '', collapsed = '', current_frame = '*' },
        controls = {
          icons = {
            pause = '',
            play = '',
            step_into = '',
            step_over = '',
            step_out = '',
            step_back = '',
            run_last = '',
            terminate = '',
            disconnect = '',
          },
        },
        layouts = {
          {
            -- Right panel: scopes, breakpoints, stacks, watches
            elements = {
              { id = 'scopes', size = 0.35 },
              { id = 'breakpoints', size = 0.15 },
              { id = 'stacks', size = 0.25 },
              { id = 'watches', size = 0.25 },
            },
            size = 0.33,
            position = 'right',
          },
          {
            -- Bottom panel: repl and console
            elements = {
              { id = 'repl', size = 0.5 },
              { id = 'console', size = 0.5 },
            },
            size = 0.27,
            position = 'bottom',
          },
        },
      }

      -- Configure breakpoint signs
      vim.fn.sign_define('DapBreakpoint', { text = '', texthl = 'DapBreakpoint', linehl = '', numhl = '' })
      vim.fn.sign_define('DapBreakpointCondition', { text = '', texthl = 'DapBreakpointCondition', linehl = '', numhl = '' })
      vim.fn.sign_define('DapLogPoint', { text = '', texthl = 'DapLogPoint', linehl = '', numhl = '' })
      vim.fn.sign_define('DapStopped', { text = '', texthl = 'DapStopped', linehl = 'DapStoppedLine', numhl = '' })
      vim.fn.sign_define('DapBreakpointRejected', { text = '', texthl = 'DapBreakpointRejected', linehl = '', numhl = '' })

      -- Set up highlight groups for breakpoints
      vim.api.nvim_set_hl(0, 'DapBreakpoint', { fg = '#e51400' })
      vim.api.nvim_set_hl(0, 'DapBreakpointCondition', { fg = '#f5c211' })
      vim.api.nvim_set_hl(0, 'DapLogPoint', { fg = '#61afef' })
      vim.api.nvim_set_hl(0, 'DapStopped', { fg = '#98c379' })
      vim.api.nvim_set_hl(0, 'DapStoppedLine', { bg = '#2e4d3d' })
      vim.api.nvim_set_hl(0, 'DapBreakpointRejected', { fg = '#656565' })

      -- Auto-open/close DAP UI
      dap.listeners.before.attach.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
        dapui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
        dapui.close()
      end

      -- Setup nvim-dap-python with the detected Python path
      local python_path = get_python_path()
      require('dap-python').setup(python_path)

      -- Add custom debug configurations for Python
      dap.configurations.python = dap.configurations.python or {}

      -- Add Launch with Arguments configuration
      table.insert(dap.configurations.python, {
        type = 'python',
        request = 'launch',
        name = 'Launch file with arguments',
        program = '${file}',
        args = function()
          local args_string = vim.fn.input 'Arguments: '
          return vim.split(args_string, ' ')
        end,
        pythonPath = python_path,
      })

      -- Add Django configuration
      table.insert(dap.configurations.python, {
        type = 'python',
        request = 'launch',
        name = 'Django',
        program = '${workspaceFolder}/manage.py',
        args = { 'runserver', '--noreload' },
        pythonPath = python_path,
        django = true,
      })

      -- Add FastAPI configuration
      table.insert(dap.configurations.python, {
        type = 'python',
        request = 'launch',
        name = 'FastAPI',
        module = 'uvicorn',
        args = function()
          local app_module = vim.fn.input('App module (e.g., main:app): ', 'main:app')
          return { app_module, '--reload' }
        end,
        pythonPath = python_path,
      })

      -- Add Attach to remote debugpy
      table.insert(dap.configurations.python, {
        type = 'python',
        request = 'attach',
        name = 'Attach to remote',
        connect = function()
          local host = vim.fn.input('Host (default: localhost): ', 'localhost')
          local port = tonumber(vim.fn.input('Port (default: 5678): ', '5678'))
          return { host = host, port = port }
        end,
        pathMappings = {
          {
            localRoot = vim.fn.getcwd(),
            remoteRoot = '.',
          },
        },
      })
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
