```
是否new方法？
    - 是： # 实例化方法
    归属为 <cls>.class
    首参为 <cls>.class
是否__init方法？
    - 是： # 构造方法（特殊实例方法）
    归属为 <cls>
    首参为 <cls>
是否元方法？
    - 是： # 元方法（特殊静态方法）
    归属为 <cls>.class
    首参为 <cls>
    @operator 作用于 <cls>
是否为Getter/Setter？
    - 是： # 特殊属性
    归属为 <cls>
    首参为 <cls>
是否标 @static？
    - 是：
    首参是否名为 cls？
        - 是： # 类方法
        归属为 <cls>.class
        首参为 <cls>.class
        - 否： # 静态方法
        归属为 <cls>.class
    - 否： # 实例方法
    归属为 <cls>
    首参为 <cls>
```

当归属和首参类型一致，且首参名为 self 时，重发副本使用冒号语法

getter/setter 除外（没有重发副本
）