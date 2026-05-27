# 向量、矩阵与运算

> 每个神经网络不过是多了几步的矩阵乘法。

**类型：** 构建
**使用语言：** Python、Julia
**前置课程：** 阶段 1，第 01 课（线性代数直觉）
**预计时间：** ~60 分钟

## 学习目标

- 构建包含逐元素操作、矩阵乘法、转置、行列式和逆矩阵的 Matrix 类
- 区分逐元素乘法和矩阵乘法，并解释各自适用的场景
- 仅使用从零构建的 Matrix 类实现一个单层密集神经网络（`relu(W @ x + b)`）
- 解释广播规则以及偏置相加在神经网络框架中的工作原理

## 问题

你想构建一个神经网络。你阅读代码并看到：

```
output = activation(weights @ input + bias)
```

那个 `@` 是矩阵乘法。`weights` 是一个矩阵。`input` 是一个向量。如果你不知道这些操作做什么，这行代码就是黑魔法。如果你知道，这就是一个层在三步操作中的完整前向传播。

你的模型处理的每张图片都是像素值的矩阵。每个词嵌入都是向量。每个神经网络的每一层都是矩阵变换。你不能在不熟练掌握矩阵操作的情况下构建 AI 系统，就如同你不能在不理解变量的情况下编写代码一样。

本课从零建立这种熟练度。

## 概念

### 向量：有序的数字列表

向量是具有方向和大小的数字列表。在 AI 中，向量代表数据点、特征或参数。

```
v = [3, 4]        -- 二维向量
w = [1, 0, -2]    -- 三维向量
```

二维向量 `[3, 4]` 指向平面上的坐标 (3, 4)。其长度（模）为 5（3-4-5 三角形）。

### 矩阵：数字网格

矩阵是一个二维网格。行和列。m x n 的矩阵有 m 行 n 列。

```
A = | 1  2  3 |     -- 2x3 矩阵（2 行，3 列）
    | 4  5  6 |
```

在神经网络中，权重矩阵将输入向量变换为输出向量。一个有 784 个输入和 128 个输出的层使用 128x784 的权重矩阵。

### 为什么形状很重要

矩阵乘法有严格的规则：`(m x n) @ (n x p) = (m x p)`。内部维度必须匹配。

```
(128 x 784) @ (784 x 1) = (128 x 1)
   权重        输入        输出

内部维度: 784 = 784  -- 有效
```

如果你在 PyTorch 中遇到形状不匹配的错误，原因就是这个。

### 操作映射

| 操作 | 做什么 | 神经网络中的用途 |
|------|-------|----------------|
| 加法 | 逐元素组合 | 将偏置加到输出 |
| 标量乘法 | 缩放每个元素 | 学习率 * 梯度 |
| 矩阵乘法 | 变换向量 | 层前向传播 |
| 转置 | 翻转行和列 | 反向传播 |
| 行列式 | 单个数摘要 | 检查可逆性 |
| 逆 | 撤销变换 | 解线性方程组 |
| 单位矩阵 | 什么都不做的矩阵 | 初始化、残差连接 |

### 逐元素乘法 vs 矩阵乘法

这个区分经常绊倒初学者。

逐元素乘法：对应位置相乘。两个矩阵必须有相同的形状。

```
| 1  2 |   | 5  6 |   | 5  12 |
| 3  4 | * | 7  8 | = | 21 32 |
```

矩阵乘法：行和列的点积。内部维度必须匹配。

```
| 1  2 |   | 5  6 |   | 1*5+2*7  1*6+2*8 |   | 19  22 |
| 3  4 | @ | 7  8 | = | 3*5+4*7  3*6+4*8 | = | 43  50 |
```

不同的操作，不同的结果，不同的规则。

### 广播

当你将一个偏置向量加到输出矩阵时，形状不匹配。广播会拉伸较小的数组使其适配。

```
| 1  2  3 |   +   [10, 20, 30]
| 4  5  6 |

广播将向量跨行拉伸：

| 1  2  3 |   | 10  20  30 |   | 11  22  33 |
| 4  5  6 | + | 10  20  30 | = | 14  25  36 |
```

每个现代框架都自动执行此操作。理解它可以在形状看似不对但代码能运行时防止困惑。

## 构建它

### 步骤 1：Vector 类

```python
class Vector:
    def __init__(self, data):
        self.data = list(data)
        self.size = len(self.data)

    def __repr__(self):
        return f"Vector({self.data})"

    def __add__(self, other):
        return Vector([a + b for a, b in zip(self.data, other.data)])

    def __sub__(self, other):
        return Vector([a - b for a, b in zip(self.data, other.data)])

    def __mul__(self, scalar):
        return Vector([x * scalar for x in self.data])

    def dot(self, other):
        return sum(a * b for a, b in zip(self.data, other.data))

    def magnitude(self):
        return sum(x ** 2 for x in self.data) ** 0.5
```

### 步骤 2：带核心操作的 Matrix 类

```python
class Matrix:
    def __init__(self, data):
        self.data = [list(row) for row in data]
        self.rows = len(self.data)
        self.cols = len(self.data[0])
        self.shape = (self.rows, self.cols)

    def matmul(self, other):
        return Matrix([
            [
                sum(self.data[i][k] * other.data[k][j] for k in range(self.cols))
                for j in range(other.cols)
            ]
            for i in range(self.rows)
        ])

    def transpose(self):
        return Matrix([
            [self.data[j][i] for j in range(self.rows)]
            for i in range(self.cols)
        ])
```

### 步骤 3：单层神经网络

```python
def forward(X, W, b):
    return relu(W.matmul(X).add_col_vector(b))
```

完整实现见 `code/matrix_from_scratch.py`。

## 练习

1. 实现矩阵乘法并使用已知输入验证
2. 计算 3x3 矩阵的行列式和逆矩阵
3. 使用你的 Matrix 类实现一个带有 ReLU 激活的单密集层的前向传播
4. 解释为什么 (128x784) @ (784x1) 有效，而 (784x128) @ (784x1) 无效

## 关键术语

| 术语 | 人们常说的 | 实际含义 |
|------|-----------|---------|
| 矩阵乘法 | "矩阵相乘" | 行与列的点积组合 |
| 转置 | "翻转" | 交换矩阵的行和列 |
| 行列式 | "缩放因子" | 矩阵变换施加的面积/体积缩放 |
| 逆 | "撤销" | 反转变换的矩阵，当它存在时 |
| 广播 | "自动拉伸" | 扩展较小数组以匹配较大数组的形状进行逐元素操作 |