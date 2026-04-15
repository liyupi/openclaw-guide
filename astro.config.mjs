import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://www.clawfather.cn',
  vite: {
    plugins: [{
      name: 'script-mime-types',
      configureServer(server) {
        server.middlewares.use((req, res, next) => {
          if (req.url?.endsWith('.ps1') || req.url?.endsWith('.sh')) {
            res.setHeader('Content-Type', 'text/plain; charset=utf-8');
          }
          next();
        });
      },
    }],
  },
  integrations: [
    sitemap(),
    starlight({
      title: 'OpenClaw 中文网',
      logo: {
        src: '/assets/pixel-lobster.svg',
      },
      favicon: '/assets/pixel-lobster.svg',
      defaultLocale: 'root',
      locales: {
        root: { label: '简体中文', lang: 'zh-CN' },
      },
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/openclaw/openclaw' },
      ],
      head: [
        {
          tag: 'script',
          content: `
            var _hmt = _hmt || [];
            (function() {
              var hm = document.createElement("script");
              hm.src = "https://hm.baidu.com/hm.js?80f7cad1898324dd4b46dfd20ece8035";
              var s = document.getElementsByTagName("script")[0];
              s.parentNode.insertBefore(hm, s);
            })();
          `,
        },
      ],
      customCss: [
        './src/styles/custom.css',
      ],
      components: {
        Header: './src/overrides/Header.astro',
        Footer: './src/overrides/Footer.astro',
      },
      expressiveCode: {
        themes: ['min-dark', 'min-light'],
      },
      sidebar: [
      {
        label: '首页',
        items: [
        { slug: 'docs-home' }
        ],
      },
      {
        label: '概览',
        items: [
        { slug: 'start/showcase' }
        ],
      },
      {
        label: '核心概念',
        items: [
        { slug: 'concepts/features' }
        ],
      },
      {
        label: '第一步',
        items: [
        { slug: 'start/getting-started' },
        { slug: 'start/onboarding-overview' },
        { slug: 'start/wizard' },
        { slug: 'start/onboarding' }
        ],
      },
      {
        label: '指南',
        items: [
        { slug: 'start/openclaw' },
        { slug: 'start/wizard-cli-reference' },
        { slug: 'start/wizard-cli-automation' }
        ],
      },
      {
        label: '安装概览',
        items: [
        { slug: 'install' },
        { slug: 'install/installer' }
        ],
      },
      {
        label: '安装方式',
        items: [
        { slug: 'install/docker' },
        { slug: 'install/podman' },
        { slug: 'install/nix' },
        { slug: 'install/ansible' },
        { slug: 'install/bun' }
        ],
      },
      {
        label: '维护',
        items: [
        { slug: 'install/updating' },
        { slug: 'install/migrating' },
        { slug: 'install/uninstall' }
        ],
      },
      {
        label: '托管与部署',
        items: [
        { slug: 'vps' },
        { slug: 'install/fly' },
        { slug: 'install/hetzner' },
        { slug: 'install/gcp' },
        { slug: 'install/macos-vm' },
        { slug: 'install/exe-dev' },
        { slug: 'install/railway' },
        { slug: 'install/render' },
        { slug: 'install/northflank' }
        ],
      },
      {
        label: '高级',
        items: [
        { slug: 'install/development-channels' }
        ],
      },
      {
        label: '概览',
        items: [
        { slug: 'channels' }
        ],
      },
      {
        label: '消息平台',
        items: [
        { slug: 'channels/bluebubbles' },
        { slug: 'channels/discord' },
        { slug: 'channels/feishu' },
        { slug: 'channels/googlechat' },
        { slug: 'channels/imessage' },
        { slug: 'channels/irc' },
        { slug: 'channels/line' },
        { slug: 'channels/matrix' },
        { slug: 'channels/mattermost' },
        { slug: 'channels/msteams' },
        { slug: 'channels/nextcloud-talk' },
        { slug: 'channels/nostr' },
        { slug: 'channels/signal' },
        { slug: 'channels/synology-chat' },
        { slug: 'channels/slack' },
        { slug: 'channels/telegram' },
        { slug: 'channels/tlon' },
        { slug: 'channels/twitch' },
        { slug: 'channels/whatsapp' },
        { slug: 'channels/zalo' },
        { slug: 'channels/zalouser' }
        ],
      },
      {
        label: '配置',
        items: [
        { slug: 'channels/pairing' },
        { slug: 'channels/group-messages' },
        { slug: 'channels/groups' },
        { slug: 'channels/broadcast-groups' },
        { slug: 'channels/channel-routing' },
        { slug: 'channels/location' },
        { slug: 'channels/troubleshooting' }
        ],
      },
      {
        label: '基础',
        items: [
        { slug: 'pi' },
        { slug: 'concepts/architecture' },
        { slug: 'concepts/agent' },
        { slug: 'concepts/agent-loop' },
        { slug: 'concepts/system-prompt' },
        { slug: 'concepts/context' },
        { slug: 'concepts/agent-workspace' },
        { slug: 'concepts/oauth' }
        ],
      },
      {
        label: '引导',
        items: [
        { slug: 'start/bootstrapping' }
        ],
      },
      {
        label: '会话与记忆',
        items: [
        { slug: 'concepts/session' },
        { slug: 'concepts/session-pruning' },
        { slug: 'concepts/session-tool' },
        { slug: 'concepts/memory' },
        { slug: 'concepts/compaction' }
        ],
      },
      {
        label: '多代理',
        items: [
        { slug: 'concepts/multi-agent' },
        { slug: 'concepts/presence' }
        ],
      },
      {
        label: '消息与投递',
        items: [
        { slug: 'concepts/messages' },
        { slug: 'concepts/streaming' },
        { slug: 'concepts/retry' },
        { slug: 'concepts/queue' }
        ],
      },
      {
        label: '概览',
        items: [
        { slug: 'tools' }
        ],
      },
      {
        label: '内置工具',
        items: [
        { slug: 'tools/apply-patch' },
        { slug: 'brave-search' },
        { slug: 'perplexity' },
        { slug: 'tools/diffs' },
        { slug: 'tools/pdf' },
        { slug: 'tools/elevated' },
        { slug: 'tools/exec' },
        { slug: 'tools/exec-approvals' },
        { slug: 'tools/firecrawl' },
        { slug: 'tools/llm-task' },
        { slug: 'tools/lobster' },
        { slug: 'tools/loop-detection' },
        { slug: 'tools/reactions' },
        { slug: 'tools/thinking' },
        { slug: 'tools/web' }
        ],
      },
      {
        label: '浏览器',
        items: [
        { slug: 'tools/browser' },
        { slug: 'tools/browser-login' },
        { slug: 'tools/chrome-extension' },
        { slug: 'tools/browser-linux-troubleshooting' }
        ],
      },
      {
        label: '代理协作',
        items: [
        { slug: 'tools/agent-send' },
        { slug: 'tools/subagents' },
        { slug: 'tools/acp-agents' },
        { slug: 'tools/multi-agent-sandbox-tools' }
        ],
      },
      {
        label: '技能',
        items: [
        { slug: 'tools/creating-skills' },
        { slug: 'tools/slash-commands' },
        { slug: 'tools/skills' },
        { slug: 'tools/skills-config' },
        { slug: 'tools/clawhub' },
        { slug: 'tools/plugin' }
        ],
      },
      {
        label: '扩展',
        items: [
        { slug: 'plugins/community' },
        { slug: 'plugins/voice-call' },
        { slug: 'plugins/zalouser' },
        { slug: 'plugins/manifest' },
        { slug: 'plugins/agent-tools' },
        { slug: 'prose' }
        ],
      },
      {
        label: '自动化',
        items: [
        { slug: 'automation/hooks' },
        { slug: 'automation/cron-jobs' },
        { slug: 'automation/cron-vs-heartbeat' },
        { slug: 'automation/troubleshooting' },
        { slug: 'automation/webhook' },
        { slug: 'automation/gmail-pubsub' },
        { slug: 'automation/poll' },
        { slug: 'automation/auth-monitoring' }
        ],
      },
      {
        label: '媒体与设备',
        items: [
        { slug: 'nodes' },
        { slug: 'nodes/troubleshooting' },
        { slug: 'nodes/media-understanding' },
        { slug: 'nodes/images' },
        { slug: 'nodes/audio' },
        { slug: 'nodes/camera' },
        { slug: 'nodes/talk' },
        { slug: 'nodes/voicewake' },
        { slug: 'nodes/location-command' },
        { slug: 'tts' }
        ],
      },
      {
        label: '概览',
        items: [
        { slug: 'providers' },
        { slug: 'providers/models' }
        ],
      },
      {
        label: '模型概念',
        items: [
        { slug: 'concepts/models' }
        ],
      },
      {
        label: '配置',
        items: [
        { slug: 'concepts/model-providers' },
        { slug: 'concepts/model-failover' }
        ],
      },
      {
        label: '提供商',
        items: [
        { slug: 'providers/anthropic' },
        { slug: 'providers/bedrock' },
        { slug: 'providers/cloudflare-ai-gateway' },
        { slug: 'providers/claude-max-api-proxy' },
        { slug: 'providers/deepgram' },
        { slug: 'providers/github-copilot' },
        { slug: 'providers/huggingface' },
        { slug: 'providers/kilocode' },
        { slug: 'providers/litellm' },
        { slug: 'providers/glm' },
        { slug: 'providers/minimax' },
        { slug: 'providers/moonshot' },
        { slug: 'providers/mistral' },
        { slug: 'providers/nvidia' },
        { slug: 'providers/ollama' },
        { slug: 'providers/openai' },
        { slug: 'providers/opencode-go' },
        { slug: 'providers/opencode' },
        { slug: 'providers/openrouter' },
        { slug: 'providers/qianfan' },
        { slug: 'providers/qwen' },
        { slug: 'providers/synthetic' },
        { slug: 'providers/together' },
        { slug: 'providers/vercel-ai-gateway' },
        { slug: 'providers/venice' },
        { slug: 'providers/vllm' },
        { slug: 'providers/xiaomi' },
        { slug: 'providers/zai' }
        ],
      },
      {
        label: '平台概览',
        items: [
        { slug: 'platforms' },
        { slug: 'platforms/macos' },
        { slug: 'platforms/linux' },
        { slug: 'platforms/windows' },
        { slug: 'platforms/android' },
        { slug: 'platforms/ios' },
        { slug: 'platforms/digitalocean' },
        { slug: 'platforms/oracle' },
        { slug: 'platforms/raspberry-pi' }
        ],
      },
      {
        label: 'macOS 配套应用',
        items: [
        { slug: 'platforms/mac/dev-setup' },
        { slug: 'platforms/mac/menu-bar' },
        { slug: 'platforms/mac/voicewake' },
        { slug: 'platforms/mac/voice-overlay' },
        { slug: 'platforms/mac/webchat' },
        { slug: 'platforms/mac/canvas' },
        { slug: 'platforms/mac/child-process' },
        { slug: 'platforms/mac/health' },
        { slug: 'platforms/mac/icon' },
        { slug: 'platforms/mac/logging' },
        { slug: 'platforms/mac/permissions' },
        { slug: 'platforms/mac/remote' },
        { slug: 'platforms/mac/signing' },
        { slug: 'platforms/mac/release' },
        { slug: 'platforms/mac/bundled-gateway' },
        { slug: 'platforms/mac/xpc' },
        { slug: 'platforms/mac/skills' },
        { slug: 'platforms/mac/peekaboo' }
        ],
      },
      {
        label: '网关',
        items: [
        { slug: 'gateway' },
        {
          label: '配置与运维',
          items: [
          { slug: 'gateway/configuration' },
          { slug: 'gateway/configuration-reference' },
          { slug: 'gateway/configuration-examples' },
          { slug: 'gateway/authentication' },
          { slug: 'auth-credential-semantics' },
          { slug: 'gateway/secrets' },
          { slug: 'gateway/secrets-plan-contract' },
          { slug: 'gateway/trusted-proxy-auth' },
          { slug: 'gateway/health' },
          { slug: 'gateway/heartbeat' },
          { slug: 'gateway/doctor' },
          { slug: 'gateway/logging' },
          { slug: 'gateway/gateway-lock' },
          { slug: 'gateway/background-process' },
          { slug: 'gateway/multiple-gateways' },
          { slug: 'gateway/troubleshooting' }
          ],
        },
        {
          label: '安全与沙箱',
          items: [
          { slug: 'gateway/security' },
          { slug: 'gateway/sandboxing' },
          { slug: 'gateway/sandbox-vs-tool-policy-vs-elevated' }
          ],
        },
        {
          label: '协议与 API',
          items: [
          { slug: 'gateway/protocol' },
          { slug: 'gateway/bridge-protocol' },
          { slug: 'gateway/openai-http-api' },
          { slug: 'gateway/openresponses-http-api' },
          { slug: 'gateway/tools-invoke-http-api' },
          { slug: 'gateway/cli-backends' },
          { slug: 'gateway/local-models' }
          ],
        },
        {
          label: '网络与发现',
          items: [
          { slug: 'gateway/network-model' },
          { slug: 'gateway/pairing' },
          { slug: 'gateway/discovery' },
          { slug: 'gateway/bonjour' }
          ],
        }
        ],
      },
      {
        label: '远程访问',
        items: [
        { slug: 'gateway/remote' },
        { slug: 'gateway/remote-gateway-readme' },
        { slug: 'gateway/tailscale' }
        ],
      },
      {
        label: '安全',
        items: [
        { slug: 'security/formal-verification' },
        { slug: 'security/readme' },
        { slug: 'security/threat-model-atlas' },
        { slug: 'security/contributing-threat-model' }
        ],
      },
      {
        label: 'Web 界面',
        items: [
        { slug: 'web' },
        { slug: 'web/control-ui' },
        { slug: 'web/dashboard' },
        { slug: 'web/webchat' },
        { slug: 'web/tui' }
        ],
      },
      {
        label: 'CLI 命令',
        items: [
        { slug: 'cli' },
        { slug: 'cli/acp' },
        { slug: 'cli/agent' },
        { slug: 'cli/agents' },
        { slug: 'cli/approvals' },
        { slug: 'cli/browser' },
        { slug: 'cli/channels' },
        { slug: 'cli/clawbot' },
        { slug: 'cli/completion' },
        { slug: 'cli/config' },
        { slug: 'cli/configure' },
        { slug: 'cli/cron' },
        { slug: 'cli/daemon' },
        { slug: 'cli/dashboard' },
        { slug: 'cli/devices' },
        { slug: 'cli/directory' },
        { slug: 'cli/dns' },
        { slug: 'cli/docs' },
        { slug: 'cli/doctor' },
        { slug: 'cli/gateway' },
        { slug: 'cli/health' },
        { slug: 'cli/hooks' },
        { slug: 'cli/logs' },
        { slug: 'cli/memory' },
        { slug: 'cli/message' },
        { slug: 'cli/models' },
        { slug: 'cli/node' },
        { slug: 'cli/nodes' },
        { slug: 'cli/onboard' },
        { slug: 'cli/pairing' },
        { slug: 'cli/plugins' },
        { slug: 'cli/qr' },
        { slug: 'cli/reset' },
        { slug: 'cli/sandbox' },
        { slug: 'cli/secrets' },
        { slug: 'cli/security' },
        { slug: 'cli/sessions' },
        { slug: 'cli/setup' },
        { slug: 'cli/skills' },
        { slug: 'cli/status' },
        { slug: 'cli/system' },
        { slug: 'cli/tui' },
        { slug: 'cli/uninstall' },
        { slug: 'cli/update' },
        { slug: 'cli/voicecall' },
        { slug: 'cli/webhooks' }
        ],
      },
      {
        label: 'RPC 与 API',
        items: [
        { slug: 'reference/rpc' },
        { slug: 'reference/device-models' }
        ],
      },
      {
        label: '模板',
        items: [
        { slug: 'reference/agents-default' },
        { slug: 'reference/templates/agents' },
        { slug: 'reference/templates/boot' },
        { slug: 'reference/templates/bootstrap' },
        { slug: 'reference/templates/heartbeat' },
        { slug: 'reference/templates/identity' },
        { slug: 'reference/templates/soul' },
        { slug: 'reference/templates/tools' },
        { slug: 'reference/templates/user' }
        ],
      },
      {
        label: '技术参考',
        items: [
        { slug: 'reference/wizard' },
        { slug: 'reference/token-use' },
        { slug: 'reference/secretref-credential-surface' },
        { slug: 'reference/prompt-caching' },
        { slug: 'reference/api-usage-costs' },
        { slug: 'reference/transcript-hygiene' },
        { slug: 'date-time' }
        ],
      },
      {
        label: '概念内部机制',
        items: [
        { slug: 'concepts/typebox' },
        { slug: 'concepts/markdown-formatting' },
        { slug: 'concepts/typing-indicators' },
        { slug: 'concepts/usage-tracking' },
        { slug: 'concepts/timezone' }
        ],
      },
      {
        label: '项目',
        items: [
        { slug: 'reference/credits' }
        ],
      },
      {
        label: '发布说明',
        items: [
        { slug: 'reference/releasing' },
        { slug: 'reference/test' }
        ],
      },
      {
        label: '实验性功能',
        items: [
        { slug: 'design/kilo-gateway-integration' },
        { slug: 'experiments/onboarding-config-protocol' },
        { slug: 'experiments/plans/acp-thread-bound-agents' },
        { slug: 'experiments/plans/acp-unified-streaming-refactor' },
        { slug: 'experiments/plans/browser-evaluate-cdp-refactor' },
        { slug: 'experiments/plans/openresponses-gateway' },
        { slug: 'experiments/plans/pty-process-supervision' },
        { slug: 'experiments/plans/session-binding-channel-agnostic' },
        { slug: 'experiments/research/memory' },
        { slug: 'experiments/proposals/model-config' }
        ],
      },
      {
        label: '帮助',
        items: [
        { slug: 'help' },
        { slug: 'help/troubleshooting' },
        { slug: 'help/faq' }
        ],
      },
      {
        label: '社区',
        items: [
        { slug: 'start/lore' }
        ],
      },
      {
        label: '环境与调试',
        items: [
        { slug: 'help/environment' },
        { slug: 'help/debugging' },
        { slug: 'help/testing' },
        { slug: 'help/scripts' },
        { slug: 'debug/node-issue' },
        { slug: 'diagnostics/flags' }
        ],
      },
      {
        label: 'Node 运行时',
        items: [
        { slug: 'install/node' }
        ],
      },
      {
        label: '压缩机制内部参考',
        items: [
        { slug: 'reference/session-management-compaction' }
        ],
      },
      {
        label: '开发者设置',
        items: [
        { slug: 'start/setup' },
        { slug: 'pi-dev' }
        ],
      },
      {
        label: '贡献',
        items: [
        { slug: 'ci' }
        ],
      },
      {
        label: '文档元信息',
        items: [
        { slug: 'start/hubs' },
        { slug: 'start/docs-directory' }
        ],
      },
      {
        label: 'CLI 命令大全',
        items: [
        { slug: 'cheatsheet/cli-commands' }
        ],
      },
      {
        label: '斜杠命令大全',
        items: [
        { slug: 'cheatsheet/slash-commands' }
        ],
      }
      ],
    }),
  ],
});
