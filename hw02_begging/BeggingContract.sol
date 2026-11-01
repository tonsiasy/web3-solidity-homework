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

    // 声明用于记录捐赠者金额的 mapping 及其他必要状态变量
    mapping(address => uint256) private _donations;
    address[3] private _topDonors;

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
        // 要求：检查 msg.value > 0；累加捐赠金额；触发 Donation 事件
        if (msg.value == 0) revert ZeroDonation();

        _donations[msg.sender] += msg.value;
        _updateTopDonors(msg.sender);
        emit Donation(msg.sender, msg.value, _donations[msg.sender]);
    }

    /**
     * @notice 查询某个地址的累计捐赠金额
     * @param donor 查询的捐赠者地址
     */
    function getDonation(address donor) external view returns (uint256) {
        return _donations[donor];
    }

    /**
     * @notice 合约所有者提取所有资金
     */
    function withdraw() external onlyOwner {
        // 提示：考虑使用 call{value: balance}("") 方式转账
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoFundsToWithdraw();
        (bool success,) = owner.call{value: balance}("");
        if (!success) revert WithdrawTransferFailed();
        emit Withdrawn(owner, balance);
    }

    /**
     * @notice 额外挑战：获取捐赠排行榜前 3 名
     */
    function getTopDonors() external view returns (address[3] memory donors, uint256[3] memory amounts) {
        for (uint256 i = 0; i < 3; i++) {
            donors[i] = _topDonors[i];
            if (_topDonors[i] != address(0)) {
                amounts[i] = _donations[_topDonors[i]];
            }
        }
    }

    /**
     * @notice 支持直接向合约地址转账自动记入捐款
     */
    receive() external payable {
        if (msg.value > 0) {
            _donations[msg.sender] += msg.value;
            _updateTopDonors(msg.sender);
            emit Donation(msg.sender, msg.value, _donations[msg.sender]);
        }
    }

    function _updateTopDonors(address donor) internal {
        uint256 donorAmount = _donations[donor];

        // 1. 检查是否已经在Top 3, 若在先移除并向前填补
        int256 existingIndex = -1;
        for (uint256 i = 0; i < 3; i++) {
            if (_topDonors[i] == donor) {
                existingIndex = int256(i);
                break;
            }
        }

        if (existingIndex >= 0) {
            for (uint256 i = uint256(existingIndex); i < 2; i++) {
                _topDonors[i] = _topDonors[i + 1];
            }
            _topDonors[2] = address(0);
        }

        // 2. 找到比当前 donor 贡献小的第一个位置，顺移并插入
        for (uint256 i = 0; i < 3; i++) {
            address current = _topDonors[i];
            if (current == address(0) || donorAmount > _donations[current]) {
                for (uint256 j = 2; j > i; j--) {
                    _topDonors[j] = _topDonors[j - 1];
                }
                _topDonors[i] = donor;
                break;
            }
        }
    }
}
