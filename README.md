# Solidity 智能合约基础作业仓库

本仓库用于归档「基础二：Solidity 智能合约基础」各阶段课后作业，每个章节作业对应一个独立文件夹，统一基于 **Foundry** 工具链进行编译与单元测试。

## 📁 目录结构

```text
homework/
├── foundry.toml               # Foundry 工作区配置
├── hw01_basics/               # 作业 1：Voting 投票合约 + 5 道算法实现
│   ├── Voting.sol             # [待实现] 投票合约
│   ├── Algorithms.sol         # [待实现] 5 道算法练习
│   └── Homework01.t.sol       # 作业 1 自动化单元测试
├── hw02_begging/              # 作业 2：讨饭合约 (BeggingContract)
│   ├── BeggingContract.sol    # [待实现] 讨饭合约
│   ├── BeggingContract.t.sol  # 作业 2 自动化单元测试
│   └── DeployBegging.s.sol    # Sepolia 测试网部署脚本
└── hw03_nft_auction/          # 作业 3：NFT 拍卖市场大作业（ERC721 + Chainlink + UUPS）
    └── README.md              # 大作业任务目标与架构要求
```

## 🧪 本地测试指令

在 `homework/` 根目录下执行：

```bash
# 运行全部作业测试
forge test -vvv

# 仅运行作业 1 测试
forge test --match-path "hw01_basics/*" -vvv

# 仅运行作业 2 测试
forge test --match-path "hw02_begging/*" -vvv
```

## 🚀 提交至个人 GitHub 仓库

```bash
cd 03_Solidity_Basics/homework
git add .
git commit -m "feat: complete solidity homework"
git remote add origin git@github.com:tonsiasy/web3-solidity-homework.git
git push -u origin main
```
