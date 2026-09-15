> Read in:
>
> ☑ 简体中文\
> ☐ [English](README_en.md)

# Lua Simple Class

可能是第一个有着现代语法，但不干扰——反而增强静态检查工具的 Lua 类库

作为 [Luaclass](https://github.com/blanhhy/luaclass) 的轻量版提供，简化了运行时行为，但保留核心 OOP 能力

## 安装

`simpleclass` 是纯 Lua 实现的，只需要下载 [此文件夹](simpleclass) 即可在任何地方使用

> **All in One** 文件现在可用！！\
> 可以方便地带到任何 Lua 项目中\
> [simpleclass.lua](variant/simpleclass.lua)

兼容 Lua 5.1 及以上版本，含 LuaJIT

如果你使用 [LuaRocks](https://luarocks.org/)，也可以用如下命令安装：

```bash
luarocks install simpleclass
```

或从源码构建到当前 rocks 树（如 `luarocks init` 生成的 `lua_modules/`）：

```bash
luarocks make --tree=lua_modules simpleclass-1.0.0-1.rockspec
```

## 快速开始

### 导入模块

```lua
require "simpleclass"
```

默认全局导入，这会将所有模块接口注册到 `_G`，如果你不希望这样，可以禁用 [全局导入](#全局导入)

> Guide:\
> 使用支持参数的第三方导入器是个不错的选择，但你也可以直接：
>
> ```lua
> local sc = require "simpleclass.with" {GLOBAL_IMPORT = false}
> ```

### 定义第一个类

```lua
class "MyClass" {
    foo = function(self)
        print("foo from", self:getClass())
    end;
}

local obj = MyClass()
obj:foo() --> "foo from    MyClass"
```

更多示例代码可以参考 [Demo](demo/)

## 特性

### 类

定义命名类：

语法为 `class "<name>" {<body>}`

> 命名类创建后位于 `simpleclass._ENV` 环境中，同名的类会覆盖之前的定义；如果开启了 [自动全局类](#自动全局类)，还会为类注册全局变量

类的成员：

静态字段、实例字段、实例属性、实例方法、类方法、静态方法、构造函数和元方法

> 在 Lua 中，实例方法需要用 `:` 调用，习惯上将函数第一个参数命名为 `self`；类方法逻辑类似
>
> SimpleClass 以 `__init` 作为构造函数名，也兼容 `constructor` 作为定义时的别名
>
> 直接在类体中定义的字段会成为静态字段，所有对象共享；而元方法是 Lua 原生的元方法，类是实例的元表，因此可以定义元方法来改变实例的行为

实例化：

使用 `clazz:new()` 或 `clazz()` 均可\
如果你正在使用 LuaLS，前者是更推荐的写法

> 示例：命名类
>
> ```lua
> class "NamedCls" {
>     __init = function(self, arg1, arg2)
>         self.arg1 = arg1
>         self.arg2 = arg2
>     end;
>     print = function(self)
>         print(self.arg1, self.arg2)
>     end;
> }
>
> local obj = NamedCls:new("hello", "world")
> obj:print() --> "hello world"
> ```

Getter & Setter 属性：

使用 `property` 定义属性，属性可以拥有 Getter & Setter 方法

- Getter：函数名为 `get.<attr>`，使得 `obj.attr` 可读取
- Setter：函数名为 `set.<attr>`，使得 `obj.attr` 可赋值

> 示例：定义 Getter & Setter
>
> ```lua
> class "Counter" {
>     __init = function(self, init)
>         self._count = init or 0
>     end;
>     property.count;
>     ['get.count'] = function(self)
>         return self._count
>     end;
>     ['set.count'] = function(self, new)
>         self._count = new
>     end;
> }
>
> local obj = Counter(10)
> print(obj.count) --> 10
> obj.count = 20
> print(obj.count) --> 20
> ```
>
> 注：并不需要同时实现，可以只读或只写，甚至都没有

匿名类：临时使用的类，无需命名，也不注册环境

> 示例：匿名类
>
> ```lua
> local cls = class {
>     foo = function(self)
>         print("foo from anonymous class")
>     end;
> }
>
> local obj = cls()
> obj:foo() --> "foo from anonymous class"
> ```
>
> 注：\
> 定义有名类时如果传入空参数，空字符串，非字符串参数，一律会被解释为匿名类\
> 如 `class() {}` 也能创建匿名类，甚至可以使用 `extends` `implements`

### 类的继承

- 单继承：simpleclass 仅支持单继承

  经典语法：使用 `extends` 关键字 + 类名字符串\
  简短语法：直接书写基类名，示例：`class "Cls" : Base {}`

> 简短语法下，基类必须紧跟类体，如有其他关键字（如 `implements`）需要在它之前使用

- `super`：以子类对象身份调用父类方法

  接收当前类与 `self`，示例： `super(this_cls, self):foo()`
  > `self` 可以是实例对象，也可以是类对象
  调用父类构造函数时，可以省略名字，示例：`super(cls, self)()`
  如果 `debug` 库可用，`super()` 可以无需传递参数，和 Python 类似

> 示例：单继承
>
> ```lua
> class "MySubCls" : extends "MyClass" {
>     ---@Override
>     foo = function(self)
>         super(MySubCls, self):foo() -- call parent's foo
>         print("improved foo")
>     end;
> }
>
> local obj = MySubCls:new()
> obj:foo() --> foo from MySubCls
>           --| improved foo
> ```

### 接口

接口是一组方法签名，定义了类必须实现的方法

接口不是类，不能实例化

接口可以被类实现，可以检查类是否实现了方法；同时接口之间也存在类似继承的关系，但不会形成继承链

- 接口定义：使用 `interface`，语法类似于类定义
- 匿名接口：类似于匿名类

> 命名接口同样在 `simpleclass._ENV` 中，与命名类的处理规则完全相同

> 示例：接口定义
>
> ```lua
> interface "CanFly" {
>     "fly"; -- only method names
> }
> ```

- 接口实现：使用 `implements`（或 `impl`）关键字，类可以实现多个接口

> 示例：接口实现
>
> ```lua
> class "Bird" : implements(CanFly) {
>     fly = function(self)
>         print("bird is flying")
>     end;
> }
>
> local obj = Bird()
> obj:fly() --> "bird is flying"
> ```

### 接口组合

定义接口时使用 `extends` 关键字可以组合多个接口

> 示例：接口组合
>
> ```lua
> interface "CanEat" {
>     "eat";
> }
>
> interface "BirdLike" : extends(CanEat, CanFly) {
>     "spawn";
>     "nest";
> }
> ```

如上，组合其他接口的同时，还可以定义新的方法

### 类型检查

**`type(obj)`**

> 不是 Lua 标准库中的 `type`

使用方式：

```lua
local ctype = require("simpleclass").type
print(ctype(obj), ctype(10))
```

- 返回 SimpleClass 库中对象的类
- 如果是 Lua 基本类型，与标准库 `type` 行为一致

**`isinstance(obj, cls)`**

使用方式：

```lua
isinstance(MyCls(), MyCls)
obj:isInstance(SomeClass)
```

- 判断对象是否为指定类型
- 类型可以是类、接口、Lua 基本类型
- 对象可以直接调用 `isInstance` 方法，与 `isinstance` 等价

**`issubclass(cls1, cls2)`**

使用方式：

```lua
issubclass(Dog, Animal)
```

- 判断一个类是否继承自另一个类（包括间接继承）
- 注：**同一个类会返回** **`true`**

**`isimplements(cls, ...interface)`**

使用方式：

```lua
isimplements(Bird, CanFly)
```

- 判断类是否实现了指定接口，可以多个
- 失败时，会额外返回未实现的接口索引

**`isimpl(cls, i)`**

使用方式：

```lua
local isimpl = require("simpleclass").isimpl
isimpl(Person, CanFly) --> false, "fly"
```

- 判断类是否实现了指定接口，只能传单个
- 失败时，会额外返回具体的未实现方法名

上面几个方法接受或返回的类 / 接口都是对象本身

### 类型推导

SimpleClass 提供了适用于 [lua-language-server](https://github.com/LuaLS/lua-language-server) 的类型推导插件，下面是一个参考的 `.luarc.json` 配置：

```json
{
  "runtime.plugin": ".luals/simpleclass.plugin.lua"
}
```

复制插件脚本和 `simpleclass.d.lua` 到工作区即可

如果通过 LuaRocks 安装，插件文件位于 rock 的配置目录中。先运行下面的命令获取当前版本目录：

```bash
luarocks show --rock-dir simpleclass
```

将输出路径记为 `<rock-dir>`，然后配置：

```json
{
  "runtime.plugin": "<rock-dir>/conf/simpleclass.luals/simpleclass.plugin.lua",
  "workspace.library": [
    "<rock-dir>/conf/simpleclass.luals"
  ]
}
```

> 注意：`runtime.plugin` 是 LuaLS 插件路径，不是 LuaRocks 的 Lua 模块路径；升级 `simpleclass` 后重新执行 `luarocks show --rock-dir simpleclass` 即可获取新路径。

也提供了可选的补丁脚本，用于增强插件能力

> 注意：补丁会 hook LuaLS 内部行为，可能影响正常功能且跨版本不稳定

如果要应用补丁，需要也复制对应的补丁文件，并保持目录结构一致

```
[DIR]
├── simpleclass.plugin.lua # 核心插件
└── patches/               # 补丁脚本目录
```

自动类型声明：

- 识别 DSL 语法自动生成静态类型注解，无需手动标注类型
- `@static` 成为有效注解，用于声明在类而非实例上的成员
- 使用双类型分担语义加自定义诊断模拟 LuaLS 不存在的接口类型

辅助类型推导：

- 智能识别方法上下文，对类别已知的方法，自动绑定首参为类或对象的类型
- 如果实例方法参数将被赋值给字段，字段类型已声明而形参类型未知，自动标注为字段的类型
- 实例方法中使用 `super` 调用时，插件自动替换为父类对象，从而得到父类方法的参数提示

静态类型检查：

- `@override` 作成为有效注解，用于检查父类上是否实际有该方法，提供 Warning 诊断
- 定义类时如果实现了接口，LS 自动检查类是否实现了接口要求的方法，提供 Error 诊断
- 【补丁】增强 `@overload` 签名分派，具体类型、子类型优先，阻止范围包含的联合类型

更多功能等待发现

> Warning:\
> 静态推导依赖于 LuaSimpleClass DSL
>
> 如果非全局导入，则需要在每个文件中手动 `local` 所用到的模块接口，使得函数名与全局导入时匹配
>
> ```lua
> local class, super = sc.class, sc.super -- etc.
> ```

## 配置项

### 全局导入

自动注册模块接口到 `_G` 中，同时启用 [自动全局类](#自动全局类)

如果不想污染全局环境，设为 `false` 即可

- 类别：**导入时**选项
- 字段：[init.lua](simpleclass/init.lua) 中的 `options.GLOBAL_IMPORT`
- 默认：`true`

### 包含接口

包含接口相关功能

如果要裁剪接口模块，设为 `false` 即可

- 类别：**导入时**选项
- 字段：[init.lua](simpleclass/init.lua) 中的 `options.INTERFACE_INCLUDED`
- 默认：`true`

### 默认接口功能

[接口功能](#接口功能) 的初始值

如果设为 `"lexical"`，可以实现只包含 LS 功能，而无运行时

- 类别：**导入时**选项
- 字段：[init.lua](simpleclass/init.lua) 中的 `options.DEFAULT_I_FEATURE`
- 默认：`"general"`

### 自动全局类

定义类时，检查全局变量名是否空闲，如果为空闲则自动注册到全局变量

- 类别：**运行时**选项
- 字段：`simpleclass.AUTO_GLOBAL`
- 初始：和 [全局导入](#全局导入) 一致

### 接口功能

`general` 为启用全部功能；`nocheck` 可跳过运行时接口检查（总返回 `true`），适用于临时关闭检查，和 `general` 可以安全互换；`lexical` 仅保留词法要素供 LS 分析，不含任何运行时功能，期间跳过的对象创建不补回，具有一定不可逆性

如果已经使用了接口想弃用，可以只设置为 `"lexical"`，以免既有 DSL 报错

- 类别：**运行时**选项
- 字段：`simpleclass.I_FEATURE`
- 初始：和 [默认接口功能](#默认接口功能) 一致

