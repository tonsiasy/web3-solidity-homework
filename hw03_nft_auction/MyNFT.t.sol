// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MyNFT} from "./MyNFT.sol";

contract MyNFTTest is Test {
    MyNFT public nft;
    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    string constant SAMPLE_URI_1 = "ipfs://QmTokenUri1";
    string constant SAMPLE_URI_2 = "ipfs://QmTokenUri2";

    function setUp() public {
        nft = new MyNFT("AuctionNFT", "ANFT");
    }

    function test_InitialState() public view {
        assertEq(nft.name(), "AuctionNFT");
        assertEq(nft.symbol(), "ANFT");
        assertEq(nft.owner(), owner);
    }

    function test_MintSuccess() public {
        uint256 tokenId1 = nft.mint(user1, SAMPLE_URI_1);
        assertEq(tokenId1, 1);
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.tokenURI(1), SAMPLE_URI_1);

        uint256 tokenId2 = nft.mint(user2, SAMPLE_URI_2);
        assertEq(tokenId2, 2);
        assertEq(nft.ownerOf(2), user2);
        assertEq(nft.tokenURI(2), SAMPLE_URI_2);
    }

    function test_RevertWhen_NonOwnerMints() public {
        vm.prank(user1);
        // OpenZeppelin v5 OwnableUnauthorizedAccount error
        vm.expectRevert();
        nft.mint(user1, SAMPLE_URI_1);
    }

    function test_TransferAndApprove() public {
        uint256 tokenId = nft.mint(user1, SAMPLE_URI_1);

        vm.startPrank(user1);
        nft.approve(user2, tokenId);
        assertEq(nft.getApproved(tokenId), user2);

        nft.transferFrom(user1, user2, tokenId);
        assertEq(nft.ownerOf(tokenId), user2);
        vm.stopPrank();
    }
}
