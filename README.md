# Lua Simple Class

可能是第一个有着现代语法，但不干扰——反而增强静态检查工具的 Lua 类库

作为 [Luaclass](https://github.com/blanhhy/luaclass) 的轻量版提供，极大简化了运行时行为，但保留核心 OOP 能力，能显著改善 Lua 的 OOP 体验

## 安装 & 导入

`simpleclass` 是纯 Lua 实现的，只需要下载 [此文件夹](simpleclass)，然后在 Lua 代码中导入即可

```lua
require "simpleclass"
```

默认全局导入，这会将所有模块接口注册到 `_G`，如果你不希望这样，可以禁用 [全局导入](#全局导入)

> Guide:  
> 使用支持参数的第三方导入器是个不错的选择，但你也可以直接：
> ```lua
> local sc = require "simpleclass.with" {AUTO_GLOBAL = false}
> ```

## 快速开始

简单的情况用起来与 Luaclass 相差无几

```lua
require "simpleclass"

class "MyClass" {
    foo = function(self)
        print("foo from", self:getClass())
    end;
}

local obj = MyClass()
obj:foo() --> "foo from    MyClass"
```

详细指导参考下方 [特性](#特性) 或 [演示脚本](demo.lua)

## 特性

### 类

类是 simpleclass 的核心，类是生成对象的蓝图，使多个对象共享相同的方法，同时在构造函数中规定对象应有的属性

定义命名类：语法为 `class "<name>" {<body>}`

> 命名类创建后位于 `simpleclass._ENV` 环境中，同名的类会覆盖之前的定义；如果开启了 [自动全局类](#自动全局类)，还会为类注册全局变量

类的成员：

- 静态字段：直接在类体中定义，属于类本身，所有对象共享
- 实例字段：在构造函数中定义，每个对象都有自己的实例字段，类无法访问它们
- Getter & Setter 属性：本质是一对实例方法，但向外暴露一个逻辑上的字段
- 实例方法：预期首参为实例的方法，习惯将首参命名为 `self`，用 `:` 调用
- 类方法：预期首参为类的方法，习惯将首参命名为 `cls` 或 `self`，用 `:` 调用
- 静态方法：挂载在类对象上的普通函数，不依赖于实例或类，用 `.` 调用
- 构造函数：名为 `__init` 的方法，是特殊的实例方法，在对象创建时调用
- 元方法：Lua 原生的元方法，定义在类对象上，影响实例对象的行为

实例化：`clazz()` 或 `clazz:new()` 均可，这里以前者为例

> 示例：命名类
>
> ```lua
> class "MyNamedClass" {
>     __init = function(self, arg1, arg2)
>         self.arg1 = arg1
>         self.arg2 = arg2
>     end;
>     print = function(self)
>         print(self.arg1, self.arg2)
>     end;
> }
>
> local obj = MyNamedClass("hello", "world")
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
> 注：并不需要同时实现，可以只读或只写，甚至没有

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
> 注：定义有名类时如果传入空参数，空字符串，非字符串参数，一律会被解释为匿名类；如 `class () {}` 也能创建匿名类，甚至可以使用 `extends` `implements`

### 类的继承

- 单继承：simpleclass 仅支持单继承

  经典语法：使用 `extends` 关键字 + 类名字符串  
  简短语法：直接书写基类名，示例：`class "Myclass" : Base {}`

> 简短语法下，基类必须紧跟类体，如有其他关键字（如 `implements`）需要在它之前使用

- `super`：以子类对象身份调用父类方法

  接收当前类与 `self`，示例： `super(thisclass, self):foo()`  
  如果 `debug` 库可用，`super()` 可以无需传递参数，和 Python 类似
  如果明确要调用构造函数，可以省略名字，示例：`super(cls, self)()`

> 示例：单继承
>
> ```lua
> class "MySubClass" : extends "MyClass" {
>     ---@Override
>     foo = function(self)
>         super(MySubClass, self):foo() -- call parent's foo
>         print("improved foo")
>     end;
> }
>
> local obj = MySubClass()
> obj:foo() --> foo from MySubClass
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

实际上，不同于定义类，空接口的 `{}` 完全可以省略

### 类型检查

`simpleclass.type(obj)`

- 返回对象的类
- 如果是基本类型，返回 `type(obj)`
- 由于`_G.type` 已存在，故不自动注入

`isinstance(obj, cls_or_type)`

- 判断对象是否为指定类或其子类，或接口
- 也可以用于检查基本类型
- 与对象方法 `obj:isInstance(clazz)` 等价

`issubclass(sub_cls, super_cls)`

- 判断子类是否为父类或其祖先类
- 与类方法 `clazz:isExtends(base)` 等价
- 注：同一个类会返回 `true`

`cls:isImplements(...interface)`

- 判断类是否实现了指定接口，可以多个
- 没有对应的模块级接口（我认为没有必要）

上面几个方法接受或返回的类/接口都是对象本身

### 类型推导

`simpleclass` 提供了适用于 [lua-language-server](https://github.com/LuaLS/lua-language-server) 的类型推导插件，下面是一个参考的 `.luarc.json` 配置：

```json
{
  "runtime.plugin": ".luals/simpleclass.plugin.lua"
}
```

复制插件脚本和 `simpleclass.d.lua` 到工作区即可

也提供了可选的补丁脚本，用于增强插件能力，注意补丁会 hook LuaLS 内部行为，可能影响正常功能且跨版本不稳定

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

> Warnning:  
> 静态推导依赖于 LuaSimpleClass DSL，如果非全局导入，则需要在每个文件中手动 `local` 所用到的模块接口，使得函数名与全局导入时匹配
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
