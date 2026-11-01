// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BeggingContract} from "./BeggingContract.sol";

contract BeggingContractTest is Test {
    BeggingContract public begging;

    address public owner;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public david = makeAddr("david");

    function setUp() public {
        owner = address(this);
        begging = new BeggingContract();

        // 为测试账户分配以太币
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
        vm.deal(david, 10 ether);
    }

    function test_DonateAndGetDonation() public {
        vm.prank(alice);
        begging.donate{value: 1 ether}();

        assertEq(begging.getDonation(alice), 1 ether);
        assertEq(address(begging).balance, 1 ether);

        vm.prank(alice);
        begging.donate{value: 0.5 ether}();
        assertEq(begging.getDonation(alice), 1.5 ether);
        assertEq(address(begging).balance, 1.5 ether);
    }

    function test_Withdraw_ByOwner() public {
        vm.prank(alice);
        begging.donate{value: 2 ether}();

        uint256 ownerBalanceBefore = owner.balance;
        begging.withdraw();

        assertEq(address(begging).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + 2 ether);
    }

    function test_Withdraw_RevertWhen_NonOwner() public {
        vm.prank(alice);
        begging.donate{value: 1 ether}();

        vm.prank(alice);
        vm.expectRevert(BeggingContract.Unauthorized.selector);
        begging.withdraw();
    }

    function test_RevertWhen_ZeroDonation() public {
        vm.prank(alice);
        vm.expectRevert(BeggingContract.ZeroDonation.selector);
        begging.donate{value: 0}();
    }

    function test_TopDonorsRanking() public {
        vm.prank(alice);
        begging.donate{value: 1 ether}();

        vm.prank(bob);
        begging.donate{value: 3 ether}();

        vm.prank(charlie);
        begging.donate{value: 2 ether}();

        vm.prank(david);
        begging.donate{value: 4 ether}();

        (address[3] memory donors, uint256[3] memory amounts) = begging.getTopDonors();

        // 排名应为: 1st David (4 ether), 2nd Bob (3 ether), 3rd Charlie (2 ether)
        assertEq(donors[0], david);
        assertEq(amounts[0], 4 ether);

        assertEq(donors[1], bob);
        assertEq(amounts[1], 3 ether);

        assertEq(donors[2], charlie);
        assertEq(amounts[2], 2 ether);
    }

    function test_ReceiveFallbackDonation() public {
        vm.prank(alice);
        (bool success, ) = address(begging).call{value: 0.8 ether}("");
        assertTrue(success);

        assertEq(begging.getDonation(alice), 0.8 ether);
        assertEq(address(begging).balance, 0.8 ether);
    }

    // 支持接收提款 ETH
    receive() external payable {}
}
