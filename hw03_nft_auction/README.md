# Homework 03: NFT 拍卖市场 (综合大作业)

本项目是「基础二：Solidity 智能合约基础」第 3 周结营综合大作业工程。采用 **UUPS 代理可升级架构**，集成 **Chainlink 价格预言机（Data Feeds）** 实现多币种（ETH & ERC20）统一美元估值竞价，并遵循 **Pull-over-Push（拉式提款）** 与 **CEI（Checks-Effects-Interactions）** 安全范式。

---

## 🚀 链上部署与验证记录 (Sepolia Testnet)

| 合约组件 | 链上部署地址 | Etherscan 浏览器链接 |
|---|---|---|
| **MyNFT (ERC721)** | `0x0DB4783E5DC6f1A77A632DBB451E4d50702523E2` | [查看合约](https://sepolia.etherscan.io/address/0x0DB4783E5DC6f1A77A632DBB451E4d50702523E2) |
| **AuctionMarket (逻辑实现 V1)** | `0xBB473653D44c65176489D264e75e785cFadb8FB0` | [查看实现合约](https://sepolia.etherscan.io/address/0xBB473653D44c65176489D264e75e785cFadb8FB0) |
| **AuctionMarket (ERC1967 代理)** | `0x0D4c70C66f422641843EFd44Ed8100e400aBa42B` | [查看代理合约](https://sepolia.etherscan.io/address/0x0D4c70C66f422641843EFd44Ed8100e400aBa42B) |

### 关键交易哈希
- **MyNFT 部署**：[`0xd4168469fbce25be846c1b1cf364296737d369a7085c4aa1461c4c463c5dbc83`](https://sepolia.etherscan.io/tx/0xd4168469fbce25be846c1b1cf364296737d369a7085c4aa1461c4c463c5dbc83)
- **AuctionMarket 实现部署**：[`0xbcb861a26182d30ce45080c29d3484c534b386c46dead0549751dbe302e8b431`](https://sepolia.etherscan.io/tx/0xbcb861a26182d30ce45080c29d3484c534b386c46dead0549751dbe302e8b431)
- **ERC1967 代理部署并初始化**：[`0x8d70d43c69bbb6c922dc1c9040d537e0332e325e1029d404092181e54641347d`](https://sepolia.etherscan.io/tx/0x8d70d43c69bbb6c922dc1c9040d537e0332e325e1029d404092181e54641347d)

---

## 🏗️ 架构与安全设计

### 1. UUPS (Universal Upgradeable Proxy Standard) 可升级架构
- 代理合约（`ERC1967Proxy`）仅负责维持状态存储与通过 `fallback` 执行 `delegatecall`。
- 逻辑合约（`AuctionMarket`）继承 `Initializable`, `UUPSUpgradeable`, `OwnableUpgradeable`。
- 升级授权钩子 `_authorizeUpgrade(address newImplementation)` 受 `onlyOwner` 权限严格守护。
- 构造函数内置 `_disableInitializers()` 锁定逻辑合约本身，防止未初始化漏洞。

### 2. Chainlink 预言机跨币种估值折算
- 接入 Sepolia 官方 ETH/USD 喂价源：`0x694AA1769357215DE4FAC081bf1f309aDC325306`（8位精度）。
- 支持管理员通过 `setTokenPriceFeed` 动态注册任意 ERC20 代币（如 USDC/USDT）的 Chainlink 喂价。
- 在出价处理函数中，通过 `(amount * price) / (10 ** tokenDecimals)` 统一折算为 8 位精度的 USD 价值，实现 ETH 与 ERC20 竞标价值的公平裁决与动态跨币种反超。

### 3. Pull-over-Push 退款安全机制
- 被超越竞标者的资金不采用同步转账（`call.value`），避免恶意合约拒绝接收造成拒绝服务（DoS 攻击）。
- 被超越资金统一记入 `pendingReturns[bidder][token]`，由竞价者主动调用 `withdrawRefund(token)` 提取。

---

## 🧪 自动化测试验证 (19/19 Tests Pass)

采用 Foundry 编写全量单元测试与端到端集成测试，覆盖率与测试用例明细：

```bash
# 执行 HW03 全量测试
forge test --match-path "hw03_nft_auction/*" -vvv
```

### 测试用例结果矩阵

#### 1. `MyNFT.t.sol` (4/4 Pass)
- `test_InitialState`: 验证 NFT 名称与符号
- `test_MintSuccess`: 验证铸造、TokenId 自增与元数据 URI 绑定
- `test_RevertWhen_NonOwnerMints`: 验证非管理员铸造回滚权限
- `test_TransferAndApprove`: 验证转移与授权完整生命周期

#### 2. `AuctionMarket.t.sol` (15/15 Pass)
- `test_Initialization`: 验证代理初始化状态、所有者与预言机喂价配置
- `test_RevertWhen_ReinitializingImplementationOrProxy`: 验证重初始化保护（防劫持）
- `test_CreateAuction_Success`: 验证拍卖创建与 NFT 质押托管
- `test_RevertWhen_CreateAuctionWithInvalidParams`: 验证参数合法性校验
- `test_BidWithETH_Success`: 验证原生以太币竞价折算 USD 逻辑
- `test_BidWithERC20_OutbidsETH`: 验证 ERC20（USDC）出价成功反超 ETH 出价
- `test_WithdrawRefund_PullOverPush`: 验证被反超资金的主动提取与防止重放提取
- `test_OracleDynamicPriceChange_AffectsBidding`: 验证预言机价格波动对竞价排名的即时动态响应
- `test_RevertWhen_BidTooLow`: 验证低于起拍价或最高价的出价拦截
- `test_EndAuction_WithWinner_ETH`: 验证 ETH 获胜者收货与卖家收款结算
- `test_EndAuction_WithWinner_ERC20`: 验证 ERC20 获胜者收货与卖家收款结算
- `test_EndAuction_NoBids_ReturnsNFTToSeller`: 验证流拍场景下 NFT 完整原路退回
- `test_RevertWhen_EndAuctionTwice`: 验证不可重复结算
- `test_UUPS_Upgrade_Success`: **验证 UUPS 代理无损升级（V1 -> V2），原有状态/拍卖完全保留且新功能生效**
- `test_RevertWhen_NonOwnerAttemptsUpgrade`: 验证非所有者无法执行代理升级

---

## 💻 链上交互验证 (Cast 验证指令)

可以通过以下命令直接向 Sepolia 测试网验证部署状态：

```bash
# 1. 查询拍卖市场代理合约所有者
cast call 0x0D4c70C66f422641843EFd44Ed8100e400aBa42B "owner()(address)" --rpc-url https://rpc.sepolia.org

# 2. 查询 ERC1967 逻辑实现存储槽 (验证指向 0xBB473653D44c65176489D264e75e785cFadb8FB0)
cast storage 0x0D4c70C66f422641843EFd44Ed8100e400aBa42B 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url https://rpc.sepolia.org

# 3. 实时调用拍卖合约折算 1 个 ETH 当前的 USD 估值 (来自 Chainlink 喂价)
cast call 0x0D4c70C66f422641843EFd44Ed8100e400aBa42B "getEthValueInUsd(uint256)(uint256)" 1000000000000000000 --rpc-url https://rpc.sepolia.org
```
