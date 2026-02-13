# LuaSimpleClass

[Luaclass](https://github.com/blanhhy/luaclass) 的轻量版，没有那么多功能，但能显著改善 Lua 的 OOP 体验

## 安装 & 导入

同样的，下载主文件夹 `simpleclass` 到模块目录，然后在 Lua 代码中导入即可

```lua
require "simpleclass"
```

这会将所有模块接口注册到 `_G`，如果你不希望这样，可以只：

```lua
local simpleclass = require "simpleclass.local"
```

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

## 特性

### 类

类是 LuaSimpleClass 的核心，类是生成对象的蓝图，使多个对象共享相同的方法，同时在构造函数中规定对象应有的属性

- 定义命名类：语法为 `class "<name>" {<body>}`

> 命名类创建后位于 `class.env` 环境中，同名的类会覆盖之前的定义；同时，如果此时 `_G` 中没有其他同名变量，会自动创建全局变量 `<name>` 指向该类

- 静态方法: 没有 `self` 参数的函数，用 `.` 调用
- 对象方法: 第一个参数为 `self` 的方法，用 `:` 调用
- 构造函数：方法签名为 `__init(self, ...) --> nil`
- 实例化：`clazz()` 或 `clazz:new()` 均可，这里以前者为例

> 示例：命名类
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

- `super`：接收 `self` 参数，如 `super(self):__init()`

> 示例：单继承
> ```lua
> class "MySubClass" : extends "MyClass" {
>     ---@Override
>     foo = function(self)
>         super(self):foo() -- call parent's foo
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

> 命名接口同样在 `class.env` 中，与命名类的处理规则完全相同

> 示例：接口定义
> ```lua
> interface "CanFly" {
>     "fly"; -- only method names
> }
> ```

- 接口实现：使用 `implements` 关键字，类可以实现多个接口

> `implements` 接受不定数量的接口（对象本身），无论接口有没有名字都可以

> 示例：接口实现
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

实际上空接口的 `{}` 可以省略，这一点和定义类不同

### 类型检查

`cls_type(obj)`
- 返回对象的类
- 如果是基本类型，返回 `type(obj)`
- 这是它在 `_G` 中的名字（因为 `_G` 已有 `type` ），在模块中名为 `type`

`isinstance(obj, clazz_or_type)`
- 判断对象是否为指定类或其子类，或接口
- 也可以用于检查基本类型
- 与对象方法 `obj:isInstance(clazz)` 等价

`issubclass(sub_clazz, super_clazz)`
- 判断子类是否为父类或其祖先类
- 与类方法 `clazz:isExtends(base)` 等价
- 注：同一个类会返回 `true`

`cls:isImplements(...interface)`
- 判断类是否实现了指定接口，可以多个
- 没有对应的全局函数（我认为没有必要）

上面几个方法接受或返回的类或接口都是对象本身

-------

LuaSimpleClass 致力于简化 Lua 面向对象开发，减少样板代码，虽然功能不多，但能满足 Lua 中多数情况下的需求。