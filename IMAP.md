# IMAP

- Paper: I’m a Map! Interpretable Motion-Attentive Maps: Spatio-Temporally Localizing Concepts in Video Diffusion Transformers
- URL: https://arxiv.org/pdf/2603.02919v1
- Output style: 中文，学术，结构化
- Confidence tags: `[Fact]` / `[Inference]` / `[Missing]`

---

## 1. 研究问题与核心贡献

- [Fact] 论文关注 Video Diffusion Transformer 中“运动词如何映射到视频中的时空区域”这一可解释性问题。  
- [Fact] 提出 GramCol：无需额外训练、无需梯度回传，可为任意概念生成逐帧显著图。  
- [Fact] 提出 IMAP（Interpretable Motion-Attentive Map）：在 GramCol 基础上加入 motion head 选择，增强运动概念的时空定位。  
- [Fact] 在 CogVideoX-2B/5B、HunyuanVideo 上，IMAP 在运动定位任务中优于 Cross Attention 和 ConceptAttention。  
- [Inference] 方法核心价值是“读取并解释已有 Video DiT 的内部机制”，而不是训练新的生成模型。

## 2. 模型结构（详细版）

### 2.1 整体输入输出

- 输入：文本提示词（含概念词）+ Video DiT 中间特征。  
- 输出：
  - 非运动概念 -> GramCol 显著图（偏空间定位）
  - 运动概念 -> IMAP 显著图（空间 + 时间定位）

### 2.2 流程分解（工程视角）

1) 时间步筛选（Timestep Filtering）  
- [Fact] 过滤早期 denoising 步（语义弱、噪声大、可能出现 watermark-like 特征）。  
- [Inference] 这样可降低伪显著区域，提高定位稳定性。

2) 层筛选（Layer Filtering）  
- [Fact] 使用注意力矩阵的二大特征值指标（平均 lambda2）筛层。  
- [Fact] 阈值示例：CogVideoX > 0.7，HunyuanVideo > 0.75。  
- [Inference] 高 lambda2 层一般语义结构更清晰。

3) 概念代理 token 选择（QK Matching）  
- [Fact] 在选中层/步中，用 Query-Key 匹配找到最对应概念词的视觉 token（text-surrogate token）。  
- [Inference] 这一步相当于定位“概念在视觉侧的锚点”。

4) GramCol 生成  
- [Fact] 从视频 token 表征构建 Gram 矩阵，再抽取概念相关响应，得到逐帧显著图。  
- [Fact] 不需要参数更新或反向传播。

5) Motion Head 选择（仅运动概念）  
- [Fact] 用 CHI（Calinski-Harabasz Index）评估 head 的时序分离能力，取 top-k（文中常用 top-5）。  
- [Fact] 仅聚合这些 head 的响应，得到 IMAP。  
- [Inference] 这一步提升“谁在动、何时动”的时空可解释性。

### 2.3 纯文本流程图

```text
[文本提示 + 概念词]
          |
          v
[Video DiT 中间特征]
          |
          v
[时间步筛选：去掉早期高噪声步]
          |
          v
[层筛选：按平均 lambda2 选语义层]
          |
          v
[QK匹配：找到概念对应的 surrogate token]
          |
          v
[GramCol计算：得到概念显著图]
          |
          +------------------------------+
          |                              |
          | 非运动概念                   | 运动概念
          v                              v
 [输出 GramCol 空间图]         [CHI打分选Top-k motion heads]
                                          |
                                          v
                                [聚合得到 IMAP 时空图]
```

## 3. 创新点 vs 现有方法（含 baseline）

- [Fact] baseline 涵盖 ViCLIP、DAAM、Cross Attention、ConceptAttention。  
- [Fact] 相比已有方法，IMAP 主要创新是“motion-head 选择 + training-free 的概念读出”。  
- [Fact] 与纯注意力聚合相比，IMAP 在运动定位五项指标上更稳、更清晰。  
- [Inference] 本文是“可解释读出算法创新”，不是 backbone 创新。

## 4. 实现细节（数据、超参、耗时）

- [Fact] 评测运动定位时，构建了 MeViS 相关数据子集（49帧切片，过滤无运动样本）。  
- [Fact] 使用 CHI 做 motion head 分离度打分，通常选 top-5 heads。  
- [Fact] 模型使用 CogVideoX / HunyuanVideo；并采用层阈值规则筛选。  
- [Fact] 附录给出阶段耗时（A100 80GB，CogVideoX-5B）：
  - Video Encode: 约 10.79s
  - Diffusion Inference: 约 58.67s
  - Query-Key Matching: 约 0.083s
  - Motion Head Selection: 约 10.35s
  - Map Save: 约 7.17s
- [Missing] 论文未给完整跨硬件统一吞吐对比（例如 FPS benchmark）。

## 5. 实验效果（主结果 + 消融）

### 5.1 运动定位主结果（Table 1）

- [Fact] IMAP 在三类 Video DiT backbone 上整体优于 Cross Attention 和 ConceptAttention。  
- [Fact] 例如 CogVideoX-5B：IMAP 平均分约 0.62，高于 ConceptAttention 约 0.45 和 Cross Attention 约 0.36。  

### 5.2 消融（Table 2）

- [Fact] 从 GramCol(all layers) -> +layer selection -> +motion head -> +both(IMAP) 逐步提升。  
- [Fact] IMAP + softmax 在部分指标提升，但论文指出可能影响帧间一致性。  

### 5.3 Zero-shot VSS（Table 3）

- [Fact] 在“Video DiT 可解释图方法”中，GramCol mIoU 最优（高于 Cross Attention / ConceptAttention）。  
- [Fact] 但与专门分割模型相比仍有差距。  
- [Inference] 更适合“可解释定位信号”，不直接替代 SOTA 分割器。

## 6. 复现难点与风险

- [Fact] 依赖模型内部张量接口（多头注意力、双流结构等），工程接入门槛高。  
- [Fact] 评估里含 LLM 评分协议（MLS），提示词和打分规范不一致会带来波动。  
- [Risk] motion head 阈值对不同 backbone 可能不通用，需要重新标定。  
- [Risk] 若不做时间步过滤，容易出现噪声/伪显著区域。  
- [Missing] 主文对完整开源复现脚本细节披露有限，需结合补充材料与后续代码仓库。
