# SwiftUI 图标按钮的命中区域与交互效果

## 问题

图标按钮容易写成“外层控件使用纯文本样式，内层 `Image` 自己负责尺寸、内边距和交互玻璃效果”的结构：

```swift
Button(action: action) {
    Image(systemName: "xmark")
        .padding(6)
        .glassEffect(.regular.interactive(), in: .circle)
}
.buttonStyle(.plain)
```

这种写法把可交互的视觉效果放在了图标标签上。按钮本身没有对应的按钮样式，容易出现按压反馈、焦点表现和可点击区域都围绕图标计算，而不是由完整按钮控件统一管理的问题。

## 修复方式

让标签只描述图标内容，把命中尺寸、命中形状和交互效果设置在 `Button`、`SettingsLink` 等完整控件上：

```swift
Button(action: action) {
    Image(systemName: "xmark")
        .frame(width: 20, height: 20)
}
.buttonStyle(.plain)
.foregroundStyle(.primary)
.frame(width: 32, height: 32)
.contentShape(.circle)
.glassEffect(.regular.interactive(), in: .circle)
.help("关闭")
```

这里的修饰符位于 `Button` 闭包之外，因此 32 × 32 的完整控件负责命中测试和交互反馈。`contentShape` 明确了圆形命中区域，`glassEffect` 也会响应整个按钮，而不是只响应内部图标。

也可以使用能提供正确命中区域的系统或自定义 `ButtonStyle`。需要注意浅色和深色界面的图标对比度；如果按钮样式会覆盖前景色，应通过渲染检查确认结果。

## 本次修复范围

- 应用首页的设置按钮。
- 词汇详情页的关闭按钮。
- 词汇编辑页的返回按钮。

## 检查清单

- 点击动作是否定义在 `Button` 或语义等价的控件上。
- 命中尺寸、`contentShape` 和交互效果是否作用于控件，而不是内部图标。
- 标签内部是否只保留图标内容和必要的图标尺寸。
- 鼠标按压、键盘焦点和辅助功能是否共享同一个按钮区域。
