api-dashboard.search.brave.com
Brave Search API Key:BSAmcnrtr9Geq782bICLeGPwingahxb
export BRAVE_API_KEY="BSAmcnrtr9Geq782bICLeGPwingahxb"

curl -sS \
  -H 'Accept: application/json' \
  -H "X-Subscription-Token: BSAmcnrtr9Geq782bICLeGPwingahxb" \
  "https://api.search.brave.com/res/v1/web/search?q=test" | head -c 400