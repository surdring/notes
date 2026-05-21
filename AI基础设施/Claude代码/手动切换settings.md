```bash
# 切到 LiteLLM
cp ~/.claude/cc-haha/settings-litellm.json ~/.claude/cc-haha/settings.json
sed -i 's/"activeId": "ce9c6bd5/"activeId": "3d9dc11d/' ~/.claude/cc-haha/providers.json

# 切到 WindsurfAPI
cp ~/.claude/cc-haha/settings-windsurfapi.json ~/.claude/cc-haha/settings.json
sed -i 's/"activeId": "3d9dc11d/"activeId": "ce9c6bd5/' ~/.claude/cc-haha/providers.json

```