```json
{
  "meta": {
    "lastTouchedVersion": "2026.2.3-1",
    "lastTouchedAt": "2026-02-08T06:44:35.827Z"
  },
  "wizard": {
    "lastRunAt": "2026-02-08T06:44:35.798Z",
    "lastRunVersion": "2026.2.3-1",
    "lastRunCommand": "configure",
    "lastRunMode": "local"
  },
  "auth": {
    "profiles": {
      "volcengine:default": {
        "provider": "volcengine",
        "mode": "api_key"
      }
    }
  },
  "models": {
    "providers": {
      "volcengine": {
        "baseUrl": "https://ark.cn-beijing.volces.com/api/coding/v3",
        "apiKey": "a383e443-c50d-4fbd-9a87-0fbe3d425602",
        "api": "openai-completions",
        "models": [
          {
            "id": "ark-code-latest",
            "name": "ark-code-latest",
            "reasoning": false,
            "input": [
              "text"
            ],
            "cost": {
              "input": 0,
              "output": 0,
              "cacheRead": 0,
              "cacheWrite": 0
            },
            "contextWindow": 200000,
            "maxTokens": 8192
          }
        ]
      },
      "llama": {
        "baseUrl": "http://172.16.100.211:8080/v1",
        "apiKey": "sk-local-gpt20b",
        "api": "openai-completions",
        "models": [
          {
            "id": "gpt-oss-20b",
            "name": "gpt-oss-20b",
            "reasoning": false,
            "input": [
              "text"
            ],
            "cost": {
              "input": 0,
              "output": 0,
              "cacheRead": 0,
              "cacheWrite": 0
            },
            "contextWindow": 131072,
            "maxTokens": 8192
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "llama/gpt-oss-20b"
      },
      "workspace": "/home/surdring/.openclaw/workspace",
      "compaction": {
        "mode": "safeguard"
      },
      "maxConcurrent": 4,
      "subagents": {
        "maxConcurrent": 8
      }
    }
  },
  "messages": {
    "ackReactionScope": "group-mentions"
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto"
  },
  "hooks": {
    "enabled": true,
    "token": "61b720af860dbbe0f6daf53781b022add34f9f108692088694675a05eb326fc7",
    "internal": {
      "enabled": true,
      "entries": {
        "command-logger": {
          "enabled": true
        },
        "session-memory": {
          "enabled": true
        }
      }
    }
  },
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "loopback",
    "auth": {
      "mode": "token",
      "token": "59d92a1f9c0c6aa1a11a28caa028f761117fe00fe75562c3"
    },
    "tailscale": {
      "mode": "off",
      "resetOnExit": false
    }
  },
  "memory": {
    "backend": "builtin"
  },
  "plugins": {
    "load": {
      "paths": [
        "/home/surdring/.local/share/Trash/files/openclaw/extensions/feishu"
      ]
    },
    "entries": {
      "feishu": {
        "enabled": true
      }
    }
  },
  "channels": {
    "feishu": {
      "enabled": true,
      "appId": "cli_a90295f185f85bcd",
      "appSecret": "Sgd6ITbxARrhSvMcz3FNPeTQoMVvSdtF",
      "domain": "feishu",
      "groupPolicy": "open",
      "dmPolicy": "open",
      "allowFrom": [
        "*"
      ]
    }
  }
}

```