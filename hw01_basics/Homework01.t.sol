// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Voting} from "./Voting.sol";
import {Algorithms} from "./Algorithms.sol";

contract Homework01Test is Test {
    Voting public voting;
    Algorithms public algo;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        voting = new Voting();
        algo = new Algorithms();
    }

    // --- Voting Tests ---

    function test_VoteAndGetVotes() public {
        voting.vote("Alice");
        voting.vote("Alice");
        voting.vote("Bob");

        assertEq(voting.getVotes("Alice"), 2);
        assertEq(voting.getVotes("Bob"), 1);
        assertEq(voting.getVotes("Charlie"), 0);
    }

    function test_ResetVotes_ByOwner() public {
        voting.vote("Alice");
        voting.vote("Bob");

        voting.resetVotes();

        assertEq(voting.getVotes("Alice"), 0);
        assertEq(voting.getVotes("Bob"), 0);
    }

    function test_ResetVotes_RevertWhen_NonOwner() public {
        voting.vote("Alice");

        vm.prank(alice);
        vm.expectRevert(Voting.Unauthorized.selector);
        voting.resetVotes();
    }

    function test_Vote_RevertWhen_EmptyName() public {
        vm.expectRevert(Voting.EmptyCandidateName.selector);
        voting.vote("");
    }

    // --- Algorithms Tests ---

    function test_ReverseString() public view {
        assertEq(algo.reverseString("abcde"), "edcba");
        assertEq(algo.reverseString("Solidity"), "ytidiloS");
        assertEq(algo.reverseString("A"), "A");
        assertEq(algo.reverseString(""), "");
    }

    function test_IntToRoman() public view {
        assertEq(algo.intToRoman(3), "III");
        assertEq(algo.intToRoman(4), "IV");
        assertEq(algo.intToRoman(9), "IX");
        assertEq(algo.intToRoman(58), "LVIII");
        assertEq(algo.intToRoman(1994), "MCMXCIV");
    }

    function test_RomanToInt() public view {
        assertEq(algo.romanToInt("III"), 3);
        assertEq(algo.romanToInt("IV"), 4);
        assertEq(algo.romanToInt("IX"), 9);
        assertEq(algo.romanToInt("LVIII"), 58);
        assertEq(algo.romanToInt("MCMXCIV"), 1994);
    }

    function test_MergeSortedArrays() public view {
        uint256[] memory a = new uint256[](3);
        a[0] = 1;
        a[1] = 3;
        a[2] = 5;

        uint256[] memory b = new uint256[](3);
        b[0] = 2;
        b[1] = 4;
        b[2] = 6;

        uint256[] memory merged = algo.mergeSortedArrays(a, b);
        assertEq(merged.length, 6);
        assertEq(merged[0], 1);
        assertEq(merged[1], 2);
        assertEq(merged[2], 3);
        assertEq(merged[3], 4);
        assertEq(merged[4], 5);
        assertEq(merged[5], 6);
    }

    function test_BinarySearch() public view {
        uint256[] memory arr = new uint256[](7);
        arr[0] = 2;
        arr[1] = 5;
        arr[2] = 8;
        arr[3] = 12;
        arr[4] = 16;
        arr[5] = 23;
        arr[6] = 38;

        (bool found, uint256 index) = algo.binarySearch(arr, 16);
        assertTrue(found);
        assertEq(index, 4);

        (bool found2, uint256 index2) = algo.binarySearch(arr, 2);
        assertTrue(found2);
        assertEq(index2, 0);

        (bool found3, uint256 index3) = algo.binarySearch(arr, 38);
        assertTrue(found3);
        assertEq(index3, 6);

        (bool notFound,) = algo.binarySearch(arr, 99);
        assertFalse(notFound);
    }
}
