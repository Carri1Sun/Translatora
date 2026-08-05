# Qwen Token Plan 接入说明

Translatora 通过 Qwen Token Plan 的 OpenAI 兼容 Chat Completions API 接入，支持以下模型：

- `qwen3.8-max`
- `qwen3.6-flash`

## 配置

在设置中选择「Qwen Token Plan」，填写 Token Plan 专用 API Key，并选择 API Keys 页面显示的服务区域：

- 国际（新加坡）：`https://token-plan.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1`
- 中国内地（北京）：`https://token-plan.cn-beijing.maas.aliyuncs.com/compatible-mode/v1`

Token Plan、Coding Plan 和按量计费使用相互隔离的 API Key 与 Base URL，不能交叉使用。国际版 Token Plan Key 通常以 `sk-sp-` 开头；应始终以订阅控制台的 API Keys 页面为准。

「测试连接」会向当前模型发起一次最小的 Chat Completions 请求，因此会产生少量 Credits 消耗。翻译请求关闭思考模式，以降低响应延迟和 Credits 消耗，并让模型直接输出约定的 JSON 结果。

## 参考资料

- [Token Plan 快速开始](https://docs.qwencloud.com/token-plan/quickstart)
- [Token Plan 常见问题](https://docs.qwencloud.com/token-plan/faq)
- [Qwen 文本生成模型](https://docs.qwencloud.com/developer-guides/getting-started/text-generation-models)
- [OpenAI Chat API](https://docs.qwencloud.com/api-reference/chat/openai-chat)
