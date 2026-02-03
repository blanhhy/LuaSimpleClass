# LuaSimpleClass

[Luaclass](https://github.com/blanhhy/luaclass) 的轻量版，没有那么多功能，但能显著改善 Lua 的 OOP 体验

## 安装 & 导入

同样的，下载主文件夹 `simpleclass` 到模块目录，然后在 Lua 代码中导入即可

```lua
require "simpleclass"
```

## 示例

简单的情况用起来与 Luaclass 相差无几

```lua
require "simpleclass"

class "MyClass" {
    foo = function(self)
        print("foo from "..class.type(self))
    end;
}

local obj = MyClass()
obj:foo() --> "foo from MyClass"
```

## 特性 & 限制

- 定义类：依旧是 `class "<name>" {<body>}` 语法
- 构造函数：依旧是 `__init`，无需返回值
- 实例化：依旧 `clazz()` 和 `clazz:new()` 均可
- 继承：使用 `extends` 关键字，且仅支持单继承

> ```lua
> class "MySubClass" : extends "MyClass" {
>     ---@Override
>     foo = function(self)
>         print("improved foo")
>     end;
> }
> ```

- 获取类型：使用 `class.type(obj)`，因为没有元类
- `super`：接收 `self` 参数，如 `super(self):__init()`
- 判断类型：全局 `isinstance` 函数或 `:isInstance` 方法
- 匿名类：`clazz = class () {<body>}`，生命周期自行管理

没有访问控制，没有命名空间（都是全局类，匿名类除外），高级功能如声明模式、抽象类等都没有

LuaSimpleClass 致力于简化 Lua 面向对象开发，减少样板代码，虽然功能不多，但能满足 Lua 中多数情况下的需求。同时，由于实现很简单，所以性能可能比 Luaclass 好