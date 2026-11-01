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
        require(num >= 1 && num <= 3999, "Out of range");
        uint16[13] memory values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
        string[13] memory symbols = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"];
        string memory result;

        for (uint256 i = 0; i < 13; i++) {
            while (num >= values[i]) {
                result = string.concat(result, symbols[i]);
                num -= values[i];
            }
        }

        return result;
    }

    function _charToVal(bytes1 c) private pure returns (uint256) {
        if (c == "I") return 1;
        if (c == "V") return 5;
        if (c == "X") return 10;
        if (c == "L") return 50;
        if (c == "C") return 100;
        if (c == "D") return 500;
        if (c == "M") return 1000;
        revert("Invalid Roman numeral");
    }

    /**
     * @notice 3. 罗马数字转整数 (Roman to Integer)
     * 题目描述：输入 "LVIII"，输出 58；输入 "MCMXCIV"，输出 1994
     * 注意：在 Solidity 中处理减法时注意防范 uint256 下溢 (Underflow)
     */
    function romanToInt(string memory s) public pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 len = b.length;
        require(len > 0, "Empty string");
        uint256 total = 0;
        uint256 i = 0;

        while (i < len) {
            uint256 current = _charToVal(b[i]);

            if (i + 1 < len) {
                uint256 nextVal = _charToVal(b[i + 1]);
                if (current < nextVal) {
                    total += nextVal - current;
                    i += 2;
                    continue;
                }
            }

            total += current;
            i += 1;
        }

        return total;
    }

    /**
     * @notice 4. 合并两个有序数组 (Merge Sorted Array)
     * 题目描述：输入 [1, 3, 5] 与 [2, 4, 6]，输出升序排列的 [1, 2, 3, 4, 5, 6]
     */
    function mergeSortedArrays(uint256[] memory a, uint256[] memory b) public pure returns (uint256[] memory) {
        uint256 lenA = a.length;
        uint256 lenB = b.length;
        uint256[] memory merged = new uint256[](lenA + lenB);
        uint256 i = 0;
        uint256 j = 0;
        uint256 k = 0;

        while (i < lenA && j < lenB) {
            if (a[i] < b[j]) {
                merged[k] = a[i];
                i++;
            } else {
                merged[k] = b[j];
                j++;
            }
            k++;
        }

        while (i < lenA) {
            merged[k] = a[i];
            i++;
            k++;
        }

        while (j < lenB) {
            merged[k] = b[j];
            j++;
            k++;
        }

        return merged;
    }

    /**
     * @notice 5. 二分查找 (Binary Search)
     * 题目描述：在升序有序数组 arr 中查找目标值 target
     * 返回值：(bool found, uint256 index)
     */
    function binarySearch(uint256[] memory arr, uint256 target) public pure returns (bool found, uint256 index) {
        if (arr.length == 0) return (false, 0);
        uint256 low = 0;
        uint256 high = arr.length;
        while (low < high) {
            uint256 mid = low + (high - low) / 2;
            if (target == arr[mid]) {
                return (true, mid);
            } else if (arr[mid] < target) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }

        return (false, 0);
    }
}
