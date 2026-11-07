// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {AuctionMarket} from "./AuctionMarket.sol";
import {AuctionMarketV2} from "./AuctionMarketV2.sol";
import {MyNFT} from "./MyNFT.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract AuctionMarketTest is Test {
    AuctionMarket public implementation;
    ERC1967Proxy public proxy;
    AuctionMarket public market; // 代理合约包装地址

    MyNFT public nft;
    MockV3Aggregator public ethFeed;
    MockV3Aggregator public usdcFeed;
    MockERC20 public usdc;

    address public owner;
    address public seller;
    address public bidderETH;
    address public bidderUSDC;
    address public randomUser;

    uint256 public constant INITIAL_ETH_PRICE = 2000 * 1e8; // 2,000 USD (8位精度)
    uint256 public constant INITIAL_USDC_PRICE = 1 * 1e8; // 1 USD (8位精度)

    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 startingPriceUsd,
        uint256 endTime
    );
    event BidPlaced(
        uint256 indexed auctionId, address indexed bidder, address indexed bidToken, uint256 amount, uint256 bidUsdValue
    );
    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        address indexed bidToken,
        uint256 finalAmount,
        uint256 finalUsdValue
    );
    event RefundRecorded(address indexed user, address indexed token, uint256 amount);
    event RefundWithdrawn(address indexed user, address indexed token, uint256 amount);

    function setUp() public {
        owner = address(this);
        seller = makeAddr("seller");
        bidderETH = makeAddr("bidderETH");
        bidderUSDC = makeAddr("bidderUSDC");
        randomUser = makeAddr("randomUser");

        // 1. 部署 Chainlink 预言机 Mock (8位精度)
        ethFeed = new MockV3Aggregator(8, int256(INITIAL_ETH_PRICE));
        usdcFeed = new MockV3Aggregator(8, int256(INITIAL_USDC_PRICE));

        // 2. 部署 Mock USDC (6位精度)
        usdc = new MockERC20("USD Coin", "USDC", 6);

        // 3. 部署 MyNFT
        nft = new MyNFT("Test NFT", "TNFT");

        // 4. 部署 AuctionMarket UUPS 代理模式
        implementation = new AuctionMarket();
        bytes memory initData = abi.encodeCall(AuctionMarket.initialize, (address(ethFeed)));
        proxy = new ERC1967Proxy(address(implementation), initData);
        market = AuctionMarket(payable(address(proxy)));

        // 5. 配置 USDC 预言机喂价
        market.setTokenPriceFeed(address(usdc), address(usdcFeed));

        // 6. 给买家与卖家分配资金与代币
        vm.deal(seller, 10 ether);
        vm.deal(bidderETH, 10 ether);
        vm.deal(randomUser, 10 ether);

        usdc.mint(bidderUSDC, 100_000 * 1e6); // 100,000 USDC
        vm.prank(bidderUSDC);
        usdc.approve(address(market), type(uint256).max);

        // 7. 给卖家铸造 NFT (TokenId: 1) 并授权给市场合约
        nft.mint(seller, "ipfs://nft-meta-1");
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);
    }

    /* -------------------------------------------------------------------------- */
    /*                               初始化测试                                   */
    /* -------------------------------------------------------------------------- */

    function test_Initialization() public view {
        assertEq(market.owner(), owner);
        assertEq(address(market.ethUsdPriceFeed()), address(ethFeed));
        assertEq(address(market.tokenPriceFeeds(address(usdc))), address(usdcFeed));
        assertEq(market.auctionCounter(), 0);
    }

    function test_RevertWhen_ReinitializingImplementationOrProxy() public {
        // 尝试重复初始化 Proxy
        vm.expectRevert();
        market.initialize(address(ethFeed));

        // 尝试直接初始化逻辑合约 (已在构造函数通过 _disableInitializers 锁定)
        vm.expectRevert();
        implementation.initialize(address(ethFeed));
    }

    /* -------------------------------------------------------------------------- */
    /*                              创建拍卖测试                                  */
    /* -------------------------------------------------------------------------- */

    function test_CreateAuction_Success() public {
        uint256 startingPriceUsd = 100 * 1e8; // 100 USD
        uint256 duration = 1 days;

        vm.prank(seller);
        vm.expectEmit(true, true, true, false);
        emit AuctionCreated(1, seller, address(nft), 1, startingPriceUsd, block.timestamp + duration);
        uint256 auctionId = market.createAuction(address(nft), 1, startingPriceUsd, duration);

        assertEq(auctionId, 1);
        assertEq(market.auctionCounter(), 1);
        assertEq(nft.ownerOf(1), address(market)); // NFT 已质押托管在代理合约

        (
            address _seller,
            address _nftContract,
            uint256 _tokenId,
            uint256 _startingPriceUsd,
            uint256 _highestBidUsd,
            address _highestBidder,
            address _bidToken,
            uint256 _bidAmount,
            uint256 _endTime,
            bool _ended
        ) = market.auctions(1);

        assertEq(_seller, seller);
        assertEq(_nftContract, address(nft));
        assertEq(_tokenId, 1);
        assertEq(_startingPriceUsd, startingPriceUsd);
        assertEq(_highestBidUsd, 0);
        assertEq(_highestBidder, address(0));
        assertEq(_bidToken, address(0));
        assertEq(_bidAmount, 0);
        assertEq(_endTime, block.timestamp + duration);
        assertFalse(_ended);
    }

    function test_RevertWhen_CreateAuctionWithInvalidParams() public {
        vm.startPrank(seller);
        // 无效 NFT 地址
        vm.expectRevert(AuctionMarket.InvalidAddress.selector);
        market.createAuction(address(0), 1, 100 * 1e8, 1 days);

        // 起拍价为 0
        vm.expectRevert(AuctionMarket.InvalidStartingPrice.selector);
        market.createAuction(address(nft), 1, 0, 1 days);

        // 拍卖时长为 0
        vm.expectRevert(AuctionMarket.InvalidDuration.selector);
        market.createAuction(address(nft), 1, 100 * 1e8, 0);
        vm.stopPrank();
    }

    /* -------------------------------------------------------------------------- */
    /*                              竞价出价测试                                  */
    /* -------------------------------------------------------------------------- */

    function test_BidWithETH_Success() public {
        vm.prank(seller);
        market.createAuction(address(nft), 1, 100 * 1e8, 1 days); // 起拍价 $100

        // bidderETH 出价 0.1 ETH (ETH = $2000, 0.1 ETH = $200 USD)
        vm.prank(bidderETH);
        market.bidWithETH{value: 0.1 ether}(1);

        (,,,, uint256 highestBidUsd, address highestBidder, address bidToken, uint256 bidAmount,,) = market.auctions(1);

        assertEq(highestBidUsd, 200 * 1e8);
        assertEq(highestBidder, bidderETH);
        assertEq(bidToken, address(0));
        assertEq(bidAmount, 0.1 ether);
    }

    function test_BidWithERC20_OutbidsETH() public {
        vm.prank(seller);
        market.createAuction(address(nft), 1, 100 * 1e8, 1 days);

        // 1. bidderETH 先出 0.1 ETH ($200 USD)
        vm.prank(bidderETH);
        market.bidWithETH{value: 0.1 ether}(1);

        // 2. bidderUSDC 出 250 USDC ($250 USD) 成功超越
        vm.prank(bidderUSDC);
        vm.expectEmit(true, true, true, true);
        emit RefundRecorded(bidderETH, address(0), 0.1 ether);
        market.bidWithERC20(1, address(usdc), 250 * 1e6);

        (,,,, uint256 highestBidUsd, address highestBidder, address bidToken, uint256 bidAmount,,) = market.auctions(1);

        assertEq(highestBidUsd, 250 * 1e8);
        assertEq(highestBidder, bidderUSDC);
        assertEq(bidToken, address(usdc));
        assertEq(bidAmount, 250 * 1e6);

        // 3. 校验 bidderETH 资金进入待退款池 (Pull-over-Push)
        assertEq(market.pendingReturns(bidderETH, address(0)), 0.1 ether);
    }

    function test_WithdrawRefund_PullOverPush() public {
        vm.prank(seller);
        market.createAuction(address(nft), 1, 100 * 1e8, 1 days);

        // bidderETH 出价被超越
        vm.prank(bidderETH);
        market.bidWithETH{value: 0.1 ether}(1);

        vm.prank(bidderUSDC);
        market.bidWithERC20(1, address(usdc), 250 * 1e6);

        uint256 balanceBefore = bidderETH.balance;

        // bidderETH 主动提取退款
        vm.prank(bidderETH);
        vm.expectEmit(true, true, false, true);
        emit RefundWithdrawn(bidderETH, address(0), 0.1 ether);
        market.withdrawRefund(address(0));

        assertEq(bidderETH.balance, balanceBefore + 0.1 ether);
        assertEq(market.pendingReturns(bidderETH, address(0)), 0);

        // 重复提取应报错
        vm.prank(bidderETH);
        vm.expectRevert(AuctionMarket.NoPendingRefund.selector);
        market.withdrawRefund(address(0));
    }

    function test_OracleDynamicPriceChange_AffectsBidding() public {
        vm.prank(seller);
        market.createAuction(address(nft), 1, 100 * 1e8, 1 days);

        // 1. USDC 出价 250 USDC ($250 USD)
        vm.prank(bidderUSDC);
        market.bidWithERC20(1, address(usdc), 250 * 1e6);

        // 2. 模拟 Chainlink 预言机喂价动态剧烈上涨：ETH 涨至 $3,000 USD
        ethFeed.updateAnswer(3000 * 1e8);

        // 3. 此时 bidderETH 仅需出 0.1 ETH (折合 $300 USD)，即可超越 $250 USDC
        vm.prank(bidderETH);
        market.bidWithETH{value: 0.1 ether}(1);

        (,,,, uint256 highestBidUsd, address highestBidder,, uint256 bidAmount,,) = market.auctions(1);
        assertEq(highestBidUsd, 300 * 1e8);
        assertEq(highestBidder, bidderETH);
        assertEq(bidAmount, 0.1 ether);
    }

    function test_RevertWhen_BidTooLow() public {
        vm.prank(seller);
        market.createAuction(address(nft), 1, 500 * 1e8, 1 days); // 起拍价 $500

        // 0.1 ETH 仅值 $200，低于起拍价 $500
        vm.prank(bidderETH);
        vm.expectRevert(AuctionMarket.BidTooLow.selector);
        market.bidWithETH{value: 0.1 ether}(1);

        // 起拍价达标：出 0.3 ETH ($600)
        vm.prank(bidderETH);
        market.bidWithETH{value: 0.3 ether}(1);

        // 再次出价低于最高价：出 500 USDC ($500) < 当前最高价 $600
        vm.prank(bidderUSDC);
        vm.expectRevert(AuctionMarket.BidTooLow.selector);
        market.bidWithERC20(1, address(usdc), 500 * 1e6);
    }

    /* -------------------------------------------------------------------------- */
    /*                              结算与流拍测试                                */
    /* -------------------------------------------------------------------------- */

    function test_EndAuction_WithWinner_ETH() public {
        vm.prank(seller);
        market.createAuction(address(nft), 1, 100 * 1e8, 1 days);

        vm.prank(bidderETH);
        market.bidWithETH{value: 0.2 ether}(1); // $400 USD

        // 未到期结算抛错
        vm.expectRevert(AuctionMarket.AuctionTimeNotExpired.selector);
        market.endAuction(1);

        // 快进时间至拍卖结束
        vm.warp(block.timestamp + 1 days + 1);

        uint256 sellerEthBefore = seller.balance;

        market.endAuction(1);

        // NFT 转移给胜出者 bidderETH
        assertEq(nft.ownerOf(1), bidderETH);
        // 拍卖资金 0.2 ETH 结算给卖家
        assertEq(seller.balance, sellerEthBefore + 0.2 ether);

        (,,,,,,,,, bool ended) = market.auctions(1);
        assertTrue(ended);
    }

    function test_EndAuction_WithWinner_ERC20() public {
        vm.prank(seller);
        market.createAuction(address(nft), 1, 100 * 1e8, 1 days);

        vm.prank(bidderUSDC);
        market.bidWithERC20(1, address(usdc), 300 * 1e6); // 300 USDC

        vm.warp(block.timestamp + 1 days + 1);

        uint256 sellerUsdcBefore = usdc.balanceOf(seller);
        market.endAuction(1);

        // NFT 归属 bidderUSDC
        assertEq(nft.ownerOf(1), bidderUSDC);
        // 300 USDC 转移给卖家
        assertEq(usdc.balanceOf(seller), sellerUsdcBefore + 300 * 1e6);
    }

    function test_EndAuction_NoBids_ReturnsNFTToSeller() public {
        vm.prank(seller);
        market.createAuction(address(nft), 1, 100 * 1e8, 1 days);

        // 无人出价，直接流拍
        vm.warp(block.timestamp + 1 days + 1);
        market.endAuction(1);

        // NFT 安全退回卖家
        assertEq(nft.ownerOf(1), seller);
    }

    function test_RevertWhen_EndAuctionTwice() public {
        vm.prank(seller);
        market.createAuction(address(nft), 1, 100 * 1e8, 1 days);

        vm.warp(block.timestamp + 1 days + 1);
        market.endAuction(1);

        vm.expectRevert(AuctionMarket.AuctionAlreadyEnded.selector);
        market.endAuction(1);
    }

    /* -------------------------------------------------------------------------- */
    /*                         UUPS 代理可升级性测试                              */
    /* -------------------------------------------------------------------------- */

    function test_UUPS_Upgrade_Success() public {
        // 1. 部署前在 V1 代理合约中创建一笔拍卖并出价
        vm.prank(seller);
        market.createAuction(address(nft), 1, 100 * 1e8, 1 days);

        vm.prank(bidderETH);
        market.bidWithETH{value: 0.15 ether}(1);

        // 2. 部署 V2 逻辑合约
        AuctionMarketV2 v2Impl = new AuctionMarketV2();

        // 3. 执行 UUPS 升级
        market.upgradeToAndCall(address(v2Impl), "");

        // 4. 将代理包装为 V2 接口进行调用
        AuctionMarketV2 marketV2 = AuctionMarketV2(payable(address(proxy)));

        // 5. 验证原有状态完整保留 (No State Loss)
        assertEq(marketV2.owner(), owner);
        assertEq(marketV2.auctionCounter(), 1);
        (,,,, uint256 highestBidUsd, address highestBidder,,, uint256 endTime,) = marketV2.auctions(1);
        assertEq(highestBidUsd, 300 * 1e8);
        assertEq(highestBidder, bidderETH);
        assertEq(endTime, block.timestamp + 1 days);

        // 6. 验证 V2 新增功能生效
        assertEq(marketV2.version(), "2.0.0");
        marketV2.setPlatformFee(250); // 2.5%
        assertEq(marketV2.platformFeeBps(), 250);
    }

    function test_RevertWhen_NonOwnerAttemptsUpgrade() public {
        AuctionMarketV2 v2Impl = new AuctionMarketV2();

        vm.prank(randomUser);
        // OpenZeppelin v5 OwnableUnauthorizedAccount
        vm.expectRevert();
        market.upgradeToAndCall(address(v2Impl), "");
    }
}
