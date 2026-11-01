// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Voting (学员实战练习)
 * @dev 作业1：投票合约
 *
 * 任务要求：
 * 1. 一个 mapping 来存储候选人的得票数
 * 2. 一个 vote 函数，允许用户投票给某个候选人
 * 3. 一个 getVotes 函数，返回某个候选人的得票数
 * 4. 一个 resetVotes 函数，重置所有候选人的得票数
 *
 * 验证方式：
 * 编写完成后在项目根目录下运行 `forge test --match-path test/Homework01.t.sol` 验证测试是否全绿
 */
contract Voting {
    // 声明存储候选人得票数的 mapping，以及 Owner 地址
    mapping(string => uint256) private _votes;
    string[] private _candidates;
    mapping(string => bool) private _isCandidate;

    address public immutable owner;

    event Voted(string candidate, uint256 newVoteCount, address indexed voter);
    event VotesReset(address indexed by);

    error Unauthorized();
    error EmptyCandidateName();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice 给指定候选人投票
     * @param candidate 候选人姓名
     */
    function vote(string calldata candidate) external {
        // 请实现投票逻辑
        // 检查姓名非空；更新票数；触发 Voted 事件
        if (bytes(candidate).length == 0) revert EmptyCandidateName();

        if (!_isCandidate[candidate]) {
            _isCandidate[candidate] = true;
            _candidates.push(candidate);
        }

        _votes[candidate] += 1;

        emit Voted(candidate, _votes[candidate], msg.sender);
    }

    /**
     * @notice 查询指定候选人的得票数
     * @param candidate 候选人姓名
     */
    function getVotes(string calldata candidate) external view returns (uint256) {
        // 请返回候选人的得票数
        if (!_isCandidate[candidate]) revert EmptyCandidateName();

        return _votes[candidate];
    }

    /**
     * @notice 重置所有候选人的得票数（仅限 Owner）
     */
    function resetVotes() external onlyOwner {
        uint256 len = _candidates.length;
        for (uint256 i = 0; i < len; i++) {
            string memory name = _candidates[i];
            delete _votes[name];
            delete _isCandidate[name];
        }
        delete _candidates;

        emit VotesReset(msg.sender);
    }
}
