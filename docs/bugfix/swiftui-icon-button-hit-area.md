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

让标签只描述图标内容，并直接使用系统提供的按钮样式。按钮的命中区域、按压反馈和玻璃效果都应由 `ButtonStyle` 管理：

```swift
Button(action: action) {
    Image(systemName: "xmark")
        .frame(width: 20, height: 20)
}
.buttonStyle(.glass(.regular.interactive()))
.buttonBorderShape(.circle)
.help("关闭")
```

不要先用 `.plain` 清除按钮样式，再通过外层 `.frame`、`.contentShape` 和 `.glassEffect` 手动模拟按钮。外层视图尺寸不一定会扩大 `.plain` 按钮内部标签的命中区域，也会绕过系统按钮对键盘焦点和按压状态的管理。

如果系统样式不能满足视觉要求，应实现自定义 `ButtonStyle`，而不是把交互效果直接放在 `Image` 或普通 View 修饰符上。修改后还需要分别检查浅色和深色界面的图标对比度。

## 本次修复范围

- 应用首页的设置按钮。
- 词汇详情页的关闭按钮。
- 词汇编辑页的返回按钮。

## 检查清单

- 点击动作是否定义在 `Button` 或语义等价的控件上。
- 交互外观是否通过 `ButtonStyle` 作用于控件，而不是通过普通 View 修饰符模拟。
- 标签内部是否只保留图标内容和必要的图标尺寸。
- 鼠标按压、键盘焦点和辅助功能是否共享同一个按钮区域。
