// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Algorithms (学员实战练习)
 * @dev 作业1：5道算法题目
 *
 * 请根据题目要求补全函数实现，并在本目录下运行 `forge test` 验证你的实现。
 */
contract Algorithms {
    /**
     * @notice 1. 反转字符串 (Reverse String)
     * 题目描述：输入 "abcde"，输出 "edcba"
     */
    function reverseString(string memory s) public pure returns (string memory) {
        bytes memory strBytes = bytes(s);
        uint256 len = strBytes.length;
        for (uint256 i = 0; i < len / 2; i++) {
            bytes1 temp = strBytes[i];
            strBytes[i] = strBytes[len - 1 - i];
            strBytes[len - 1 - i] = temp;
        }

        return string(strBytes);
    }

    /**
     * @notice 2. 整数转罗马数字 (Integer to Roman)
     * 题目描述：输入 1994，输出 "MCMXCIV"；输入 58，输出 "LVIII"
     * 范围：1 <= num <= 3999
     */
    function intToRoman(uint256 num) public pure returns (string memory) {
        // TODO: 请实现整数转罗马数字
        revert("TODO: Please implement intToRoman()");
    }

    /**
     * @notice 3. 罗马数字转整数 (Roman to Integer)
     * 题目描述：输入 "LVIII"，输出 58；输入 "MCMXCIV"，输出 1994
     * 注意：在 Solidity 中处理减法时注意防范 uint256 下溢 (Underflow)
     */
    function romanToInt(string memory s) public pure returns (uint256) {
        // TODO: 请实现罗马数字转整数
        revert("TODO: Please implement romanToInt()");
    }

    /**
     * @notice 4. 合并两个有序数组 (Merge Sorted Array)
     * 题目描述：输入 [1, 3, 5] 与 [2, 4, 6]，输出升序排列的 [1, 2, 3, 4, 5, 6]
     */
    function mergeSortedArrays(uint256[] memory a, uint256[] memory b) public pure returns (uint256[] memory) {
        // TODO: 请实现双指针归并排序算法
        revert("TODO: Please implement mergeSortedArrays()");
    }

    /**
     * @notice 5. 二分查找 (Binary Search)
     * 题目描述：在升序有序数组 arr 中查找目标值 target
     * 返回值：(bool found, uint256 index)
     */
    function binarySearch(uint256[] memory arr, uint256 target) public pure returns (bool found, uint256 index) {
        // TODO: 请实现二分查找算法
        revert("TODO: Please implement binarySearch()");
    }
}
