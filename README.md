# LuaSimpleClass

[Luaclass](https://github.com/blanhhy/luaclass) 的轻量版，没有那么多功能，但能显著改善 Lua 的 OOP 体验

> Note:
> `simpleclass` 的类型结构比 `luaclass` 更简单，因此有更好的 LS 类型推导支持

## 安装 & 导入

同样的，下载主文件夹 `simpleclass` 到模块目录，然后在 Lua 代码中导入即可

```lua
require "simpleclass"
```

默认全局导入，这会将所有模块接口注册到 `_G`，如果你不希望这样，可以禁用 [全局导入](#全局导入)

## 快速开始

简单的情况用起来与 Luaclass 相差无几

```lua
require "simpleclass"

class "MyClass" {
    foo = function(self)
        print("foo from "..cls_type(self))
    end;
}

local obj = MyClass()
obj:foo() --> "foo from MyClass"
```

详细指导参考下方 [特性说明](#特性) 或 [演示脚本](demo.lua)

## 特性

### 类

类是 LuaSimpleClass 的核心，类是生成对象的蓝图，使多个对象共享相同的方法，同时在构造函数中规定对象应有的属性

- 定义命名类：语法为 `class "<name>" {<body>}`

> 命名类创建后位于 `class._ENV` 环境中，同名的类会覆盖之前的定义；如果设置了 `simpleclass.AUTO_GLOBAL = true`，还会检测 `_G` 中是否有同名非类变量，若无则为类注册全局变量

- 静态方法: 没有 `self` 参数的函数，用 `.` 调用
- 对象方法: 第一个参数为 `self` 的方法，用 `:` 调用
- 构造函数：方法签名为 `__init(self, ...) --> nil`
- 实例化：`clazz()` 或 `clazz:new()` 均可，这里以前者为例

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

- 匿名类：无名的类，不会注册到任何环境

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
> 注：定义有名类时如果传入空参数，空字符串，非字符串参数，一律会被解释为匿名类；如 `class () {}` 也能创建匿名类，这和 `class {}` 方式的不同之处在于，它可以像命名类一样用 `extends` `implements`

### 类的继承

- 单继承：本模块仅支持单继承，使用 `extends` 关键字

> `extends` 接受类名字符串，因此匿名类不能作为父类；但匿名类可以继承其他类，这一点与 Java 类似

- `super`：接收当前类与 `self`，如 `super(MySubclass, self):__init()`

> 示例：单继承
>
> ```lua
> class "MySubClass" : extends "MyClass" {
>     ---@Override
>     foo = function(self)
>         super(MySubclass, self):foo() -- call parent's foo
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

接口可以被类实现，可以检查类是否实现了接口，这与继承相似；同时接口之间也存在类似继承的关系，但不会形成继承链

- 接口定义：使用 `interface`，语法类似于类定义
- 匿名接口：类似于匿名类

> 命名接口同样在 `class._ENV` 中，与命名类的处理规则完全相同

> 示例：接口定义
>
> ```lua
> interface "CanFly" {
>     "fly"; -- only method names
> }
> ```

- 接口实现：使用 `implements` 关键字，类可以实现多个接口

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

`cls_type(obj)`

- 返回对象的类
- 如果是基本类型，返回 `type(obj)`
- 这是它在 `_G` 中的名字（因为 `_G` 已有 `type`），在模块中名为 `type`

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
- 没有对应的全局函数（我认为没有必要）

上面几个方法接受或返回的类或接口都是对象本身

### 类型推导

`simpleclass` 提供了与 [lua-language-server](https://github.com/LuaLS/lua-language-server) 兼容的类型推导插件，下面是一个参考的 LS 配置：

```json
"runtime.plugin": ".luals/simpleclass.plugin.lua"
```

复制插件脚本，并且保持 `simpleclass` 文件夹在 LS 支持的模块目录中即可

大致的功能：

- 为新建的类和接口生成 @class 标注
- 自动包含用户定义的类成员（包括 Getter 对应的属性）
- 自动生成 new 方法的签名
- 自动分析继承链与接口
- 提供 @override，用于检查超类上是否有同名方法

> Warnning:
> 静态推导依赖于 LuaSimpleClass DSL，如果非全局导入，则需要在每个文件中手动 local 所用到的模块接口，使得函数名与全局导入时匹配

## 配置项

### 全局导入

自动注册模块接口到 `_G` 中，同时启用 [自动全局类](#自动全局类)

如果不想污染全局环境，设为 `false` 即可

- 类别：导入时选项
- 字段：`init.lua` 中的 `options.GLOBAL_IMPORT`
- 默认：`true`

### 包含接口

包含接口相关功能

如果要裁剪接口模块，设为 `false` 即可

- 类别：导入时选项
- 字段：`init.lua` 中的 `options.INTERFACE_INCLUDED`
- 默认：`true`

### 默认接口功能

[接口功能](#接口功能) 的初始值

如果设为 `"lexical"`，可以实现只包含 LS 功能，而无运行时

- 类别：导入时选项
- 字段：`init.lua` 中的 `options.DEFAULT_I_FEATURE`
- 默认：`"general"`

### 自动全局类

定义类时，检查全局变量名是否空闲，自动注册全局变量

- 类别：运行时选项
- 字段：`simpleclass.AUTO_GLOBAL`
- 初始：和 [全局导入](#全局导入) 一致

### 接口功能

`general` 为启用全部功能
`nocheck` 可跳过运行时接口检查（总返回 `true`）
`lexical` 仅保留词法要素供 LS 分析，不含任何运行时功能

`nocheck` 适用于临时关闭检查，和 `general` 可以安全切换，而 `lexical` 则具有不可逆性（因新创建的接口实为 `nil`）

如果已经使用了接口想弃用，可以设置为 `"lexical"`，以免解释器语法错误

- 类别：运行时选项
- 字段：`simpleclass.I_FEATURE`
- 初始：和 [默认接口功能](#默认接口功能) 一致
