// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title AuctionMarket (大作业核心：NFT 拍卖市场)
 * @dev 基于 UUPS 代理可升级架构实现，集成 Chainlink 预言机统一折算 USD 估值，支持 ETH/ERC20 双币种竞价
 */
contract AuctionMarket is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    IERC721Receiver
{
    using SafeERC20 for IERC20;

    struct Auction {
        address seller; // 卖家
        address nftContract; // NFT 合约地址
        uint256 tokenId; // NFT Token ID
        uint256 startingPriceUsd; // 起拍价 (USD, 8位小数)
        uint256 highestBidUsd; // 当前最高出价 (USD, 8位小数)
        address highestBidder; // 当前最高出价者
        address bidToken; // 出价代币 (address(0) 表示原生 ETH)
        uint256 bidAmount; // 最高出价原始代币数额
        uint256 endTime; // 拍卖截止时间戳
        bool ended; // 拍卖是否已结算
    }

    uint256 public auctionCounter;
    mapping(uint256 => Auction) public auctions;

    // Chainlink 价格预言机配置 (原生 ETH/USD 及各 ERC20/USD 喂价)
    AggregatorV3Interface public ethUsdPriceFeed;
    mapping(address token => AggregatorV3Interface feed) public tokenPriceFeeds;

    // Pull-over-Push 待退款余额：user => token => amount (address(0) 表示 ETH)
    mapping(address user => mapping(address token => uint256 amount)) public pendingReturns;

    // 事件
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
    event AuctionCanceled(uint256 indexed auctionId);
    event RefundRecorded(address indexed user, address indexed token, uint256 amount);
    event RefundWithdrawn(address indexed user, address indexed token, uint256 amount);
    event TokenPriceFeedUpdated(address indexed token, address indexed feed);

    // 自定义错误
    error InvalidAddress();
    error InvalidDuration();
    error InvalidStartingPrice();
    error AuctionNotActive();
    error AuctionAlreadyEnded();
    error AuctionTimeNotExpired();
    error BidTooLow();
    error ZeroBidAmount();
    error OraclePriceInvalid();
    error PriceFeedNotConfigured();
    error NoPendingRefund();
    error NativeTransferFailed();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice UUPS 代理初始化函数 (替代构造函数)
     * @param _ethUsdPriceFeed Chainlink ETH/USD 预言机地址
     */
    function initialize(address _ethUsdPriceFeed) external initializer {
        if (_ethUsdPriceFeed == address(0)) revert InvalidAddress();

        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
    }

    /**
     * @notice 配置或更新某个 ERC20 代币的 Chainlink 喂价预言机
     * @param token ERC20 代币地址
     * @param feed 对应的 Chainlink 喂价接口地址
     */
    function setTokenPriceFeed(address token, address feed) external onlyOwner {
        if (token == address(0) || feed == address(0)) revert InvalidAddress();
        tokenPriceFeeds[token] = AggregatorV3Interface(feed);
        emit TokenPriceFeedUpdated(token, feed);
    }

    /**
     * @notice 创建 NFT 拍卖
     * @param nftContract NFT 合约地址
     * @param tokenId NFT Token ID
     * @param startingPriceUsd 起拍价 (USD, 8位精度，例如 100 美元应传入 100_00000000)
     * @param duration 拍卖持续时长 (秒)
     * @return auctionId 拍卖编号
     */
    function createAuction(address nftContract, uint256 tokenId, uint256 startingPriceUsd, uint256 duration)
        external
        nonReentrant
        returns (uint256 auctionId)
    {
        if (nftContract == address(0)) revert InvalidAddress();
        if (startingPriceUsd == 0) revert InvalidStartingPrice();
        if (duration == 0) revert InvalidDuration();

        auctionId = ++auctionCounter;
        uint256 endTime = block.timestamp + duration;

        auctions[auctionId] = Auction({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            startingPriceUsd: startingPriceUsd,
            highestBidUsd: 0,
            highestBidder: address(0),
            bidToken: address(0),
            bidAmount: 0,
            endTime: endTime,
            ended: false
        });

        // 托管质押 NFT (转移到当前拍卖合约)
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);

        emit AuctionCreated(auctionId, msg.sender, nftContract, tokenId, startingPriceUsd, endTime);
    }

    /**
     * @notice 以原生以太币 (ETH) 参与竞价
     * @param auctionId 拍卖编号
     */
    function bidWithETH(uint256 auctionId) external payable nonReentrant {
        if (msg.value == 0) revert ZeroBidAmount();
        Auction storage auction = auctions[auctionId];

        _validateAuctionActive(auction);

        uint256 bidUsd = getEthValueInUsd(msg.value);
        _processBid(auctionId, auction, msg.sender, address(0), msg.value, bidUsd);
    }

    /**
     * @notice 以指定 ERC20 代币参与竞价
     * @param auctionId 拍卖编号
     * @param token 出价代币地址
     * @param amount 出价代币数量
     */
    function bidWithERC20(uint256 auctionId, address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroBidAmount();
        if (token == address(0)) revert InvalidAddress();
        if (address(tokenPriceFeeds[token]) == address(0)) revert PriceFeedNotConfigured();

        Auction storage auction = auctions[auctionId];
        _validateAuctionActive(auction);

        // 转入代币 (SafeERC20)
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 bidUsd = getTokenValueInUsd(token, amount);
        _processBid(auctionId, auction, msg.sender, token, amount, bidUsd);
    }

    /**
     * @notice 结束并结算拍卖
     * @param auctionId 拍卖编号
     */
    function endAuction(uint256 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        if (auction.seller == address(0)) revert InvalidAddress();
        if (auction.ended) revert AuctionAlreadyEnded();
        if (block.timestamp < auction.endTime) revert AuctionTimeNotExpired();

        auction.ended = true;

        if (auction.highestBidder != address(0)) {
            // 有人胜出：NFT 发放给最高出价者
            IERC721(auction.nftContract).safeTransferFrom(address(this), auction.highestBidder, auction.tokenId);

            // 资金划转给卖家
            if (auction.bidToken == address(0)) {
                (bool success,) = auction.seller.call{value: auction.bidAmount}("");
                if (!success) revert NativeTransferFailed();
            } else {
                IERC20(auction.bidToken).safeTransfer(auction.seller, auction.bidAmount);
            }

            emit AuctionEnded(
                auctionId, auction.highestBidder, auction.bidToken, auction.bidAmount, auction.highestBidUsd
            );
        } else {
            // 无人出价流拍：NFT 退还给卖家
            IERC721(auction.nftContract).safeTransferFrom(address(this), auction.seller, auction.tokenId);
            emit AuctionCanceled(auctionId);
        }
    }

    /**
     * @notice 提取被超越的出价退款 (Pull-over-Push 模式)
     * @param token 待提取的代币地址 (address(0) 为 ETH)
     */
    function withdrawRefund(address token) external nonReentrant {
        uint256 amount = pendingReturns[msg.sender][token];
        if (amount == 0) revert NoPendingRefund();

        pendingReturns[msg.sender][token] = 0;

        if (token == address(0)) {
            (bool success,) = msg.sender.call{value: amount}("");
            if (!success) revert NativeTransferFailed();
        } else {
            IERC20(token).safeTransfer(msg.sender, amount);
        }

        emit RefundWithdrawn(msg.sender, token, amount);
    }

    /**
     * @notice 计算指定 ETH 数量的 USD 估值 (8位精度)
     * @param ethAmount 以 wei 为单位的 ETH 数量 (18位精度)
     */
    function getEthValueInUsd(uint256 ethAmount) public view returns (uint256) {
        (, int256 price,, uint256 updatedAt,) = ethUsdPriceFeed.latestRoundData();
        if (price <= 0 || updatedAt == 0) revert OraclePriceInvalid();

        // ETH 精度 18 位，Chainlink 喂价 8 位，结果保留 8 位:
        // (ethAmount * price) / 1e18
        return (ethAmount * uint256(price)) / 1e18;
    }

    /**
     * @notice 计算指定 ERC20 代币数量的 USD 估值 (8位精度)
     * @param token 代币合约地址
     * @param amount 代币原始精度数量
     */
    function getTokenValueInUsd(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface feed = tokenPriceFeeds[token];
        if (address(feed) == address(0)) revert PriceFeedNotConfigured();

        (, int256 price,, uint256 updatedAt,) = feed.latestRoundData();
        if (price <= 0 || updatedAt == 0) revert OraclePriceInvalid();

        uint8 tokenDecimals = IERC20Metadata(token).decimals();
        // (amount * price) / (10 ** tokenDecimals)
        return (amount * uint256(price)) / (10 ** tokenDecimals);
    }

    /**
     * @dev 校验拍卖是否处于进行中
     */
    function _validateAuctionActive(Auction storage auction) internal view {
        if (auction.seller == address(0)) revert InvalidAddress();
        if (auction.ended || block.timestamp >= auction.endTime) revert AuctionNotActive();
    }

    /**
     * @dev 处理出价并更新最高出价与退款
     */
    function _processBid(
        uint256 auctionId,
        Auction storage auction,
        address bidder,
        address token,
        uint256 amount,
        uint256 bidUsd
    ) internal {
        // 首次出价需大于等于起拍价；后续出价需高于当前最高价
        if (auction.highestBidder == address(0)) {
            if (bidUsd < auction.startingPriceUsd) revert BidTooLow();
        } else {
            if (bidUsd <= auction.highestBidUsd) revert BidTooLow();

            // 将被超越的前最高出价计入待退款池 (Pull-over-Push)
            pendingReturns[auction.highestBidder][auction.bidToken] += auction.bidAmount;
            emit RefundRecorded(auction.highestBidder, auction.bidToken, auction.bidAmount);
        }

        auction.highestBidder = bidder;
        auction.highestBidUsd = bidUsd;
        auction.bidToken = token;
        auction.bidAmount = amount;

        emit BidPlaced(auctionId, bidder, token, amount, bidUsd);
    }

    /**
     * @notice UUPS 升级授权钩子
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @notice 支持接收 ERC721 代币托管
     */
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
