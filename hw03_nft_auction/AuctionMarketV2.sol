// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AuctionMarket} from "./AuctionMarket.sol";

/**
 * @title AuctionMarketV2
 * @dev 供 UUPS 代理升级测试与演练的 V2 实现合约
 * 保持 V1 存储布局完全兼容，并在其尾部新增平台手续费率及版本标识
 */
contract AuctionMarketV2 is AuctionMarket {
    // 新增状态变量 (必须附加在原有存储槽之后，严禁改变原有变量顺序)
    uint256 public platformFeeBps; // 平台手续费率 (基点，如 250 代表 2.5%)

    event PlatformFeeUpdated(uint256 newFeeBps);

    function setPlatformFee(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= 1000, "Fee too high: max 10%");
        platformFeeBps = newFeeBps;
        emit PlatformFeeUpdated(newFeeBps);
    }

    function version() external pure returns (string memory) {
        return "2.0.0";
    }
}
