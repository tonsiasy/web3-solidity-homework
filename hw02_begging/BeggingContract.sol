// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BeggingContract (学员实战练习)
 * @dev 作业2：编写一个讨饭合约
 *
 * 任务目标：
 * 1. 允许用户向合约地址发送以太币 (donate)。
 * 2. 记录每个捐赠者的地址和捐赠金额。
 * 3. 允许合约所有者提取所有捐赠的资金 (withdraw)。
 * 4. 允许查询某个地址的捐赠金额 (getDonation)。
 * 
 * 额外挑战：
 * 5. 触发 Donation 事件记录每次捐赠。
 * 6. 捐赠排行榜：实现 getTopDonors() 显示捐赠金额最多的前 3 个地址。
 */
contract BeggingContract {
    address public immutable owner;

    // TODO 1: 声明用于记录捐赠者金额的 mapping 及其他必要状态变量

    event Donation(address indexed donor, uint256 amount, uint256 totalDonatedByDonor);
    event Withdrawn(address indexed owner, uint256 amount);

    error Unauthorized();
    error ZeroDonation();
    error NoFundsToWithdraw();
    error WithdrawTransferFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice 用户向合约发送以太币，记录捐赠信息
     */
    function donate() external payable {
        // TODO 2: 请实现捐赠逻辑
        // 要求：检查 msg.value > 0；累加捐赠金额；触发 Donation 事件
        revert("TODO: Please implement donate()");
    }

    /**
     * @notice 查询某个地址的累计捐赠金额
     * @param donor 查询的捐赠者地址
     */
    function getDonation(address donor) external view returns (uint256) {
        // TODO 3: 请返回该地址累计捐赠金额
        revert("TODO: Please implement getDonation()");
    }

    /**
     * @notice 合约所有者提取所有资金
     */
    function withdraw() external onlyOwner {
        // TODO 4: 请实现所有者提款逻辑
        // 提示：考虑使用 call{value: balance}("") 方式转账
        revert("TODO: Please implement withdraw()");
    }

    /**
     * @notice 额外挑战：获取捐赠排行榜前 3 名
     */
    function getTopDonors() external view returns (address[3] memory donors, uint256[3] memory amounts) {
        // TODO 5: 请实现前三大捐助者查询逻辑
        revert("TODO: Please implement getTopDonors()");
    }

    /**
     * @notice 支持直接向合约地址转账自动记入捐款
     */
    receive() external payable {
        // TODO 6: 处理纯 ETH 转账逻辑
    }
}
