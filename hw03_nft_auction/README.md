# Homework 03: NFT 拍卖市场 (大作业)

本项目是「基础二：Solidity 智能合约基础」第 3 周综合大作业工程。

## 🎯 任务目标与技术要求

1. **NFT 合约 (`ERC721`)**：
   - 基于 OpenZeppelin `ERC721` 标准实现。
   - 支持铸造（mint）与授权转移。
2. **拍卖市场合约 (`AuctionMarket`)**：
   - **创建拍卖**：允许卖家上架 NFT，设置起拍价与持续时间，NFT 质押进合约托管。
   - **出价参与**：支持以以太坊（ETH）或 ERC20 代币出价，自动竞价退款机制。
   - **结束结算**：到期结算，最高出价者获得 NFT，资金划转给卖家。
3. **集成 Chainlink 预言机**：
   - 接入 Chainlink `feedData` 预言机获取 ETH/USD 与 ERC20/USD 汇率。
   - 将出价统一换算为 USD 美元估值进行精准比对。
4. **合约可升级性**：
   - 采用 **UUPS**（通用可升级代理模式）实现业务逻辑平滑升级。
5. **测试与部署**：
   - 编写 Foundry 单元测试与端到端集成测试，覆盖竞价、结算与升级流程。
   - 部署至 Sepolia 测试网并在 Etherscan 上开源验证。

---

## 🛠️ 参考资料
- 导师参考工程：[lc3091/hardhatV3Nft](https://github.com/lc3091/hardhatV3Nft.git)
- 学习笔记：
  - [可升级合约原理](../../notes/04_Upgradeable_Contracts.md)
  - [预言机与 CCIP 集成](../../notes/05_Oracles_And_CrossChain.md)
